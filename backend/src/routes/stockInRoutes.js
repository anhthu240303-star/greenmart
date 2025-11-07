const express = require('express');
const router = express.Router();
const {
  createStockIn,
  getStockIns,
  getStockInById,
  updateStockIn,
  approveStockIn,
  cancelStockIn,
  deleteStockIn,
} = require('../controllers/stockInController');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// 🔒 Bảo vệ tất cả route
router.use(protect);

// 📋 Danh sách & chi tiết phiếu nhập (warehouse_staff, warehouse_manager, admin)
router
  .route('/')
  .get(authorize('admin', 'warehouse_manager', 'warehouse_staff'), getStockIns)
  .post(authorize('admin', 'warehouse_manager', 'warehouse_staff'), createStockIn);

router
  .route('/:id')
  .get(authorize('admin', 'warehouse_manager', 'warehouse_staff'), getStockInById)
  .put(authorize('admin', 'warehouse_manager', 'warehouse_staff'), updateStockIn)
  .delete(authorize('admin', 'warehouse_manager'), deleteStockIn);

// ✅ Duyệt & ❌ Hủy phiếu (chỉ manager hoặc admin)
router.put('/:id/approve', authorize('admin', 'warehouse_manager'), approveStockIn);
router.put('/:id/cancel', authorize('admin', 'warehouse_manager'), cancelStockIn);

module.exports = router;
