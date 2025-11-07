const jwt = require('jsonwebtoken');
const User = require('../models/User');
const ApiResponse = require('../utils/response');

/**
 * Middleware xác thực người dùng
 */
const protect = async (req, res, next) => {
  try {
    let token;

    // Lấy token từ header
    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith('Bearer')
    ) {
      token = req.headers.authorization.split(' ')[1];
    }

    // Kiểm tra token có tồn tại
    if (!token) {
      return ApiResponse.unauthorized(res, 'Vui lòng đăng nhập để truy cập');
    }

    try {
      // Verify token
      const decoded = jwt.verify(token, process.env.JWT_SECRET);

      // Lấy thông tin user từ token
      req.user = await User.findById(decoded.id).select('-password');

      if (!req.user) {
        return ApiResponse.unauthorized(res, 'Người dùng không tồn tại');
      }

      // Kiểm tra user có active không
      if (!req.user.isActive) {
        return ApiResponse.forbidden(res, 'Tài khoản đã bị vô hiệu hóa');
      }

      next();
    } catch (error) {
      return ApiResponse.unauthorized(res, 'Token không hợp lệ hoặc đã hết hạn');
    }
  } catch (error) {
    return ApiResponse.error(res, 'Lỗi xác thực', 500);
  }
};

/**
 * Middleware kiểm tra quyền optional (không bắt buộc đăng nhập)
 */
const optionalAuth = async (req, res, next) => {
  try {
    let token;

    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith('Bearer')
    ) {
      token = req.headers.authorization.split(' ')[1];
    }

    if (token) {
      try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        req.user = await User.findById(decoded.id).select('-password');
      } catch (error) {
        // Nếu token không hợp lệ, vẫn cho phép truy cập nhưng req.user = null
        req.user = null;
      }
    }

    next();
  } catch (error) {
    next();
  }
};

module.exports = { protect, optionalAuth };