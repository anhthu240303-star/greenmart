const express = require('express');
const router = express.Router();
const batchLotController = require('../controllers/batchLotController');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// Lấy giá vốn của lô hàng
router.get('/cost', protect, batchLotController.getBatchCost);

// Lấy danh sách lô hàng
router.get('/', protect, batchLotController.listBatchLots);

// Cập nhật lô hàng (admin/warehouse)
router.put('/:id',
  protect,
  authorize('admin', 'warehouse_manager'),
  batchLotController.updateBatchLot
);

module.exports = router;
