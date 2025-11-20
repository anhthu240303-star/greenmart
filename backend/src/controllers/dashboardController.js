const Product = require('../models/Product');
const StockIn = require('../models/StockIn');
const StockOut = require('../models/StockOut');
const Category = require('../models/Category');
const Supplier = require('../models/Supplier');
const ApiResponse = require('../utils/response');

/**
 * @desc    Lấy thống kê tổng quan dashboard
 * @route   GET /api/dashboard/overview
 * @access  Private
 */
exports.getDashboardOverview = async (req, res, next) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const [
      totalProducts,
      totalCategories,
      totalSuppliers,
      lowStockProducts,
      totalStockValue,
      todayStockIns,
      todayStockOuts,
      pendingStockIns,
      pendingStockOuts
    ] = await Promise.all([
      // Tổng số sản phẩm (tất cả)
      Product.countDocuments(),
      
      // Tổng số danh mục
      Category.countDocuments(),
      
      // Tổng số nhà cung cấp
      Supplier.countDocuments(),
      
      // Sản phẩm sắp hết hàng (currentStock <= minStock OR total remaining across batches < minStock)
      Product.countLowStock(),
      
      // Tổng giá trị tồn kho
      Product.aggregate([
        { $match: {} },
        {
          $group: {
            _id: null,
            totalValue: {
              $sum: { $multiply: ['$currentStock', '$costPrice'] }
            }
          }
        }
      ]).then(result => result),
      
      // Số phiếu nhập hôm nay
      StockIn.countDocuments({
        createdAt: { $gte: today }
      }),
      
      // Số phiếu xuất hôm nay
      StockOut.countDocuments({
        createdAt: { $gte: today }
      }),
      
      // Phiếu nhập chờ duyệt
      StockIn.countDocuments({ status: 'pending' }),
      
      // Phiếu xuất chờ duyệt
      StockOut.countDocuments({ status: 'pending' })
    ]);

    const overview = {
      inventory: {
        totalProducts,
        totalCategories,
        totalSuppliers,
        lowStockProducts,
        totalStockValue: totalStockValue[0]?.totalValue || 0
      },
      today: {
        stockIns: todayStockIns,
        stockOuts: todayStockOuts
      },
      pending: {
        stockIns: pendingStockIns,
        stockOuts: pendingStockOuts
      }
    };

    ApiResponse.success(res, overview);
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Lấy biểu đồ nhập/xuất kho theo thời gian
 * @route   GET /api/dashboard/stock-chart
 * @access  Private
 */
