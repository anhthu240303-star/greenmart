const mongoose = require('mongoose');
const StockOut = require('../models/StockOut');
const Product = require('../models/Product');
const BatchLot = require('../models/BatchLot');
const ApiResponse = require('../utils/response');
const { generateStockOutCode } = require('../utils/generateCode');
const { logActivity } = require('../utils/activityLogger');

/**
 * @desc    Tạo phiếu xuất kho mới
 * @route   POST /api/stock-outs
 * @access  Private (Warehouse Staff, Manager)
 */
const createStockOut = async (req, res) => {
  try {
    const { type, items, issueDate } = req.body;

    if (!type || !items || items.length === 0) {
      
      return ApiResponse.badRequest(res, 'Vui lòng nhập đầy đủ thông tin phiếu xuất kho');
    }

    // Validate sản phẩm
    for (const item of items) {
      const product = await Product.findById(item.product);
      if (!product) {
        
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ID: ${item.product}`);
      }
      if (product.currentStock < item.quantity) {
        
        return ApiResponse.badRequest(
          res,
          `Sản phẩm "${product.name}" không đủ tồn kho (hiện còn ${product.currentStock})`
        );
      }
    }

    // Chọn lô xuất theo FIFO cho từng item
    for (const item of items) {
      const batchLots = [];
      let qtyToExport = item.quantity;
      let weightedCostSum = 0; // sum of (qty * costPrice) for this item
      // Tìm các lô còn hàng theo FIFO
      const lots = await BatchLot.find({
        product: item.product,
        status: 'active',
        remainingQuantity: { $gt: 0 },
      }).sort({ receivedDate: 1 });
      for (const lot of lots) {
        if (qtyToExport <= 0) break;
        const exportQty = Math.min(qtyToExport, lot.remainingQuantity);
        batchLots.push({
          batchLotRef: lot._id,
          batchNumber: lot.batchNumber,
          quantity: exportQty,
          costPrice: lot.costPrice,
          expiryDate: lot.expiryDate,
        });
        weightedCostSum += exportQty * (lot.costPrice || 0);
        // Giảm số lượng lô
        lot.remainingQuantity -= exportQty;
        if (lot.remainingQuantity === 0) lot.status = 'depleted';
        await lot.save();
        qtyToExport -= exportQty;
      }
      item.batchLots = batchLots;
      // Nếu client không truyền `unitPrice`, tự set theo trung bình gia von của các lô (weighted average)
      if (item.unitPrice === undefined || item.unitPrice === null) {
        const qty = Number(item.quantity || 0);
        item.unitPrice = qty > 0 ? Number((weightedCostSum / qty).toFixed(2)) : 0;
      }
    }

    // Sinh mã phiếu xuất
    const code = await generateStockOutCode(StockOut);

    // Tạo phiếu xuất kho
    const stockOut = await StockOut.create({
      code,
      type,
      items,
      issueDate: issueDate || Date.now(),
      createdBy: req.user._id,
    });

    await stockOut.populate([
      { path: 'items.product', select: 'name sku unit currentStock' },
      { path: 'createdBy', select: 'fullName email' },
    ]);

    // Log activity: create stock out
    try {
      await logActivity({
        user: req.user && req.user._id,
        action: 'create_stock_out',
        entityType: 'StockOut',
        entityId: stockOut._id,
        description: `Tạo phiếu xuất ${stockOut.code}`,
        meta: { code: stockOut.code, totalAmount: stockOut.totalAmount, itemsCount: stockOut.items.length, type: stockOut.type },
      });
    } catch (_) {}

    return ApiResponse.created(res, { stockOut }, 'Tạo phiếu xuất kho thành công');
  } catch (error) {
    console.error('Create stock out error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách phiếu xuất kho
 * @route   GET /api/stock-outs
 * @access  Private
 */
const getStockOuts = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      search,
      type,
      status,
      startDate,
      endDate,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const query = {};

    if (search) query.code = { $regex: search, $options: 'i' };
    if (type) query.type = type;
    if (status) query.status = status;
    if (startDate || endDate) {
      query.issueDate = {};
      if (startDate) query.issueDate.$gte = new Date(startDate);
      if (endDate) query.issueDate.$lte = new Date(endDate);
    }

    const skip = (page - 1) * limit;
    const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

    const stockOuts = await StockOut.find(query)
      .populate('createdBy', 'fullName email')
      .populate('approvedBy', 'fullName email')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await StockOut.countDocuments(query);

    return ApiResponse.paginate(
      res,
      stockOuts,
      {
        page: parseInt(page),
        limit: parseInt(limit),
        total,
      },
      'Lấy danh sách phiếu xuất kho thành công'
    );
  } catch (error) {
    console.error('Get stock outs error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy chi tiết phiếu xuất kho
 * @route   GET /api/stock-outs/:id
 * @access  Private
 */
const getStockOutById = async (req, res) => {
  try {
    const stockOut = await StockOut.findById(req.params.id)
      .populate('items.product', 'name sku unit currentStock')
      .populate('createdBy', 'fullName email')
      .populate('approvedBy', 'fullName email');

    if (!stockOut) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu xuất kho');
    }

    return ApiResponse.success(res, { stockOut }, 'Lấy chi tiết phiếu xuất kho thành công');
  } catch (error) {
    console.error('Get stock out by ID error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Cập nhật phiếu xuất kho (khi pending)
 * @route   PUT /api/stock-outs/:id
 * @access  Private (Warehouse Staff, Manager)
 */
const updateStockOut = async (req, res) => {
  try {
    const stockOut = await StockOut.findById(req.params.id);

    if (!stockOut) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu xuất kho');
    }

    if (stockOut.status !== 'pending') {
      return ApiResponse.badRequest(res, 'Chỉ có thể cập nhật phiếu đang chờ duyệt');
    }

    const { type, items, issueDate } = req.body;

    if (type) stockOut.type = type;
    if (issueDate) stockOut.issueDate = issueDate;

    if (items && items.length > 0) {
      for (const item of items) {
        const product = await Product.findById(item.product);
        if (!product) {
          return ApiResponse.notFound(res, `Sản phẩm ${item.product} không tồn tại`);
        }
        if (product.currentStock < item.quantity) {
          return ApiResponse.badRequest(
            res,
            `Sản phẩm "${product.name}" không đủ tồn kho (hiện còn ${product.currentStock})`
          );
        }
      }
      stockOut.items = items;
    }

    await stockOut.save();

    await stockOut.populate([
      { path: 'items.product', select: 'name sku unit currentStock' },
      { path: 'createdBy', select: 'fullName email' },
    ]);

    return ApiResponse.updated(res, { stockOut }, 'Cập nhật phiếu xuất kho thành công');
  } catch (error) {
    console.error('Update stock out error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Duyệt phiếu xuất kho (Manager/Admin)
 * @route   POST /api/stock-outs/:id/approve
 * @access  Private/Manager
 */
const approveStockOut = async (req, res) => {
  

  try {
    const stockOut = await StockOut.findById(req.params.id)
      .populate('items.product')
      ;

    if (!stockOut) {
      
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu xuất kho');
    }

    if (stockOut.status !== 'pending') {
      
      return ApiResponse.badRequest(res, 'Phiếu này đã được xử lý hoặc bị hủy');
    }

    for (const item of stockOut.items) {
      const product = await Product.findById(item.product._id);
      if (!product) {
        
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ${item.product.name}`);
      }
      if (product.currentStock < item.quantity) {
        
        return ApiResponse.badRequest(
          res,
          `Sản phẩm "${product.name}" không đủ tồn kho (hiện còn ${product.currentStock})`
        );
      }

      const stockBefore = product.currentStock;
      const stockAfter = stockBefore - item.quantity;

      // Cập nhật tồn kho sản phẩm (không tạo StockTransaction)
      product.currentStock = stockAfter;
      await product.save();

      // Không lưu transaction object nữa; giữ trống hoặc xóa reference
      item.transactionRef = null;
    }

    stockOut.status = 'completed';
    stockOut.approvedBy = req.user._id;
    stockOut.approvedAt = new Date();

    await stockOut.save();
    

    await stockOut.populate([
      { path: 'items.product', select: 'name sku unit currentStock' },
      { path: 'approvedBy', select: 'fullName email' },
    ]);

    // Log activity: approve stock out
    try {
      await logActivity({
        user: req.user && req.user._id,
        action: 'approve_stock_out',
        entityType: 'StockOut',
        entityId: stockOut._id,
        description: `Duyệt phiếu xuất ${stockOut.code}`,
        meta: { code: stockOut.code, approvedBy: req.user && req.user._id, approvedAt: stockOut.approvedAt },
      });
    } catch (_) {}

    return ApiResponse.success(res, { stockOut }, 'Duyệt phiếu xuất kho thành công');
  } catch (error) {
    
    console.error('Approve stock out error:', error);
    return ApiResponse.error(res, error.message);
  } finally {
    
  }
};

