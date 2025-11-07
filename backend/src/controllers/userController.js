const User = require('../models/User');
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
      User.find(query).select('-password').sort({ createdAt: -1 }).skip(skip).limit(parseInt(limit)),
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
    return ApiResponse.success(res, user);
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
    await user.save();

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

    user.isActive = true;
    await user.save();

    return ApiResponse.success(res, user.toJSON(), 'Kích hoạt người dùng thành công');
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
    await user.save();

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
