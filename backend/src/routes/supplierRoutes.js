const express = require('express');
const router = express.Router();
const {
  createSupplier,
  getSuppliers,
  getAllSuppliers,
  getSupplierById,
  updateSupplier,
  deleteSupplier,
  getSupplierStatistics,
} = require('../controllers/supplierController');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// Bảo vệ tất cả route
router.use(protect);

// 📊 Lấy thống kê nhà cung cấp
router.get('/:id/statistics', getSupplierStatistics);

// 🧾 Lấy danh sách, tạo mới
router
  .route('/')
  .get(getSuppliers)
  .post(authorize('admin', 'warehouse_manager'), createSupplier);

// 🔎 Lấy tất cả (đơn giản, không phân trang)
router.get('/all', getAllSuppliers);

// 📄 Chi tiết, cập nhật, xóa
router
  .route('/:id')
  .get(getSupplierById)
  .put(authorize('admin', 'warehouse_manager'), updateSupplier)
  .delete(authorize('admin', 'warehouse_manager'), deleteSupplier);

module.exports = router;
