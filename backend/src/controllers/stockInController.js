const mongoose = require('mongoose');
const StockIn = require('../models/StockIn');
const Product = require('../models/Product');
const Supplier = require('../models/Supplier');
const StockTransaction = require('../models/StockTransaction');
const ApiResponse = require('../utils/response');
const { generateStockInCode, generateTransactionCode } = require('../utils/generateCode');

/**
 * @desc    Tạo phiếu nhập kho mới
 * @route   POST /api/stock-in
 * @access  Private (Warehouse Staff / Manager)
 */
const createStockIn = async (req, res) => {
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const { supplier, items, importDate } = req.body;

    if (!supplier || !items || items.length === 0) {
      await session.abortTransaction();
      return ApiResponse.badRequest(res, 'Vui lòng nhập đầy đủ thông tin phiếu nhập');
    }

    // Kiểm tra supplier
    const supplierExists = await Supplier.findById(supplier).session(session);
    if (!supplierExists) {
      await session.abortTransaction();
      return ApiResponse.notFound(res, 'Nhà cung cấp không tồn tại');
    }

    // Kiểm tra sản phẩm trong danh sách nhập
    for (const item of items) {
      const product = await Product.findById(item.product).session(session);
      if (!product) {
        await session.abortTransaction();
        return ApiResponse.notFound(res, `Sản phẩm với ID ${item.product} không tồn tại`);
      }
    }

    // Sinh mã phiếu nhập
    const code = await generateStockInCode(StockIn);

    const stockIn = await StockIn.create(
      [
        {
          code,
          supplier,
          items,
          importDate: importDate || Date.now(),
          createdBy: req.user._id,
        },
      ],
      { session }
    );

    await session.commitTransaction();

    await stockIn[0].populate([
      { path: 'supplier', select: 'name code phone' },
      { path: 'items.product', select: 'name sku unit' },
      { path: 'createdBy', select: 'fullName email' },
    ]);

    return ApiResponse.created(res, { stockIn: stockIn[0] }, 'Tạo phiếu nhập kho thành công');
  } catch (error) {
    await session.abortTransaction();
    console.error('Create stock in error:', error);
    return ApiResponse.error(res, error.message);
  } finally {
    session.endSession();
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
      .populate('supplier')
      .populate('items.product')
      .populate('createdBy', 'fullName email')
      .populate('approvedBy', 'fullName email');

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
  const session = await mongoose.startSession();
  session.startTransaction();

  try {
    const stockIn = await StockIn.findById(req.params.id)
      .populate('items.product')
      .session(session);

    if (!stockIn) {
      await session.abortTransaction();
      return ApiResponse.notFound(res, 'Không tìm thấy phiếu nhập kho');
    }

    if (stockIn.status !== 'pending') {
      await session.abortTransaction();
      return ApiResponse.badRequest(res, 'Phiếu nhập này đã được xử lý hoặc bị hủy');
    }

    for (const item of stockIn.items) {
      const product = await Product.findById(item.product._id).session(session);
      if (!product) {
        await session.abortTransaction();
        return ApiResponse.notFound(res, `Không tìm thấy sản phẩm ${item.product.name}`);
      }

      const stockBefore = product.currentStock;
      const stockAfter = stockBefore + item.quantity;

      const transactionCode = await generateTransactionCode(StockTransaction, 'in');
      const transaction = await StockTransaction.create(
        [
          {
            transactionCode,
            type: 'in',
            product: product._id,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            supplier: stockIn.supplier,
            stockBefore,
            stockAfter,
            status: 'approved',
            createdBy: stockIn.createdBy,
            approvedBy: req.user._id,
            approvedAt: new Date(),
            stockInRef: stockIn._id,
          },
        ],
        { session }
      );

      // Cập nhật tồn kho sản phẩm
      product.currentStock = stockAfter;
      await product.save({ session });

      // Ghi lại reference transaction
      item.transactionRef = transaction[0]._id;
    }

    stockIn.status = 'completed';
    stockIn.approvedBy = req.user._id;
    stockIn.approvedAt = new Date();

    await stockIn.save({ session });
    await session.commitTransaction();

    await stockIn.populate([
      { path: 'supplier', select: 'name code' },
      { path: 'items.product', select: 'name sku unit currentStock' },
      { path: 'approvedBy', select: 'fullName email' },
    ]);

    return ApiResponse.success(res, { stockIn }, 'Duyệt phiếu nhập kho thành công');
  } catch (error) {
    await session.abortTransaction();
    console.error('Approve stock in error:', error);
    return ApiResponse.error(res, error.message);
  } finally {
    session.endSession();
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

    stockIn.status = 'cancelled';
    await stockIn.save();

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
