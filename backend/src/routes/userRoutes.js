const express = require('express');
const router = express.Router();
const {
  getUsers,
  getUserById,
  createUser,
  updateUser,
  deleteUser,
  activateUser,
  resetPassword,
  getUserStatistics,
} = require('../controllers/userController');
const { protect } = require('../middlewares/authMiddleware');
const { authorize } = require('../middlewares/roleMiddleware');

// Protect all routes
router.use(protect);

// Statistics route (before /:id to avoid conflicts)
router.get('/statistics', authorize('admin'), getUserStatistics);

// Activities route (get user activity history)
router.get('/:id/activities', authorize('admin', 'warehouse_manager'), require('../controllers/userController').getUserActivities);

// Main routes
router
  .route('/')
  .get(authorize('admin', 'warehouse_manager'), getUsers)
  .post(authorize('admin'), createUser);

router
  .route('/:id')
  .get(authorize('admin', 'warehouse_manager'), getUserById)
  .put(authorize('admin'), updateUser)
  .delete(authorize('admin'), deleteUser);

// Allow both admin and warehouse_manager to call activate; behavior depends on caller role
router.put('/:id/activate', authorize('admin', 'warehouse_manager'), activateUser);
router.put('/:id/reset-password', authorize('admin'), resetPassword);

module.exports = router;