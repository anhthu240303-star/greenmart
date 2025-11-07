const mongoose = require('mongoose');
const StockTransaction = require('../models/StockTransaction');
const Product = require('../models/Product');
const Supplier = require('../models/Supplier');
const ApiResponse = require('../utils/response');
const { generateTransactionCode } = require('../utils/generateCode');

/**
 * @desc    Tạo giao dịch điều chỉnh tồn kho (adjustment)
 * @route   POST /api/stock-transactions
 * @access  Private (admin, warehouse_manager)
 */
const createAdjustment = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { product: productId, quantity, unitPrice = 0, reason, supplier } = req.body;

    if (!productId || typeof quantity !== 'number' || !reason) {
      await session.abortTransaction();
      return ApiResponse.badRequest(res, 'Vui lòng cung cấp product, quantity (số), và reason');
    }

    const product = await Product.findById(productId).session(session);
    if (!product) {
      await session.abortTransaction();
      return ApiResponse.notFound(res, 'Sản phẩm không tồn tại');
    }

    let supplierRef = null;
    if (supplier) {
      const sup = await Supplier.findById(supplier).session(session);
      if (!sup) {
        await session.abortTransaction();
        return ApiResponse.notFound(res, 'Nhà cung cấp không tồn tại');
      }
      supplierRef = sup._id;
    }

    const stockBefore = product.currentStock || 0;
    const stockAfter = stockBefore + quantity; // quantity can be negative for decrease

    if (stockAfter < 0) {
      await session.abortTransaction();
      return ApiResponse.badRequest(res, 'Không thể điều chỉnh làm tồn kho âm');
    }

    const transactionCode = await generateTransactionCode(StockTransaction, 'adjustment');

    const tx = await StockTransaction.create(
      [
        {
          transactionCode,
          type: 'adjustment',
          product: product._id,
          quantity: Math.abs(quantity),
          unitPrice,
          totalAmount: Math.abs(quantity) * unitPrice,
          supplier: supplierRef,
          stockBefore,
          stockAfter,
          status: 'approved',
          reason,
          createdBy: req.user._id,
          approvedBy: req.user._id,
          approvedAt: new Date(),
        },
      ],
      { session }
    );

    product.currentStock = stockAfter;
    await product.save({ session });

    await session.commitTransaction();
    session.endSession();

    await tx[0].populate(['product', 'supplier', 'createdBy', 'approvedBy']);

    return ApiResponse.created(res, { transaction: tx[0] }, 'Tạo giao dịch điều chỉnh thành công');
  } catch (error) {
    await session.abortTransaction();
    session.endSession();
    console.error('Create adjustment error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy danh sách giao dịch
 * @route   GET /api/stock-transactions
 * @access  Private
 */
const getTransactions = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 20,
      product,
      type,
      supplier,
      createdBy,
      startDate,
      endDate,
      sortBy = 'createdAt',
      sortOrder = 'desc',
    } = req.query;

    const query = {};
    if (product) query.product = product;
    if (type) query.type = type;
    if (supplier) query.supplier = supplier;
    if (createdBy) query.createdBy = createdBy;

    if (startDate || endDate) {
      query.createdAt = {};
      if (startDate) query.createdAt.$gte = new Date(startDate);
      if (endDate) query.createdAt.$lte = new Date(endDate);
    }

    const skip = (page - 1) * limit;
    const sort = { [sortBy]: sortOrder === 'desc' ? -1 : 1 };

    const list = await StockTransaction.find(query)
      .populate('product', 'name sku unit')
      .populate('supplier', 'name code')
      .populate('createdBy', 'fullName email')
      .populate('approvedBy', 'fullName email')
      .sort(sort)
      .skip(skip)
      .limit(parseInt(limit));

    const total = await StockTransaction.countDocuments(query);

    return ApiResponse.paginate(
      res,
      list,
      { page: parseInt(page), limit: parseInt(limit), total },
      'Lấy danh sách giao dịch thành công'
    );
  } catch (error) {
    console.error('Get transactions error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy chi tiết giao dịch
 * @route   GET /api/stock-transactions/:id
 * @access  Private
 */
const getTransactionById = async (req, res) => {
  try {
    const tx = await StockTransaction.findById(req.params.id)
      .populate('product')
      .populate('supplier')
      .populate('createdBy', 'fullName email')
      .populate('approvedBy', 'fullName email');

    if (!tx) return ApiResponse.notFound(res, 'Không tìm thấy giao dịch');

    return ApiResponse.success(res, { transaction: tx }, 'Lấy thông tin giao dịch thành công');
  } catch (error) {
    console.error('Get transaction by id error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  createAdjustment,
  getTransactions,
  getTransactionById,
};