/**
 * @desc    Hủy phiếu xuất kho
 * @route   POST /api/stock-outs/:id/cancel
 * @access  Private/Manager
 */
const cancelStockOut = async (req, res) => {
  try {
    const stockOut = await StockOut.findById(req.params.id);

    if (!stockOut) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu xuất kho');
    }

    if (stockOut.status === 'completed') {
      return ApiResponse.badRequest(res, 'Không thể hủy phiếu đã hoàn thành');
    }

    // Sequential rollback logic (no transactions, no sessions)
    // 1) Validate all batches referenced by the stockOut exist and belong to the expected product
    // 2) For each item -> for each batch record: update batch.remainingQuantity += quantity (restore)
    //    then save batch (await)
    //    after batches for item, update product.currentStock += item.quantity and save (await)
    // 3) After handling all items, delete any StockTransaction / MovementLog referencing this stockOut
    // 4) Mark stockOut.status = 'cancelled', set metadata, save (await)

    // Validate referenced batches exist and are associated with the correct product
    for (const item of stockOut.items) {
      if (!item.batchLots || item.batchLots.length === 0) continue;
      for (const bl of item.batchLots) {
        if (!bl.batchLotRef) {
          return ApiResponse.badRequest(res, `Thiếu tham chiếu lô cho sản phẩm ${item.product}`);
        }
        const batch = await BatchLot.findById(bl.batchLotRef);
        if (!batch) {
          return ApiResponse.notFound(res, `Không tìm thấy lô ${bl.batchNumber} (id: ${bl.batchLotRef})`);
        }
        if (batch.product.toString() !== item.product.toString()) {
          return ApiResponse.badRequest(
            res,
            `Lô ${batch.batchNumber} không thuộc sản phẩm trong phiếu (sai batch/product)`
          );
        }
      }
    }

    // Process each item sequentially
    for (const item of stockOut.items) {
      // Restore each batch referenced in the item, in the same order
      if (item.batchLots && item.batchLots.length > 0) {
        for (const bl of item.batchLots) {
          const batch = await BatchLot.findById(bl.batchLotRef);
          if (!batch) {
            // defensive: should not happen because of validation above
            return ApiResponse.notFound(res, `Không tìm thấy lô ${bl.batchNumber}`);
          }

          const restoreQty = Number(bl.quantity || 0);
          if (restoreQty <= 0) continue;

          batch.remainingQuantity = (batch.remainingQuantity || 0) + restoreQty;
          // If batch was depleted, reopen it
          if (batch.remainingQuantity > 0 && batch.status === 'depleted') {
            batch.status = 'active';
          }

          try {
            await batch.save(); // await update batch
          } catch (err) {
            console.error('Error saving batch during cancelStockOut', batch._id.toString(), err && err.message ? err.message : err);
            return ApiResponse.error(res, 'Lỗi khi cập nhật lô hàng trong quá trình hủy phiếu');
          }
        }
      }

      // Update product stock (Stock representation is product.currentStock)
      const product = await Product.findById(item.product);
      if (!product) {
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ${item.product}`);
      }

      product.currentStock = (product.currentStock || 0) + Number(item.quantity || 0);
      try {
        await product.save(); // await update stock
      } catch (err) {
        console.error('Error updating product stock during cancelStockOut', product._id.toString(), err && err.message ? err.message : err);
        return ApiResponse.error(res, 'Lỗi khi cập nhật tồn kho sản phẩm');
      }
    }

    // Delete legacy StockTransaction and MovementLog records related to this stockOut (if models exist)
    try {
      // eslint-disable-next-line global-require
      const StockTransaction = require('../models/StockTransaction');
      try {
        await StockTransaction.deleteMany({ stockOutRef: stockOut._id });
      } catch (err) {
        console.warn('Warning: failed to delete StockTransaction for stockOut', stockOut._id.toString(), err && err.message ? err.message : err);
      }
    } catch (e) {
      // model not present
    }

    try {
      // eslint-disable-next-line global-require
      const MovementLog = require('../models/MovementLog');
      try {
        await MovementLog.deleteMany({ referenceId: stockOut._id });
      } catch (err) {
        console.warn('Warning: failed to delete MovementLog for stockOut', stockOut._id.toString(), err && err.message ? err.message : err);
      }
    } catch (e) {
      // model not present
    }

    // Finally mark stockOut as cancelled
    stockOut.status = 'cancelled';
    stockOut.cancelledBy = req.user && req.user._id;
    stockOut.cancelledAt = new Date();
    try {
      await stockOut.save();
    } catch (err) {
      console.error('Error saving stockOut status during cancel', stockOut._id.toString(), err && err.message ? err.message : err);
      return ApiResponse.error(res, 'Lỗi khi lưu trạng thái phiếu xuất');
    }

    await stockOut.populate([
      { path: 'items.product', select: 'name sku unit currentStock' },
    ]);

    // Log activity: cancel stock out
    try {
      await logActivity({
        user: req.user && req.user._id,
        action: 'cancel_stock_out',
        entityType: 'StockOut',
        entityId: stockOut._id,
        description: `Hủy phiếu xuất ${stockOut.code}`,
        meta: { code: stockOut.code, cancelledBy: req.user && req.user._id, cancelledAt: stockOut.cancelledAt },
      });
    } catch (_) {}

    return ApiResponse.success(res, { stockOut }, 'Hủy phiếu xuất kho thành công');
  } catch (error) {
    console.error('Cancel stock out error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Xóa phiếu xuất kho
 * @route   DELETE /api/stock-outs/:id
 * @access  Private/Manager
 */
const deleteStockOut = async (req, res) => {
  try {
    const stockOut = await StockOut.findById(req.params.id);

    if (!stockOut) {
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu xuất kho');
    }

    if (stockOut.status !== 'pending' && stockOut.status !== 'cancelled') {
      return ApiResponse.badRequest(res, 'Chỉ có thể xóa phiếu đang chờ duyệt hoặc đã hủy');
    }

    await stockOut.deleteOne();

    return ApiResponse.deleted(res, 'Xóa phiếu xuất kho thành công');
  } catch (error) {
    console.error('Delete stock out error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  createStockOut,
  getStockOuts,
  getStockOutById,
  updateStockOut,
  approveStockOut,
  cancelStockOut,
  deleteStockOut,
};
