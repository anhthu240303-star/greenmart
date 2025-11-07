const ApiResponse = require('../utils/response');

/**
 * Error Handler Middleware
 */
const errorHandler = (err, req, res, next) => {
  let error = { ...err };
  error.message = err.message;

  // Log lỗi ra console (development)
  if (process.env.NODE_ENV === 'development') {
    console.error('Error Stack:', err.stack);
  }

  // Mongoose bad ObjectId
  if (err.name === 'CastError') {
    const message = 'ID không hợp lệ';
    return ApiResponse.badRequest(res, message);
  }

  // Mongoose duplicate key
  if (err.code === 11000) {
    const field = Object.keys(err.keyValue)[0];
    const message = `${field} đã tồn tại trong hệ thống`;
    return ApiResponse.badRequest(res, message);
  }

  // Mongoose validation error
  if (err.name === 'ValidationError') {
    const errors = Object.values(err.errors).map((val) => val.message);
    return ApiResponse.badRequest(res, 'Dữ liệu không hợp lệ', errors);
  }

  // JWT errors
  if (err.name === 'JsonWebTokenError') {
    return ApiResponse.unauthorized(res, 'Token không hợp lệ');
  }

  if (err.name === 'TokenExpiredError') {
    return ApiResponse.unauthorized(res, 'Token đã hết hạn');
  }

  // Default error
  return ApiResponse.error(
    res,
    error.message || 'Lỗi máy chủ',
    err.statusCode || 500
  );
};

module.exports = errorHandler;