exports.getStockChart = async (req, res, next) => {
  try {
    const { period = '7days' } = req.query;
    
    let days = 7;
    if (period === '30days') days = 30;
    if (period === '90days') days = 90;

    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);
    startDate.setHours(0, 0, 0, 0);

    // Lấy dữ liệu nhập kho
    const stockInsData = await StockIn.aggregate([
      {
        $match: {
          createdAt: { $gte: startDate },
          status: 'approved'
        }
      },
      {
        $group: {
          _id: {
            $dateToString: { format: '%Y-%m-%d', date: '$createdAt' }
          },
          count: { $sum: 1 },
          totalAmount: { $sum: '$totalAmount' }
        }
      },
      { $sort: { _id: 1 } }
    ]);

    // Lấy dữ liệu xuất kho
    const stockOutsData = await StockOut.aggregate([
      {
        $match: {
          createdAt: { $gte: startDate },
          status: 'approved'
        }
      },
      {
        $group: {
          _id: {
            $dateToString: { format: '%Y-%m-%d', date: '$createdAt' }
          },
          count: { $sum: 1 },
          totalAmount: { $sum: '$totalAmount' }
        }
      },
      { $sort: { _id: 1 } }
    ]);

    // Tạo mảng dates đầy đủ
    const dates = [];
    for (let i = 0; i < days; i++) {
      const date = new Date(startDate);
      date.setDate(date.getDate() + i);
      dates.push(date.toISOString().split('T')[0]);
    }

    // Map data với dates
    const chartData = dates.map(date => {
      const stockIn = stockInsData.find(item => item._id === date);
      const stockOut = stockOutsData.find(item => item._id === date);

      return {
        date,
        stockIn: {
          count: stockIn?.count || 0,
          amount: stockIn?.totalAmount || 0
        },
        stockOut: {
          count: stockOut?.count || 0,
          amount: stockOut?.totalAmount || 0
        }
      };
    });

    ApiResponse.success(res, chartData);
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Lấy top sản phẩm
 * @route   GET /api/dashboard/top-products
 * @access  Private
 */
exports.getTopProducts = async (req, res, next) => {
  try {
    const { type = 'most_stock', limit = 10 } = req.query;

    let sortCriteria = {};
    
    switch (type) {
      case 'most_stock':
        sortCriteria = { currentStock: -1 };
        break;
      case 'least_stock':
        sortCriteria = { currentStock: 1 };
        break;
      case 'highest_value':
        // Sản phẩm có giá trị tồn kho cao nhất
        break;
      case 'low_stock':
        // Sản phẩm sắp hết hàng
        break;
      default:
        sortCriteria = { stock: -1 };
    }

    let products;

    if (type === 'highest_value') {
      // Tính giá trị tồn kho = currentStock * costPrice
      products = await Product.aggregate([
        { $match: { status: 'active' } },
        {
          $addFields: {
            stockValue: { $multiply: ['$currentStock', '$costPrice'] }
          }
        },
        { $sort: { stockValue: -1 } },
        { $limit: parseInt(limit) },
        {
          $lookup: {
            from: 'categories',
            localField: 'category',
            foreignField: '_id',
            as: 'category'
          }
        },
        { $unwind: '$category' }
      ]);
    } else if (type === 'low_stock') {
      // Sản phẩm có currentStock = 0
      products = await Product.find({
        status: 'active',
        currentStock: 0
      })
        .populate('category', 'name')
        .sort({ currentStock: 1 })
        .limit(parseInt(limit));
    } else {
      products = await Product.find({ status: 'active' })
        .populate('category', 'name')
        .sort(sortCriteria)
        .limit(parseInt(limit));
    }

    ApiResponse.success(res, products);
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Lấy thống kê theo danh mục
 * @route   GET /api/dashboard/category-statistics
 * @access  Private
 */
exports.getCategoryStatistics = async (req, res, next) => {
  try {
    const statistics = await Product.aggregate([
      { $match: { status: 'active' } },
      {
        $group: {
          _id: '$category',
          totalProducts: { $sum: 1 },
          totalStock: { $sum: '$currentStock' },
          totalValue: {
            $sum: { $multiply: ['$currentStock', '$costPrice'] }
          }
        }
      },
      {
        $lookup: {
          from: 'categories',
          localField: '_id',
          foreignField: '_id',
          as: 'category'
        }
      },
      { $unwind: '$category' },
      {
        $project: {
          _id: 1,
          categoryName: '$category.name',
          totalProducts: 1,
          totalStock: 1,
          totalValue: 1
        }
      },
      { $sort: { totalValue: -1 } }
    ]);

    ApiResponse.success(res, statistics);
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Lấy lịch sử giao dịch gần đây
 * @route   GET /api/dashboard/recent-transactions
 * @access  Private
 */
exports.getRecentTransactions = async (req, res, next) => {
  try {
    const { limit = 10 } = req.query;
    // Transactions feature removed — return empty list
    ApiResponse.success(res, []); 
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Lấy báo cáo tồn kho
 * @route   GET /api/dashboard/inventory-report
 * @access  Private
 */
exports.getInventoryReport = async (req, res, next) => {
  try {
    const { categoryId, supplierId } = req.query;

    const query = { status: 'active' };
    
    if (categoryId) {
      query.category = categoryId;
    }

    const products = await Product.find(query)
      .populate('category', 'name')
      .populate('defaultSupplier', 'name code')
      .select('name barcode currentStock costPrice sellingPrice unit')
      .sort({ name: 1 });

    // Tính toán các chỉ số
    const report = {
      products: products.map(product => ({
        ...product.toObject(),
        stockValue: product.currentStock * product.costPrice,
        stockStatus: product.currentStock === 0 ? 'out_of_stock' : 'normal'
      })),
      summary: {
        totalProducts: products.length,
        totalStock: products.reduce((sum, p) => sum + p.currentStock, 0),
        totalValue: products.reduce((sum, p) => sum + (p.currentStock * p.costPrice), 0),
        outOfStockCount: products.filter(p => p.currentStock === 0).length
      }
    };

    ApiResponse.success(res, report);
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Export báo cáo Excel (placeholder - cần implement thêm)
 * @route   GET /api/dashboard/export
 * @access  Private
 */
exports.exportReport = async (req, res, next) => {
  try {
    // TODO: Implement Excel export using exceljs or similar library
    ApiResponse.success(res, { message: 'Export feature - To be implemented' });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Lấy danh sách sản phẩm sắp hết hàng (chi tiết)
 * @route   GET /api/dashboard/low-stock
 * @access  Private
 */
exports.getLowStockProducts = async (req, res, next) => {
  try {
    const { limit = 50, skip = 0 } = req.query;
    const products = await Product.findLowStockProducts({ limit: parseInt(limit, 10), skip: parseInt(skip, 10) });

    // Map to include helpful fields
    const mapped = products.map(p => ({
      _id: p._id,
      name: p.name,
      barcode: p.barcode,
      currentStock: p.currentStock,
      minStock: p.minStock,
      batchesRemaining: p.batchesRemaining || 0,
      reason: p.currentStock <= p.minStock ? 'currentStock' : ( (p.batchesRemaining || 0) < p.minStock ? 'batchesRemaining' : 'unknown')
    }));

    ApiResponse.success(res, mapped);
  } catch (error) {
    next(error);
  }
};