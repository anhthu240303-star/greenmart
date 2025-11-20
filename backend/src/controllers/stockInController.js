const mongoose = require('mongoose');
const StockIn = require('../models/StockIn');
const Product = require('../models/Product');
const Supplier = require('../models/Supplier');
const BatchLot = require('../models/BatchLot');
const ApiResponse = require('../utils/response');
const { generateStockInCode } = require('../utils/generateCode');
const { logActivity } = require('../utils/activityLogger');

/**
 * @desc    Tạo phiếu nhập kho mới
 * @route   POST /api/stock-in
 * @access  Private (Warehouse Staff / Manager)
 */
const createStockIn = async (req, res) => {
  try {
    const { supplier, items, importDate } = req.body;

    if (!supplier || !items || items.length === 0) {
      return ApiResponse.badRequest(res, 'Vui lòng nhập đầy đủ thông tin phiếu nhập');
    }

    // Kiểm tra supplier
    const supplierExists = await Supplier.findById(supplier);
    if (!supplierExists) {
      return ApiResponse.notFound(res, 'Nhà cung cấp không tồn tại');
    }

    // Kiểm tra sản phẩm trong danh sách nhập
    for (const item of items) {
      const product = await Product.findById(item.product);
      if (!product) {
        return ApiResponse.notFound(res, `Sản phẩm với ID ${item.product} không tồn tại`);
      }
    }

    // Sinh mã phiếu nhập
    const code = await generateStockInCode(StockIn);

    // Tạo phiếu nhập kho trước, sau đó tạo BatchLot với stockInRef trỏ tới stockIn._id
    // (BatchLot.stockInRef là required nên cần stockIn._id trước khi tạo BatchLot)
    const stockIn = await StockIn.create({
      code,
      supplier,
      items,
      importDate: importDate || Date.now(),
      createdBy: req.user._id,
    });

    // Tạo BatchLot cho từng item và cập nhật stockIn.items[*].batchLotRef
    for (const item of stockIn.items) {
      if (item.batchNumber && item.quantity > 0) {
        try {
          // Ensure costPrice is present: prefer item.unitPrice, fallback to product.costPrice, else 0
          let costForBatch = 0;
          if (item.unitPrice != null) {
            costForBatch = Number(item.unitPrice) || 0;
          } else {
            try {
              const prodForCost = await Product.findById(item.product).select('costPrice');
              if (prodForCost && prodForCost.costPrice != null) costForBatch = Number(prodForCost.costPrice) || 0;
            } catch (pfErr) {
              // ignore and leave fallback 0
            }
          }

          const batchLot = await BatchLot.create({
            batchNumber: item.batchNumber,
            product: item.product,
            supplier,
            stockInRef: stockIn._id,
            manufacturingDate: item.manufacturingDate,
            expiryDate: item.expiryDate,
            initialQuantity: item.quantity,
            remainingQuantity: item.quantity,
            costPrice: costForBatch,
            receivedDate: stockIn.importDate || Date.now(),
            status: 'active',
            createdBy: req.user._id,
          });
          item.batchLotRef = batchLot._id;

          // Update product.batchLots if product schema has field
          try {
            await Product.updateOne({ _id: item.product }, { $addToSet: { batchLots: batchLot._id } });
          } catch (upErr) {
            console.warn('Warning: failed to push batchLot id into product', item.product.toString(), upErr && upErr.message ? upErr.message : upErr);
          }
        } catch (err) {
          // Log and continue with other items
          console.error('Error creating BatchLot for stockIn item', item.product.toString(), err && err.message ? err.message : err);
        }
      }
    }

    // Save stockIn again to persist batchLotRef in items
    await stockIn.save();

    await stockIn.populate([
      { path: 'supplier', select: 'name code phone' },
      { path: 'items.product', select: 'name sku unit' },
      { path: 'createdBy', select: 'fullName email' },
    ]);

    // Log activity: create stock in
    try {
      await logActivity({
        user: req.user && req.user._id,
        action: 'create_stock_in',
        entityType: 'StockIn',
        entityId: stockIn._id,
        description: `Tạo phiếu nhập ${stockIn.code}`,
        meta: { code: stockIn.code, totalAmount: stockIn.totalAmount, itemsCount: stockIn.items.length },
      });
    } catch (_) {}

    return ApiResponse.created(res, { stockIn }, 'Tạo phiếu nhập kho thành công');
  } catch (error) {
    console.error('Create stock in error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách phiếu nhập kho
 * @route   GET /api/stock-in
 * @access  Private
 */
const getStockIns = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      search,
      status,
      supplier,
      startDate,
      endDate,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const query = {};

    if (search) query.code = { $regex: search, $options: 'i' };
    if (status) query.status = status;
    if (supplier) query.supplier = supplier;

    if (startDate || endDate) {
      query.importDate = {};
      if (startDate) query.importDate.$gte = new Date(startDate);
      if (endDate) query.importDate.$lte = new Date(endDate);
    }

    const skip = (page - 1) * limit;
    const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

    const stockIns = await StockIn.find(query)
      .populate('supplier', 'name code')
      .populate('createdBy', 'fullName email')
      .populate('approvedBy', 'fullName email')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await StockIn.countDocuments(query);

    return ApiResponse.paginate(
      res,
      stockIns,
      { page: parseInt(page), limit: parseInt(limit), total },
      'Lấy danh sách phiếu nhập kho thành công'
    );
  } catch (error) {
    console.error('Get stock ins error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy chi tiết phiếu nhập kho
 * @route   GET /api/stock-in/:id
 * @access  Private
 */
const getStockInById = async (req, res) => {
  try {
    const stockIn = await StockIn.findById(req.params.id)
      .populate('supplier', 'name code phone')
      .populate('items.product', 'name sku unit')
      .populate('createdBy', 'name username fullName email')
      .populate('approvedBy', 'name username fullName email');

    if (!stockIn) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu nhập kho');
    }

    return ApiResponse.success(res, { stockIn }, 'Lấy thông tin phiếu nhập kho thành công');
  } catch (error) {
    console.error('Get stock in by ID error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Cập nhật phiếu nhập kho (khi còn pending)
 * @route   PUT /api/stock-in/:id
 * @access  Private
 */
const updateStockIn = async (req, res) => {
  try {
    const stockIn = await StockIn.findById(req.params.id);
    if (!stockIn) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu nhập kho');
    }

    if (stockIn.status !== 'pending') {
      return ApiResponse.badRequest(res, 'Chỉ có thể cập nhật phiếu đang chờ duyệt');
    }

    const { supplier, items, importDate } = req.body;

    if (supplier) {
      const supplierExists = await Supplier.findById(supplier);
      if (!supplierExists) {
        return ApiResponse.notFound(res, 'Nhà cung cấp không tồn tại');
      }
      stockIn.supplier = supplier;
    }

    if (items && items.length > 0) {
      for (const item of items) {
        const product = await Product.findById(item.product);
        if (!product) {
          return ApiResponse.notFound(res, `Sản phẩm ${item.product} không tồn tại`);
        }
      }
      stockIn.items = items;
    }

    if (importDate) stockIn.importDate = importDate;

    await stockIn.save();

    await stockIn.populate([
      { path: 'supplier', select: 'name code' },
      { path: 'items.product', select: 'name sku unit' },
    ]);

    return ApiResponse.updated(res, { stockIn }, 'Cập nhật phiếu nhập kho thành công');
  } catch (error) {
    console.error('Update stock in error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Duyệt phiếu nhập kho (manager)
 * @route   POST /api/stock-in/:id/approve
 * @access  Private/Manager
 */
const approveStockIn = async (req, res) => {
  
  try {
    const stockIn = await StockIn.findById(req.params.id)
      .populate('items.product');

    if (!stockIn) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu nhập kho');
    }

    if (stockIn.status !== 'pending') {
      return ApiResponse.badRequest(res, 'Phiếu nhập này đã được xử lý hoặc bị hủy');
    }

    for (const item of stockIn.items) {
      const product = await Product.findById(item.product._id);
      if (!product) {
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ${item.product.name}`);
      }

      const stockBefore = product.currentStock;
      const stockAfter = stockBefore + item.quantity;

      // Cập nhật tồn kho sản phẩm (không tạo StockTransaction)
      product.currentStock = stockAfter;
      await product.save();

      // Không lưu transaction object nữa; giữ trống hoặc xóa reference
      item.transactionRef = null;
    }

    stockIn.status = 'completed';
    stockIn.approvedBy = req.user._id;
    stockIn.approvedAt = new Date();

    await stockIn.save();

    await stockIn.populate([
      { path: 'supplier', select: 'name code' },
      { path: 'items.product', select: 'name sku unit currentStock' },
      { path: 'approvedBy', select: 'fullName email' },
    ]);

    // Log activity: approve stock in
    try {
      await logActivity({
        user: req.user && req.user._id,
        action: 'approve_stock_in',
        entityType: 'StockIn',
        entityId: stockIn._id,
        description: `Duyệt phiếu nhập ${stockIn.code}`,
        meta: { code: stockIn.code, approvedBy: req.user && req.user._id, approvedAt: stockIn.approvedAt },
      });
    } catch (_) {}

    return ApiResponse.success(res, { stockIn }, 'Duyệt phiếu nhập kho thành công');
  } catch (error) {
    console.error('Approve stock in error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Hủy phiếu nhập kho
 * @route   POST /api/stock-in/:id/cancel
 * @access  Private/Manager
 */
const cancelStockIn = async (req, res) => {
  try {
    const stockIn = await StockIn.findById(req.params.id);
    if (!stockIn) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu nhập kho');
    }

    if (stockIn.status === 'completed') {
      return ApiResponse.badRequest(res, 'Không thể hủy phiếu đã hoàn thành');
    }

    // Sequential rollback WITHOUT using MongoDB transactions (standalone mongod compatibility)
    // Steps:
    // 1) For each item in the stockIn, ensure product exists and that cancelling won't make stock negative
    // 2) If checks pass, delete BatchLots created by this stockIn
    // 3) Decrement product.currentStock by item.quantity (fail if result would be negative)
    // 4) Attempt to delete any StockTransaction / MovementLog referencing this stockIn (if models exist)
    // 5) Mark stockIn.status = 'cancelled' and save

    // Validate all items first to avoid partial changes
    for (const item of stockIn.items) {
      const product = await Product.findById(item.product);
      if (!product) {
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ${item.product}`);
      }

      const newStock = product.currentStock - item.quantity;
      if (newStock < 0) {
        return ApiResponse.badRequest(
          res,
          `Không thể hủy phiếu vì sẽ dẫn tới tồn kho âm cho sản phẩm ${product._id} (${product.name || ''})`
        );
      }
    }

    // All checks passed, perform sequential deletions and updates
    for (const item of stockIn.items) {
      // Kiểm tra các BatchLot tạo bởi stockIn cho sản phẩm này
      let batches = [];
      try {
        batches = await BatchLot.find({ stockInRef: stockIn._id, product: item.product }).exec();
      } catch (err) {
        console.error('Error finding BatchLots for stockIn', stockIn._id.toString(), err && err.message ? err.message : err);
        return ApiResponse.error(res, 'Lỗi khi kiểm tra lô hàng liên quan tới phiếu nhập');
      }

      // Nếu có bất kỳ lô nào đã bị xuất một phần (initialQuantity !== remainingQuantity), abort
      const partiallyUsed = batches.find((b) => b.initialQuantity !== b.remainingQuantity);
      if (partiallyUsed) {
        return ApiResponse.badRequest(
          res,
          `Không thể hủy phiếu vì lô ${partiallyUsed.batchNumber} của sản phẩm đã bị xuất một phần`
        );
      }

      // Nếu tất cả lô đều nguyên vẹn (chưa xuất), xóa chúng
      if (batches.length > 0) {
        try {
          await BatchLot.deleteMany({ stockInRef: stockIn._id, product: item.product });
        } catch (err) {
          console.error('Error deleting BatchLots for stockIn', stockIn._id.toString(), err && err.message ? err.message : err);
          return ApiResponse.error(res, 'Lỗi khi xóa lô hàng liên quan tới phiếu nhập');
        }
      }

      // Update product currentStock
      const product = await Product.findById(item.product);
      if (!product) {
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ${item.product}`);
      }

      product.currentStock = product.currentStock - item.quantity;
      if (product.currentStock < 0) {
        // This should not happen because we validated earlier, but check defensively
        return ApiResponse.badRequest(
          res,
          `Hủy thất bại: tồn kho âm cho sản phẩm ${product._id} (${product.name || ''})`
        );
      }

      // Save product (this will update status/out_of_stock middleware)
      try {
        await product.save();
      } catch (err) {
        console.error('Error updating product stock during cancel', product._id.toString(), err && err.message ? err.message : err);
        return ApiResponse.error(res, 'Lỗi khi cập nhật tồn kho sản phẩm');
      }
    }

    // Attempt to remove any legacy transaction / movement logs referencing this stockIn
    // Models may have been removed; try/catch to skip if not present
    try {
      // StockTransaction model (if exists)
      // eslint-disable-next-line global-require
      const StockTransaction = require('../models/StockTransaction');
      try {
        await StockTransaction.deleteMany({ stockInRef: stockIn._id });
      } catch (err) {
        console.warn('Warning: failed to delete StockTransaction records for stockIn', stockIn._id.toString(), err && err.message ? err.message : err);
      }
    } catch (e) {
      // model doesn't exist — nothing to do
    }

    try {
      // MovementLog model (if exists)
      // eslint-disable-next-line global-require
      const MovementLog = require('../models/MovementLog');
      try {
        await MovementLog.deleteMany({ referenceId: stockIn._id });
      } catch (err) {
        console.warn('Warning: failed to delete MovementLog records for stockIn', stockIn._id.toString(), err && err.message ? err.message : err);
      }
    } catch (e) {
      // model doesn't exist — nothing to do
    }

    // Finally mark the stockIn as cancelled
    stockIn.status = 'cancelled';
    stockIn.cancelledBy = req.user._id; // optional field (may not exist in schema)
    stockIn.cancelledAt = new Date();
    await stockIn.save();

    await stockIn.populate([
      { path: 'supplier', select: 'name code' },
      { path: 'items.product', select: 'name sku unit currentStock' },
    ]);

    // Log activity: cancel stock in
    try {
      await logActivity({
        user: req.user && req.user._id,
        action: 'cancel_stock_in',
        entityType: 'StockIn',
        entityId: stockIn._id,
        description: `Hủy phiếu nhập ${stockIn.code}`,
        meta: { code: stockIn.code, cancelledBy: req.user && req.user._id, cancelledAt: stockIn.cancelledAt },
      });
    } catch (_) {}

    return ApiResponse.success(res, { stockIn }, 'Hủy phiếu nhập kho thành công');
  } catch (error) {
    console.error('Cancel stock in error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Xóa phiếu nhập kho
 * @route   DELETE /api/stock-in/:id
 * @access  Private/Manager
 */
const deleteStockIn = async (req, res) => {
  try {
    const stockIn = await StockIn.findById(req.params.id);
    if (!stockIn) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu nhập kho');
    }

    if (stockIn.status !== 'cancelled' && stockIn.status !== 'pending') {
      return ApiResponse.badRequest(
        res,
        'Chỉ có thể xóa phiếu nhập ở trạng thái chờ duyệt hoặc đã hủy'
      );
    }

    await stockIn.deleteOne();

    return ApiResponse.deleted(res, 'Xóa phiếu nhập kho thành công');
  } catch (error) {
    console.error('Delete stock in error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  createStockIn,
  getStockIns,
  getStockInById,
  updateStockIn,
  approveStockIn,
  cancelStockIn,
  deleteStockIn,
};
