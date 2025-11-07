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

router.put('/:id/activate', authorize('admin'), activateUser);
router.put('/:id/reset-password', authorize('admin'), resetPassword);

module.exports = router;