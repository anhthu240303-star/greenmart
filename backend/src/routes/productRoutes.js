const express = require('express');
const router = express.Router();
const {
  createProduct,
  getProducts,
  getProductById,
  updateProduct,
  deleteProduct,
  uploadProductImages,
  deleteProductImage,
  setPrimaryImage,
  getOutOfStockProducts,
  getProductsByCategory,
} = require('../controllers/productController');
const { createProduct: validateCreateProduct, updateProduct: validateUpdateProduct } = require('../validators/productValidator');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');
const { uploadMultiple } = require('../middlewares/uploadMiddleware');

// 🔒 Tất cả route đều yêu cầu đăng nhập
router.use(protect);

// 📋 Lấy danh sách, lọc theo danh mục hoặc sản phẩm hết hàng
router.get('/', getProducts);
router.get('/out-of-stock', getOutOfStockProducts);
router.get('/category/:categoryId', getProductsByCategory);
router.get('/:id', getProductById);

// 🛠️ Tạo, cập nhật, xóa sản phẩm (Admin hoặc Quản lý kho)
router.post('/', authorize('admin', 'warehouse_manager'), validateCreateProduct, createProduct);
router.put('/:id', authorize('admin', 'warehouse_manager'), validateUpdateProduct, updateProduct);
router.delete('/:id', authorize('admin', 'warehouse_manager'), deleteProduct);

// 🖼️ Quản lý ảnh sản phẩm (Admin hoặc Quản lý kho)
router.post(
  '/:id/images',
  authorize('admin', 'warehouse_manager'),
  uploadMultiple('images', 5),
  uploadProductImages
);
router.delete(
  '/:id/images/:imageId',
  authorize('admin', 'warehouse_manager'),
  deleteProductImage
);
router.put(
  '/:id/images/:imageId/primary',
  authorize('admin', 'warehouse_manager'),
  setPrimaryImage
);

module.exports = router;
