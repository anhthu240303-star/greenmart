const express = require('express');
const router = express.Router();
const { getActivityLogs } = require('../controllers/activityController');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// List activity logs (protected, admin/warehouse_manager only)
router.get('/', protect, authorize('admin', 'warehouse_manager'), getActivityLogs);

module.exports = router;
