const express = require('express');
const router = express.Router();
const {
  register,
  login,
  getMe,
  changePassword,
  updateProfile,
} = require('../controllers/authController');
const { register: validateRegister, login: validateLogin } = require('../validators/authValidator');
const { protect } = require('../middlewares/authMiddleware');

// Public routes
router.post('/register', validateRegister, register);
router.post('/login', validateLogin, login);

// Protected routes
router.get('/me', protect, getMe);
router.put('/change-password', protect, changePassword);
router.put('/update-profile', protect, updateProfile);

module.exports = router;