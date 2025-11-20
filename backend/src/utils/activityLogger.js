const ActivityLog = require('../models/ActivityLog');

/**
 * Log an activity to ActivityLog collection.
 * Swallows errors so logging never breaks main flows.
 */
async function logActivity({ user, action, entityType, entityId, description, meta } = {}) {
  try {
    // Friendly Vietnamese labels for common actions
    const actionLabels = {
      create_stock_in: 'Tạo phiếu nhập',
      approve_stock_in: 'Duyệt phiếu nhập',
      cancel_stock_in: 'Hủy phiếu nhập',
      create_stock_out: 'Tạo phiếu xuất',
      approve_stock_out: 'Duyệt phiếu xuất',
      cancel_stock_out: 'Hủy phiếu xuất',
      change_selling_price: 'Thay đổi giá bán',
      create_product: 'Tạo sản phẩm',
      delete_product: 'Xóa sản phẩm',
      inventory_check_adjust: 'Điều chỉnh tồn kho (kiểm kê)',
      submit_inventory_check: 'Nộp kết quả kiểm kê',
      approve_inventory_check: 'Duyệt kiểm kê và cập nhật tồn kho',
    };

    meta = meta || {};
    if (!meta.actionLabel) meta.actionLabel = actionLabels[action] || action;

    const payload = {
      action,
      entityType,
      entityId,
      user,
      description,
      meta,
    };

    await ActivityLog.create(payload);
  } catch (err) {
    // Do not throw — logging should be best-effort
    try {
      console.warn('Activity log failed:', err && err.message ? err.message : err);
    } catch (_) {}
  }
}

module.exports = {
  logActivity,
};
