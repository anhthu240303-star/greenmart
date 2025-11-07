const mongoose = require('mongoose');
const StockOut = require('../models/StockOut');
const Product = require('../models/Product');
const StockTransaction = require('../models/StockTransaction');
const ApiResponse = require('../utils/response');
const { generateTransactionCode, generateStockOutCode } = require('../utils/generateCode');

/**
 * @desc    Tạo phiếu xuất kho mới
 * @route   POST /api/stock-outs
 * @access  Private (Warehouse Staff, Manager)
 */
const createStockOut = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { type, items, issueDate } = req.body;

    if (!type || !items || items.length === 0) {
      await session.abortTransaction();
      return ApiResponse.badRequest(res, 'Vui lòng nhập đầy đủ thông tin phiếu xuất kho');
    }

    // Validate sản phẩm
    for (const item of items) {
      const product = await Product.findById(item.product).session(session);
      if (!product) {
        await session.abortTransaction();
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ID: ${item.product}`);
      }
      if (product.currentStock < item.quantity) {
        await session.abortTransaction();
        return ApiResponse.badRequest(
          res,
          `Sản phẩm "${product.name}" không đủ tồn kho (hiện còn ${product.currentStock})`
        );
      }
    }

    // Sinh mã phiếu xuất
    const code = await generateStockOutCode(StockOut);

    // Tạo phiếu xuất kho
    const stockOut = await StockOut.create(
      [
        {
          code,
          type,
          items,
          issueDate: issueDate || Date.now(),
          createdBy: req.user._id,
        },
      ],
      { session }
    );

    await session.commitTransaction();

    await stockOut[0].populate([
      { path: 'items.product', select: 'name sku unit currentStock' },
      { path: 'createdBy', select: 'fullName email' },
    ]);

    return ApiResponse.created(res, { stockOut: stockOut[0] }, 'Tạo phiếu xuất kho thành công');
  } catch (error) {
    await session.abortTransaction();
    console.error('Create stock out error:', error);
    return ApiResponse.error(res, error.message);
  } finally {
    session.endSession();
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
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const stockOut = await StockOut.findById(req.params.id)
      .populate('items.product')
      .session(session);

    if (!stockOut) {
      await session.abortTransaction();
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu xuất kho');
    }

    if (stockOut.status !== 'pending') {
      await session.abortTransaction();
      return ApiResponse.badRequest(res, 'Phiếu này đã được xử lý hoặc bị hủy');
    }

    for (const item of stockOut.items) {
      const product = await Product.findById(item.product._id).session(session);
      if (!product) {
        await session.abortTransaction();
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ${item.product.name}`);
      }
      if (product.currentStock < item.quantity) {
        await session.abortTransaction();
        return ApiResponse.badRequest(
          res,
          `Sản phẩm "${product.name}" không đủ tồn kho (hiện còn ${product.currentStock})`
        );
      }

      const stockBefore = product.currentStock;
      const stockAfter = stockBefore - item.quantity;

      // Tạo transaction
      const transactionCode = await generateTransactionCode(StockTransaction, 'out');
      const transaction = await StockTransaction.create(
        [
          {
            transactionCode,
            type: 'out',
            product: product._id,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            stockBefore,
            stockAfter,
            status: 'approved',
            createdBy: stockOut.createdBy,
            approvedBy: req.user._id,
            approvedAt: new Date(),
            stockOutRef: stockOut._id,
          },
        ],
        { session }
      );

      product.currentStock = stockAfter;
      await product.save({ session });

      item.transactionRef = transaction[0]._id;
    }

    stockOut.status = 'completed';
    stockOut.approvedBy = req.user._id;
    stockOut.approvedAt = new Date();

    await stockOut.save({ session });
    await session.commitTransaction();

    await stockOut.populate([
      { path: 'items.product', select: 'name sku unit currentStock' },
      { path: 'approvedBy', select: 'fullName email' },
    ]);

    return ApiResponse.success(res, { stockOut }, 'Duyệt phiếu xuất kho thành công');
  } catch (error) {
    await session.abortTransaction();
    console.error('Approve stock out error:', error);
    return ApiResponse.error(res, error.message);
  } finally {
    session.endSession();
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

    stockOut.status = 'cancelled';
    await stockOut.save();

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
