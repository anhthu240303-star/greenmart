const express = require('express');
const router = express.Router();
const {
  getDashboardOverview,
  getStockChart,
  getTopProducts,
  getCategoryStatistics,
  getRecentTransactions,
  getInventoryReport,
  exportReport,
} = require('../controllers/dashboardController');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// Protect all routes
router.use(protect);

// Dashboard routes (restricted to Admin and Warehouse Manager)
router.get('/overview', authorize('admin', 'warehouse_manager'), getDashboardOverview);
router.get('/stock-chart', authorize('admin', 'warehouse_manager'), getStockChart);
router.get('/low-stock', authorize('admin', 'warehouse_manager'), require('../controllers/dashboardController').getLowStockProducts);
router.get('/top-products', authorize('admin', 'warehouse_manager'), getTopProducts);
router.get('/category-statistics', authorize('admin', 'warehouse_manager'), getCategoryStatistics);
router.get('/recent-transactions', authorize('admin', 'warehouse_manager'), getRecentTransactions);
router.get('/inventory-report', authorize('admin', 'warehouse_manager'), getInventoryReport);
router.get('/export', authorize('admin', 'warehouse_manager'), exportReport);

module.exports = router;