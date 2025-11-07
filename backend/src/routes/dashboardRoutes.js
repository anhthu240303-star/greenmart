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

// Protect all routes
router.use(protect);

// Dashboard routes
router.get('/overview', getDashboardOverview);
router.get('/stock-chart', getStockChart);
router.get('/top-products', getTopProducts);
router.get('/category-statistics', getCategoryStatistics);
router.get('/recent-transactions', getRecentTransactions);
router.get('/inventory-report', getInventoryReport);
router.get('/export', exportReport);

module.exports = router;