const express = require('express');
const router = express.Router();
const {
  createInventoryCheck,
  getInventoryChecks,
  getInventoryCheckById,
  updateInventoryCheckItems,
  completeInventoryCheck,
  cancelInventoryCheck,
  deleteInventoryCheck,
} = require('../controllers/inventoryController');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// 🔒 Bảo vệ tất cả route - yêu cầu đăng nhập
router.use(protect);

// 📋 Lấy danh sách & chi tiết phiếu kiểm kê
router.get('/', getInventoryChecks);
router.get('/:id', getInventoryCheckById);

// 🧾 Tạo phiếu kiểm kê (Admin hoặc Quản lý kho)
router.post('/', authorize('admin', 'warehouse_manager'), createInventoryCheck);

// ✏️ Cập nhật số lượng thực tế (Nhân viên kho, Quản lý, Admin)
router.put(
  '/:id/items',
  authorize('admin', 'warehouse_manager', 'warehouse_staff'),
  updateInventoryCheckItems
);

// ✅ Hoàn tất kiểm kê (Quản lý, Admin)
router.put('/:id/complete', authorize('admin', 'warehouse_manager'), completeInventoryCheck);

// ❌ Hủy phiếu kiểm kê (Quản lý, Admin)
router.put('/:id/cancel', authorize('admin', 'warehouse_manager'), cancelInventoryCheck);

// 🗑️ Xóa phiếu kiểm kê (chỉ Admin)
router.delete('/:id', authorize('admin'), deleteInventoryCheck);

module.exports = router;
