const InventoryCheck = require('../models/InventoryCheck');
const Product = require('../models/Product');
const BatchLot = require('../models/BatchLot');
const User = require('../models/User');
const ApiResponse = require('../utils/response');
const { generateCode } = require('../utils/generateCode');
const { logActivity } = require('../utils/activityLogger');
const mongoose = require('mongoose');

/**
 * @desc    Tạo phiếu kiểm kê mới
 * @route   POST /api/inventory-checks
 * @access  Private (Warehouse Manager, Admin)
 */
const createInventoryCheck = async (req, res) => {
  try {
    const { title, products, notes, assigneeId, scope, categoryId } = req.body;

    if (!products || products.length === 0) {
      return ApiResponse.badRequest(res, 'Vui lòng chọn ít nhất một sản phẩm để kiểm kê');
    }

    // Sinh mã phiếu
    const lastCheck = await InventoryCheck.findOne().sort({ createdAt: -1 });
    const sequence = lastCheck ? parseInt(lastCheck.code.substring(2)) + 1 : 1;
    const code = generateCode('KK', sequence);

    const checkItems = [];
    // products: array of { productId, batchId? }
    for (const p of products) {
      const product = await Product.findById(p.productId);
      if (!product) {
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ID: ${p.productId}`);
      }

      let systemQty = product.currentStock;
      let batch = null;
      let batchSnapshot = {};

      if (p.batchId) {
        batch = await BatchLot.findById(p.batchId);
        if (!batch) return ApiResponse.notFound(res, `Không tìm thấy lô ID: ${p.batchId}`);
        systemQty = batch.remainingQuantity;
        batchSnapshot = {
          batchNumber: batch.batchNumber,
          manufacturingDate: batch.manufacturingDate,
          expiryDate: batch.expiryDate,
        };
      }

      checkItems.push({
        product: product._id,
        batch: batch ? batch._id : undefined,
        batchNumber: batchSnapshot.batchNumber,
        manufacturingDate: batchSnapshot.manufacturingDate,
        expiryDate: batchSnapshot.expiryDate,
        systemQuantity: systemQty,
        actualQuantity: p.actualQuantity || 0,
        difference: 0,
        status: 'matched',
        discrepancyReason: p.discrepancyReason || null,
        costPrice: (batch && batch.costPrice) ? batch.costPrice : product.costPrice || 0,
      });
    }

    // Validate scope/category
    const allowedScopes = ['all', 'category', 'product'];
    let finalScope = scope || 'product';
    if (!allowedScopes.includes(finalScope)) finalScope = 'product';

    const createPayload = {
      code,
      title,
      items: checkItems,
      createdBy: req.user._id,
      notes,
      scope: finalScope,
    };

    if (assigneeId) {
      try {
        const u = await User.findById(assigneeId).select('_id fullName');
        if (u) createPayload.assignee = u._id;
        else console.warn(`createInventoryCheck: provided assigneeId ${assigneeId} not found`);
      } catch (e) {
        console.warn(`createInventoryCheck: invalid assigneeId ${assigneeId}`);
      }
    }
    if (finalScope === 'category' && categoryId) createPayload.category = categoryId;

    const inventoryCheck = await InventoryCheck.create(createPayload);
    console.log('Created inventoryCheck', { id: inventoryCheck._id, assignee: inventoryCheck.assignee });

    await inventoryCheck.populate([
      { path: 'items.product', select: 'name unit currentStock' },
      { path: 'createdBy', select: 'fullName email' },
      { path: 'assignee', select: 'fullName email username' },
      { path: 'category', select: 'name' },
    ]);

    return ApiResponse.created(res, { inventoryCheck }, 'Tạo phiếu kiểm kê thành công');
  } catch (error) {
    console.error('Create inventory check error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách phiếu kiểm kê
 * @route   GET /api/inventory-checks
 * @access  Private
 */
const getInventoryChecks = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      search,
      status,
      startDate,
      endDate,
      assigneeId: qAssigneeId,
    } = req.query;

    const query = {};

    if (search) {
      query.$or = [
        { code: { $regex: search, $options: 'i' } },
        { title: { $regex: search, $options: 'i' } },
      ];
    }

    if (status) query.status = status;

    // If current user is warehouse_staff, only return checks assigned to them
    if (req.user && req.user.role === 'warehouse_staff') {
      query.assignee = req.user._id;
    } else if (qAssigneeId) {
      // allow admin/manager to filter by assignee
      query.assignee = qAssigneeId;
    }

    if (startDate || endDate) {
      query.checkDate = {};
      if (startDate) query.checkDate.$gte = new Date(startDate);
      if (endDate) query.checkDate.$lte = new Date(endDate);
    }

    const skip = (page - 1) * limit;

    const [checks, total] = await Promise.all([
      InventoryCheck.find(query)
        .populate('createdBy', 'fullName email')
        .populate('assignee', 'fullName email username')
        .populate('approvedBy', 'fullName email')
        .populate('category', 'name')
        .sort({ checkDate: -1 })
        .skip(skip)
        .limit(parseInt(limit)),
      InventoryCheck.countDocuments(query),
    ]);

    return ApiResponse.paginate(
      res,
      checks,
      { page: parseInt(page), limit: parseInt(limit), total },
      'Lấy danh sách phiếu kiểm kê thành công'
    );
  } catch (error) {
    console.error('Get inventory checks error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy chi tiết phiếu kiểm kê
 * @route   GET /api/inventory-checks/:id
 * @access  Private
 */
const getInventoryCheckById = async (req, res) => {
  try {
    const check = await InventoryCheck.findById(req.params.id)
      .populate('items.product', 'name unit currentStock')
      .populate('createdBy', 'fullName email')
      .populate('assignee', 'fullName email username')
      .populate('checkedBy', 'fullName email')
      .populate('approvedBy', 'fullName email')
      .populate('category', 'name');

    if (!check) return ApiResponse.notFound(res, 'Không tìm thấy phiếu kiểm kê');

    return ApiResponse.success(res, { check }, 'Lấy chi tiết phiếu kiểm kê thành công');
  } catch (error) {
    console.error('Get inventory check detail error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Cập nhật kết quả kiểm kê (số lượng thực tế)
 * @route   PUT /api/inventory-checks/:id/items
 * @access  Private (Warehouse Staff, Manager)
 */
const updateInventoryCheckItems = async (req, res) => {
  try {
    const { items } = req.body;
    const check = await InventoryCheck.findById(req.params.id);

    if (!check) return ApiResponse.notFound(res, 'Không tìm thấy phiếu kiểm kê');
    if (check.status !== 'in_progress')
      return ApiResponse.badRequest(res, 'Chỉ có thể cập nhật khi đang thực hiện');

    // Only the assigned staff can update actual quantities
    if (check.assignee) {
      if (!req.user || !req.user._id || check.assignee.toString() !== req.user._id.toString()) {
        return ApiResponse.forbidden(res, 'Chỉ nhân viên được phân công mới có thể cập nhật kết quả kiểm kê');
      }
    } else {
      // If no assignee is set, disallow updates (require explicit assignment)
      return ApiResponse.forbidden(res, 'Phiếu chưa được phân công người thực hiện');
    }

    for (const itemUpdate of items) {
      const item = check.items.find(
        (i) => i.product.toString() === itemUpdate.productId
      );
      if (!item) continue;
      item.actualQuantity = itemUpdate.actualQuantity;
      item.notes = itemUpdate.notes || '';
      if (itemUpdate.discrepancyReason !== undefined) item.discrepancyReason = itemUpdate.discrepancyReason;
    }

    await check.save();
    await check.populate([
      { path: 'items.product', select: 'name unit currentStock' },
    ]);

    return ApiResponse.success(res, { check }, 'Cập nhật số lượng thực tế thành công');
  } catch (error) {
    console.error('Update inventory check error:', error);
    return ApiResponse.error(res, error.message);
  }
};


/**
 * @desc    Nhân viên kho đánh dấu phiếu là đã "hoàn tất kiểm kê" (submit kết quả)
 * @route   PUT /api/inventory-checks/:id/complete
 * @access  Private (Warehouse Staff, Manager, Admin)
 */
const completeInventoryCheck = async (req, res) => {
  try {
    const check = await InventoryCheck.findById(req.params.id);
    if (!check) return ApiResponse.notFound(res, 'Không tìm thấy phiếu kiểm kê');

    if (check.status !== 'in_progress') return ApiResponse.badRequest(res, 'Chỉ có thể hoàn tất phiếu khi đang thực hiện');

    // Only the assigned staff can mark the check as completed
    if (check.assignee) {
      if (!req.user || !req.user._id || check.assignee.toString() !== req.user._id.toString()) {
        return ApiResponse.forbidden(res, 'Chỉ nhân viên được phân công mới có thể hoàn tất phiếu kiểm kê');
      }
    } else {
      return ApiResponse.forbidden(res, 'Phiếu chưa được phân công người thực hiện');
    }

    // Mark as submitted (waiting for approval) rather than completed
    check.status = 'submitted';
    check.submittedAt = new Date();
    // Optionally record who submitted
    if (!check.checkedBy) check.checkedBy = [];
    if (req.user && req.user._id) check.checkedBy.push(req.user._id);
    await check.save();

    await logActivity({
      user: req.user ? req.user._id : null,
      action: 'submit_inventory_check',
      entityType: 'InventoryCheck',
      entityId: check._id,
      description: `Nộp kết quả kiểm kê ${check.code}`,
      meta: { checkId: check._id },
    });

    await check.populate([
      { path: 'items.product', select: 'name unit currentStock' },
      { path: 'createdBy', select: 'fullName email' },
    ]);

    return ApiResponse.success(res, { check }, 'Đã nộp kết quả kiểm kê (chờ duyệt)');
  } catch (error) {
    console.error('Complete inventory check error:', error);
    return ApiResponse.error(res, error.message);
  }
};


/**
 * @desc    Duyệt phiếu kiểm kê và cập nhật tồn kho (Admin/Manager)
 * @route   PUT /api/inventory-checks/:id/approve
 * @access  Private (Admin, Warehouse Manager)
 */
const approveInventoryCheck = async (req, res) => {
  try {
    const check = await InventoryCheck.findById(req.params.id);
    if (!check) return ApiResponse.notFound(res, 'Không tìm thấy phiếu kiểm kê');

    if (check.status !== 'submitted') return ApiResponse.badRequest(res, 'Chỉ có thể duyệt phiếu đã được nộp bởi nhân viên kho');

    // Only allow admin or warehouse_manager roles to approve
    const allowedRoles = ['admin', 'warehouse_manager'];
    if (!req.user || !req.user.role || !allowedRoles.includes(req.user.role)) {
      return ApiResponse.forbidden(res, 'Chỉ Admin hoặc Quản lý kho mới có thể duyệt phiếu kiểm kê');
    }

    console.log('Approving inventoryCheck', { id: check._id, approver: req.user ? req.user._id : null, approverRole: req.user ? req.user.role : null });

    // Apply adjustments
    for (const item of check.items) {
      const product = await Product.findById(item.product);
      if (!product) continue;

      item.difference = item.actualQuantity - item.systemQuantity;

      if (item.batch) {
        const batch = await BatchLot.findById(item.batch);
        if (batch) {
          const before = batch.remainingQuantity;
          batch.remainingQuantity = item.actualQuantity;
          await batch.save();

          // recompute product.currentStock from active batches
          const batches = await BatchLot.find({ product: product._id, status: 'active' });
          const totalRemaining = batches.reduce((s, b) => s + (b.remainingQuantity || 0), 0);
          const productBefore = product.currentStock;
          product.currentStock = totalRemaining;
          await product.save();

          await logActivity({
            user: req.user ? req.user._id : null,
            action: 'approve_inventory_check',
            entityType: 'BatchLot',
            entityId: batch._id,
            description: `Duyệt kiểm kê ${check.code}: lô ${batch.batchNumber} ${product.name} ${before} → ${batch.remainingQuantity}`,
            meta: { before, after: batch.remainingQuantity, product: product._id, checkId: check._id, reason: item.discrepancyReason },
          });
        }
      } else {
        const before = product.currentStock;
        product.currentStock = item.actualQuantity;
        await product.save();

        await logActivity({
          user: req.user ? req.user._id : null,
          action: 'approve_inventory_check',
          entityType: 'Product',
          entityId: product._id,
          description: `Duyệt kiểm kê ${check.code}: sản phẩm ${product.name} ${before} → ${product.currentStock}`,
          meta: { before, after: product.currentStock, checkId: check._id, reason: item.discrepancyReason },
        });
      }
    }

    // Mark as completed after approval
    check.status = 'completed';
    check.approvedBy = req.user ? req.user._id : undefined;
    check.approvedAt = new Date();
    await check.save();

    await check.populate([
      { path: 'items.product', select: 'name unit currentStock' },
      { path: 'createdBy', select: 'fullName email' },
      { path: 'approvedBy', select: 'fullName email' },
    ]);

    return ApiResponse.success(res, { check }, 'Duyệt phiếu kiểm kê và cập nhật tồn kho thành công');
  } catch (error) {
    console.error('Approve inventory check error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Hủy phiếu kiểm kê
 * @route   PUT /api/inventory-checks/:id/cancel
 * @access  Private (Manager/Admin)
 */
const cancelInventoryCheck = async (req, res) => {
  try {
    const check = await InventoryCheck.findById(req.params.id);
    if (!check) return ApiResponse.notFound(res, 'Không tìm thấy phiếu kiểm kê');

    // Can only cancel when still in progress
    if (check.status !== 'in_progress') {
      return ApiResponse.badRequest(res, 'Không thể hủy phiếu đã nộp hoặc hoàn tất');
    }

    check.status = 'cancelled';
    await check.save();

    return ApiResponse.success(res, { check }, 'Hủy phiếu kiểm kê thành công');
  } catch (error) {
    console.error('Cancel inventory check error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Xóa phiếu kiểm kê
 * @route   DELETE /api/inventory-checks/:id
 * @access  Private (Admin)
 */
const deleteInventoryCheck = async (req, res) => {
  try {
    const check = await InventoryCheck.findById(req.params.id);
    if (!check) return ApiResponse.notFound(res, 'Không tìm thấy phiếu kiểm kê');
    // Only allow deletion when still in progress (not submitted or completed)
    if (check.status !== 'in_progress')
      return ApiResponse.badRequest(res, 'Không thể xóa phiếu đã nộp hoặc đã hoàn tất');

    await check.deleteOne();
    return ApiResponse.deleted(res, 'Xóa phiếu kiểm kê thành công');
  } catch (error) {
    console.error('Delete inventory check error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  createInventoryCheck,
  getInventoryChecks,
  getInventoryCheckById,
  updateInventoryCheckItems,
  completeInventoryCheck,
  approveInventoryCheck,
  cancelInventoryCheck,
  deleteInventoryCheck,
};
