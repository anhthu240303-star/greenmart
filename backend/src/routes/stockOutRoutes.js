const express = require('express');
const router = express.Router();
const {
  createStockOut,
  getStockOuts,
  getStockOutById,
  updateStockOut,
  approveStockOut,
  cancelStockOut,
  deleteStockOut,
} = require('../controllers/stockOutController');
const { createStockOut: validateCreateStockOut } = require('../validators/stockValidator');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// 🔒 Bảo vệ tất cả route
router.use(protect);

// 📋 Danh sách & tạo mới phiếu xuất
router
  .route('/')
  .get(getStockOuts)
  .post(authorize('admin', 'warehouse_manager', 'warehouse_staff'), validateCreateStockOut, createStockOut);

// 🔍 Chi tiết, cập nhật, xóa phiếu
router
  .route('/:id')
  .get(getStockOutById)
  .put(authorize('admin', 'warehouse_manager', 'warehouse_staff'), updateStockOut)
  .delete(authorize('admin', 'warehouse_manager'), deleteStockOut);

// ✅ Duyệt hoặc ❌ hủy phiếu xuất
router.put('/:id/approve', authorize('admin', 'warehouse_manager'), approveStockOut);
router.put('/:id/cancel', authorize('admin', 'warehouse_manager'), cancelStockOut);

module.exports = router;
