const express = require('express');
const router = express.Router();
const {
  createCategory,
  getCategories,
  getAllCategories,
  getCategoryById,
  updateCategory,
  deleteCategory,
  uploadCategoryImage,
} = require('../controllers/categoryController');
const { protect } = require('../middlewares/authMiddleware');
const { isManager } = require('../middlewares/roleMiddleware');
const { uploadSingle } = require('../middlewares/uploadMiddleware');

// 🔒 Bảo vệ tất cả route - chỉ người dùng có token hợp lệ
router.use(protect);

// 📋 Lấy danh sách & chi tiết danh mục
router.get('/', getCategories);
router.get('/all', getAllCategories);
router.get('/:id', getCategoryById);

// ➕➖ Cập nhật dữ liệu danh mục (chỉ Quản lý kho hoặc Admin)
router.post('/', isManager, createCategory);
router.put('/:id', isManager, updateCategory);
router.delete('/:id', isManager, deleteCategory);

// 🖼️ Upload ảnh danh mục (chỉ Quản lý hoặc Admin)
router.post('/:id/image', isManager, uploadSingle('image'), uploadCategoryImage);

module.exports = router;
