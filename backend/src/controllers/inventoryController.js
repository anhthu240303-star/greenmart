const InventoryCheck = require('../models/InventoryCheck');
const Product = require('../models/Product');
const StockTransaction = require('../models/StockTransaction');
const ApiResponse = require('../utils/response');
const { generateCode } = require('../utils/generateCode');
const mongoose = require('mongoose');

/**
 * @desc    Tạo phiếu kiểm kê mới
 * @route   POST /api/inventory-checks
 * @access  Private (Warehouse Manager, Admin)
 */
const createInventoryCheck = async (req, res) => {
  try {
    const { title, products, notes } = req.body;

    if (!products || products.length === 0) {
      return ApiResponse.badRequest(res, 'Vui lòng chọn ít nhất một sản phẩm để kiểm kê');
    }

    // Sinh mã phiếu
    const lastCheck = await InventoryCheck.findOne().sort({ createdAt: -1 });
    const sequence = lastCheck ? parseInt(lastCheck.code.substring(2)) + 1 : 1;
    const code = generateCode('KK', sequence);

    const checkItems = [];
    for (const productId of products) {
      const product = await Product.findById(productId);
      if (!product) {
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ID: ${productId}`);
      }

      checkItems.push({
        product: product._id,
        systemQuantity: product.currentStock,
        actualQuantity: 0,
        difference: 0,
        status: 'matched',
      });
    }

    const inventoryCheck = await InventoryCheck.create({
      code,
      title,
      items: checkItems,
      createdBy: req.user._id,
      notes,
    });

    await inventoryCheck.populate([
      { path: 'items.product', select: 'name unit currentStock' },
      { path: 'createdBy', select: 'fullName email' },
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
    } = req.query;

    const query = {};

    if (search) {
      query.$or = [
        { code: { $regex: search, $options: 'i' } },
        { title: { $regex: search, $options: 'i' } },
      ];
    }

    if (status) query.status = status;

    if (startDate || endDate) {
      query.checkDate = {};
      if (startDate) query.checkDate.$gte = new Date(startDate);
      if (endDate) query.checkDate.$lte = new Date(endDate);
    }

    const skip = (page - 1) * limit;

    const [checks, total] = await Promise.all([
      InventoryCheck.find(query)
        .populate('createdBy', 'fullName email')
        .populate('approvedBy', 'fullName email')
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
      .populate('checkedBy', 'fullName email')
      .populate('approvedBy', 'fullName email');

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

    for (const itemUpdate of items) {
      const item = check.items.find(
        (i) => i.product.toString() === itemUpdate.productId
      );
      if (!item) continue;
      item.actualQuantity = itemUpdate.actualQuantity;
      item.notes = itemUpdate.notes || '';
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
 * @desc    Hoàn tất và cập nhật tồn kho theo kết quả kiểm kê
 * @route   PUT /api/inventory-checks/:id/complete
 * @access  Private (Warehouse Manager)
 */
const completeInventoryCheck = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();
  try {
    const check = await InventoryCheck.findById(req.params.id).session(session);
    if (!check) {
      await session.abortTransaction();
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu kiểm kê');
    }

    if (check.status !== 'in_progress') {
      await session.abortTransaction();
      return ApiResponse.badRequest(res, 'Phiếu kiểm kê đã hoàn tất hoặc bị hủy');
    }

    for (const item of check.items) {
      const product = await Product.findById(item.product).session(session);
      if (!product) continue;

      const stockBefore = product.currentStock;
      product.currentStock = item.actualQuantity;
      await product.save({ session });

      if (item.difference !== 0) {
        await StockTransaction.create(
          [
            {
              transactionCode: `${check.code}-${product._id}`,
              type: item.difference > 0 ? 'adjustment_in' : 'adjustment_out',
              product: product._id,
              quantity: Math.abs(item.difference),
              unitPrice: product.costPrice,
              stockBefore,
              stockAfter: product.currentStock,
              reference: check._id,
              referenceModel: 'InventoryCheck',
              performedBy: req.user._id,
              notes: 'Điều chỉnh theo kiểm kê',
            },
          ],
          { session }
        );
      }
    }

    check.status = 'completed';
    check.completedAt = new Date();
    await check.save({ session });

    await session.commitTransaction();
    session.endSession();

    await check.populate([
      { path: 'items.product', select: 'name unit currentStock' },
      { path: 'createdBy', select: 'fullName email' },
    ]);

    return ApiResponse.success(res, { check }, 'Hoàn tất kiểm kê và cập nhật tồn kho');
  } catch (error) {
    await session.abortTransaction();
    session.endSession();
    console.error('Complete inventory check error:', error);
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

    if (check.status === 'completed') {
      return ApiResponse.badRequest(res, 'Không thể hủy phiếu đã hoàn tất');
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
    if (check.status === 'completed')
      return ApiResponse.badRequest(res, 'Không thể xóa phiếu đã hoàn tất');

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
  cancelInventoryCheck,
  deleteInventoryCheck,
};
