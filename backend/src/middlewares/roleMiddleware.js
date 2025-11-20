const ApiResponse = require('../utils/response');

/**
 * Middleware kiểm tra quyền truy cập theo role
 * @param  {...string} roles - Danh sách roles được phép truy cập
 */
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return ApiResponse.unauthorized(res, 'Vui lòng đăng nhập');
    }

    if (!roles.includes(req.user.role)) {
      return ApiResponse.forbidden(
        res,
        `Vai trò ${req.user.role} không có quyền truy cập chức năng này`
      );
    }

    next();
  };
};

/**
 * Kiểm tra quyền Admin
 */
const isAdmin = (req, res, next) => {
  if (!req.user) {
    return ApiResponse.unauthorized(res, 'Vui lòng đăng nhập');
  }

  if (req.user.role !== 'admin') {
    return ApiResponse.forbidden(res, 'Chỉ Admin mới có quyền truy cập');
  }

  next();
};

/**
 * Kiểm tra quyền Manager (Quản lý kho hoặc Admin)
 */
const isManager = (req, res, next) => {
  if (!req.user) {
    return ApiResponse.unauthorized(res, 'Vui lòng đăng nhập');
  }

  const allowedRoles = ['admin', 'warehouse_manager'];
  if (!allowedRoles.includes(req.user.role)) {
    return ApiResponse.forbidden(
      res,
      'Chỉ Admin hoặc Quản lý kho mới có quyền truy cập'
    );
  }

  next();
};

/**
 * Kiểm tra quyền Staff (Nhân viên kho, Quản lý kho, hoặc Admin)
 */
const isStaff = (req, res, next) => {
  if (!req.user) {
    return ApiResponse.unauthorized(res, 'Vui lòng đăng nhập');
  }

  const allowedRoles = ['admin', 'warehouse_manager', 'warehouse_staff'];
  if (!allowedRoles.includes(req.user.role)) {
    return ApiResponse.forbidden(res, 'Không có quyền truy cập');
  }

  next();
};

/**
 * Kiểm tra quyền sở hữu resource hoặc là Admin/Manager
 */
const isOwnerOrManager = (resourceUserIdField = 'createdBy') => {
  return (req, res, next) => {
    if (!req.user) {
      return ApiResponse.unauthorized(res, 'Vui lòng đăng nhập');
    }

    // Admin và Manager có thể truy cập mọi resource
    const managerRoles = ['admin', 'warehouse_manager'];
    if (managerRoles.includes(req.user.role)) {
      return next();
    }

    // Staff chỉ có thể truy cập resource của mình
    const resource = req.resource; // Resource được set từ controller
    if (!resource) {
      return ApiResponse.notFound(res, 'Không tìm thấy dữ liệu');
    }

    const resourceUserId = resource[resourceUserIdField];
    if (resourceUserId.toString() !== req.user._id.toString()) {
      return ApiResponse.forbidden(
        res,
        'Bạn không có quyền truy cập dữ liệu này'
      );
    }

    next();
  };
};

module.exports = {
  authorize,
  isAdmin,
  isManager,
  isStaff,
  isOwnerOrManager,
};