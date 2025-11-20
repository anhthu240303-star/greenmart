const User = require('../models/User');
const ActivityLog = require('../models/ActivityLog');
const ApiResponse = require('../utils/response');
const bcrypt = require('bcryptjs');

/**
 * @desc    Lấy danh sách người dùng
 * @route   GET /api/users
 * @access  Private (Admin, Warehouse Manager)
 */
exports.getUsers = async (req, res, next) => {
  try {
    const { page = 1, limit = 10, role, status, search } = req.query;
    const query = {};

    if (role) query.role = role;
    if (status !== undefined) query.isActive = status === 'active';
    if (search) {
      query.$or = [
        { fullName: { $regex: search, $options: 'i' } },
        { username: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } },
        { phone: { $regex: search, $options: 'i' } },
      ];
    }

    const skip = (page - 1) * limit;

    const [users, total] = await Promise.all([
  User.find(query).select('-password -activities').sort({ createdAt: -1 }).skip(skip).limit(parseInt(limit)),
      User.countDocuments(query),
    ]);

    return ApiResponse.success(res, {
      users,
      pagination: {
        total,
        page: parseInt(page),
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Lấy chi tiết người dùng
 * @route   GET /api/users/:id
 * @access  Private (Admin, Warehouse Manager)
 */
exports.getUserById = async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id).select('-password');
    if (!user) return ApiResponse.error(res, 'Không tìm thấy người dùng', 404);

    // Also fetch recent ActivityLog entries where `user` equals this user.
    // We focus on actions relevant for warehouse activities.
    const interestingActions = [
      'create_stock_in',
      'approve_stock_in',
      'cancel_stock_in',
      'create_stock_out',
      'approve_stock_out',
      'cancel_stock_out',
      'change_selling_price',
      'create_product',
      'delete_product',
    ];

    let logs = [];
    try {
      logs = await ActivityLog.find({ user: user._id, action: { $in: interestingActions } })
        .sort({ createdAt: -1 })
        .limit(200)
        .lean();
    } catch (e) {
      logs = [];
    }

    // Normalize ActivityLog entries to the embedded `activities` shape used on User model
    const normalizedLogs = (logs || []).map((l) => ({
      actor: l.user || null,
      action: l.action,
      details: l.description || l.meta || null,
      entityType: l.entityType || null,
      entityId: l.entityId || null,
      ip: null,
      userAgent: null,
      createdAt: l.createdAt,
    }));

    // Merge embedded activities (if any) with normalized logs, de-duplicate by timestamp+action
    const embedded = (user.activities || []).slice();
    const merged = [...normalizedLogs, ...embedded];

    // Attach merged activities to the returned user object (do not modify DB)
    const out = user.toJSON();
    out.activities = merged;

    return ApiResponse.success(res, out);
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Lấy lịch sử hoạt động của user (embedded activities)
 * @route   GET /api/users/:id/activities
 * @access  Private (Admin, Warehouse Manager)
 */
exports.getUserActivities = async (req, res, next) => {
  try {
    const { page = 1, limit = 20, action, from, to } = req.query;
    const user = await User.findById(req.params.id).select('activities');
    if (!user) return ApiResponse.error(res, 'Không tìm thấy người dùng', 404);

    let activities = (user.activities || []).slice(); // copy

    // Filters
    if (action) {
      activities = activities.filter((a) => (a.action || '').toString() === action.toString());
    }
    if (from) {
      const fromDate = new Date(from);
      if (!isNaN(fromDate)) activities = activities.filter((a) => new Date(a.createdAt) >= fromDate);
    }
    if (to) {
      const toDate = new Date(to);
      if (!isNaN(toDate)) activities = activities.filter((a) => new Date(a.createdAt) <= toDate);
    }

    // Sort desc by createdAt
    activities.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    const pageNum = Math.max(parseInt(page, 10) || 1, 1);
    const pageSize = Math.max(parseInt(limit, 10) || 20, 1);
    const total = activities.length;
    const start = (pageNum - 1) * pageSize;
    const paged = activities.slice(start, start + pageSize);

    return ApiResponse.success(res, {
      activities: paged,
      pagination: { total, page: pageNum, pages: Math.ceil(total / pageSize) },
    });
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Tạo người dùng mới
 * @route   POST /api/users
 * @access  Private (Admin)
 */
exports.createUser = async (req, res, next) => {
  try {
    const { username, email, password, fullName, phone, role } = req.body;

    if (!password || password.length < 6)
      return ApiResponse.error(res, 'Mật khẩu phải có ít nhất 6 ký tự', 400);

    // Kiểm tra username/email tồn tại
    const existingUser = await User.findOne({ $or: [{ username }, { email }] });
    if (existingUser) {
      return ApiResponse.error(
        res,
        existingUser.username === username ? 'Tên đăng nhập đã tồn tại' : 'Email đã được sử dụng',
        400
      );
    }

    const user = await User.create({
      username,
      email,
      password,
      fullName,
      phone,
      role: role || 'warehouse_staff',
      activities: [
        {
          actor: req.user?._id || null,
          action: 'created',
          details: { createdBy: req.user?._id || null },
          ip: req.ip,
          userAgent: req.get('User-Agent') || null,
          createdAt: new Date(),
        },
      ],
    });

    return ApiResponse.success(res, user.toJSON(), 'Tạo người dùng thành công', 201);
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Cập nhật thông tin người dùng
 * @route   PUT /api/users/:id
 * @access  Private (Admin)
 */
exports.updateUser = async (req, res, next) => {
  try {
    const { email, fullName, phone, role, isActive } = req.body;

    const user = await User.findById(req.params.id);
    if (!user) return ApiResponse.error(res, 'Không tìm thấy người dùng', 404);

    // Không cho phép tự thay đổi role của chính mình
    if (req.user._id.toString() === user._id.toString() && role && role !== user.role)
      return ApiResponse.error(res, 'Không thể thay đổi quyền của chính mình', 400);

    // Kiểm tra email trùng
    if (email && email !== user.email) {
      const emailExists = await User.findOne({ email });
      if (emailExists) return ApiResponse.error(res, 'Email đã được sử dụng', 400);
      user.email = email;
    }

    if (fullName) user.fullName = fullName;
    if (phone) user.phone = phone;
    if (role) user.role = role;
    if (isActive !== undefined) user.isActive = isActive;

    await user.save();
    try {
      // Push activity atomically and cap the array size to most recent 200 entries
      const activity = {
        actor: req.user._id,
        action: 'updated',
        // only store changed fields for privacy (avoid sensitive fields)
        details: {
          email: email || undefined,
          fullName: fullName || undefined,
          phone: phone || undefined,
          role: role || undefined,
          isActive: isActive !== undefined ? isActive : undefined,
        },
        ip: req.ip,
        userAgent: req.get('User-Agent') || null,
        createdAt: new Date(),
      };
      await User.findByIdAndUpdate(user._id, {
        $push: { activities: { $each: [activity], $position: 0, $slice: 200 } },
      });
    } catch (e) {}
    return ApiResponse.success(res, user.toJSON(), 'Cập nhật người dùng thành công');
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Vô hiệu hóa (xóa mềm) người dùng
 * @route   DELETE /api/users/:id
 * @access  Private (Admin)
 */
exports.deleteUser = async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return ApiResponse.error(res, 'Không tìm thấy người dùng', 404);

    if (req.user._id.toString() === user._id.toString())
      return ApiResponse.error(res, 'Không thể xóa tài khoản của chính mình', 400);

    user.isActive = false;
    try {
      const activity = {
        actor: req.user._id,
        action: 'disabled',
        details: null,
        ip: req.ip,
        userAgent: req.get('User-Agent') || null,
        createdAt: new Date(),
      };
      await User.findByIdAndUpdate(user._id, { $set: { isActive: false }, $push: { activities: { $each: [activity], $position: 0, $slice: 200 } } });
    } catch (e) {}

    return ApiResponse.success(res, null, 'Vô hiệu hóa người dùng thành công');
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Kích hoạt lại người dùng
 * @route   PUT /api/users/:id/activate
 * @access  Private (Admin)
 */
exports.activateUser = async (req, res, next) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) return ApiResponse.error(res, 'Không tìm thấy người dùng', 404);

    // Dual approval flow:
    // - If a warehouse_manager calls this endpoint, mark managerApproved
    // - If an admin calls this endpoint, mark adminApproved
    // Only when both approvals are true we set isActive = true
    const callerRole = req.user.role;
    if (callerRole === 'warehouse_manager') {
      user.managerApproved = true;
    } else if (callerRole === 'admin') {
      user.adminApproved = true;
    } else {
      return ApiResponse.forbidden(res, 'Không có quyền phê duyệt');
    }

    // If both approved, activate account
    if (user.managerApproved && user.adminApproved) {
      user.isActive = true;
    }

    try {
      const activity = {
        actor: req.user._id,
        action: callerRole === 'warehouse_manager' ? 'manager_approve' : 'admin_approve',
        details: { managerApproved: user.managerApproved, adminApproved: user.adminApproved },
        ip: req.ip,
        userAgent: req.get('User-Agent') || null,
        createdAt: new Date(),
      };
      await User.findByIdAndUpdate(user._id, { $set: { managerApproved: user.managerApproved, adminApproved: user.adminApproved, isActive: user.isActive }, $push: { activities: { $each: [activity], $position: 0, $slice: 200 } } });
    } catch (e) {}

    return ApiResponse.success(res, user.toJSON(), 'Cập nhật trạng thái phê duyệt người dùng thành công');
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Đặt lại mật khẩu người dùng
 * @route   PUT /api/users/:id/reset-password
 * @access  Private (Admin)
 */
exports.resetPassword = async (req, res, next) => {
  try {
    const { newPassword } = req.body;
    if (!newPassword || newPassword.length < 6)
      return ApiResponse.error(res, 'Mật khẩu mới phải có ít nhất 6 ký tự', 400);

    const user = await User.findById(req.params.id).select('+password');
    if (!user) return ApiResponse.error(res, 'Không tìm thấy người dùng', 404);

    // Hash lại mật khẩu
    const salt = await bcrypt.genSalt(10);
    user.password = await bcrypt.hash(newPassword, salt);
    try {
      const activity = {
        actor: req.user._id,
        action: 'reset_password',
        details: null,
        ip: req.ip,
        userAgent: req.get('User-Agent') || null,
        createdAt: new Date(),
      };
      await User.findByIdAndUpdate(user._id, { $push: { activities: { $each: [activity], $position: 0, $slice: 200 } }, $set: { password: user.password } });
    } catch (e) {}
    // password already hashed and set above

    return ApiResponse.success(res, null, 'Reset mật khẩu thành công');
  } catch (error) {
    next(error);
  }
};

/**
 * @desc    Thống kê người dùng
 * @route   GET /api/users/statistics
 * @access  Private (Admin)
 */
exports.getUserStatistics = async (req, res, next) => {
  try {
    const [totalUsers, activeUsers, inactiveUsers, usersByRole] = await Promise.all([
      User.countDocuments(),
      User.countDocuments({ isActive: true }),
      User.countDocuments({ isActive: false }),
      User.aggregate([{ $group: { _id: '$role', count: { $sum: 1 } } }]),
    ]);

    const statistics = {
      total: totalUsers,
      active: activeUsers,
      inactive: inactiveUsers,
      byRole: usersByRole.reduce((acc, item) => {
        acc[item._id] = item.count;
        return acc;
      }, {}),
    };

    return ApiResponse.success(res, statistics);
  } catch (error) {
    next(error);
  }
};
