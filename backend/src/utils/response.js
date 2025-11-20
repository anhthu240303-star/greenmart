/**
 * Chuẩn hóa response API
 */

class ApiResponse {
  static success(res, data, message = 'Thành công', statusCode = 200) {
    return res.status(statusCode).json({
      success: true,
      message,
      data,
    });
  }

  static error(res, message = 'Có lỗi xảy ra', statusCode = 500, errors = null) {
    return res.status(statusCode).json({
      success: false,
      message,
      errors,
    });
  }

  static created(res, data, message = 'Tạo mới thành công') {
    return this.success(res, data, message, 201);
  }

  static updated(res, data, message = 'Cập nhật thành công') {
    return this.success(res, data, message, 200);
  }

  static deleted(res, message = 'Xóa thành công') {
    return this.success(res, null, message, 200);
  }

  static notFound(res, message = 'Không tìm thấy') {
    return this.error(res, message, 404);
  }

  static badRequest(res, message = 'Yêu cầu không hợp lệ', errors = null) {
    return this.error(res, message, 400, errors);
  }

  static unauthorized(res, message = 'Chưa xác thực') {
    return this.error(res, message, 401);
  }

  static forbidden(res, message = 'Không có quyền truy cập') {
    return this.error(res, message, 403);
  }

  static paginate(res, data, pagination, message = 'Thành công') {
    return res.status(200).json({
      success: true,
      message,
      data,
      pagination: {
        page: pagination.page,
        limit: pagination.limit,
        total: pagination.total,
        totalPages: Math.ceil(pagination.total / pagination.limit),
      },
    });
  }
}

module.exports = ApiResponse;