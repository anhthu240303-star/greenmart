const express = require('express');
const router = express.Router();
const {
  createAdjustment,
  getTransactions,
  getTransactionById,
} = require('../controllers/stockTransactionController');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// Bảo vệ tất cả routes
router.use(protect);

// Danh sách & tạo điều chỉnh
router
  .route('/')
  .get(getTransactions)
  .post(authorize('admin', 'warehouse_manager'), createAdjustment);

// Chi tiết giao dịch
router.get('/:id', getTransactionById);

module.exports = router;
