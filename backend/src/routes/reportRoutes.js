const express = require('express');
const router = express.Router();
const { protect } = require('../middlewares/authMiddleware');

// Import old controller (giữ tạm cho compatibility)
const {
  getInventoryReportPDF,
  getStockInReportPDF,
  getStockOutReportPDF,
  getSummaryReportPDF
} = require('../controllers/reportController');

// Import new controllers
const summaryReportController = require('../controllers/summaryReportController');
const detailReportController = require('../controllers/detailReportController');

// Tất cả routes đều cần authentication
router.use(protect);

/**
 * 🔹 A. BÁO CÁO TỔNG HỢP (Summary Reports)
 * Không chi tiết từng phiếu, chỉ số tổng
 */

// Báo cáo tổng hợp theo kỳ (ngày/tuần/tháng/năm)
router.get('/summary/period/pdf', summaryReportController.getPeriodSummaryPDF);

// Báo cáo chênh lệch kiểm kê theo kỳ (dùng các phiếu kiểm kê hoàn tất)
router.get('/discrepancy/period/pdf', summaryReportController.getDiscrepancyPeriodPDF);

// Báo cáo tồn kho tổng hợp (theo danh mục)
router.get('/summary/inventory/pdf', summaryReportController.getInventorySummaryPDF);

// Báo cáo tổng hợp theo danh mục (xu hướng)
router.get('/summary/category/pdf', summaryReportController.getCategorySummaryPDF);

/**
 * 🔹 B. BÁO CÁO CHI TIẾT (Detail Reports)
 * Chi tiết từng phiếu, từng sản phẩm, từng lô
 */

// Báo cáo nhập kho chi tiết (từng phiếu + SP)
router.get('/detail/stock-in/pdf', detailReportController.getStockInDetailPDF);

// Báo cáo xuất kho chi tiết (từng phiếu + SP + FIFO)
router.get('/detail/stock-out/pdf', detailReportController.getStockOutDetailPDF);

// Báo cáo tồn kho chi tiết theo lô (FIFO/FEFO, kiểm kê)
router.get('/detail/batch-inventory/pdf', detailReportController.getBatchInventoryDetailPDF);

/**
 * 📦 OLD ROUTES (Deprecated - Giữ lại để không break frontend)
 */
router.get('/inventory/pdf', getInventoryReportPDF);
router.get('/stock-in/pdf', getStockInReportPDF);
router.get('/stock-out/pdf', getStockOutReportPDF);
router.get('/summary/pdf', getSummaryReportPDF);

module.exports = router;
