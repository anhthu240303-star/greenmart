const jwt = require('jsonwebtoken');
const User = require('../models/User');
const ApiResponse = require('../utils/response');

/**
 * Tạo JWT token
 */
const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRE,
  });
};



/**
 * @desc    Đăng nhập
 * @route   POST /api/auth/login
 * @access  Public
 */
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate
    if (!email || !password) {
      return ApiResponse.badRequest(
        res,
        'Vui lòng nhập email và mật khẩu'
      );
    }

    // Tìm user và include password
    const user = await User.findOne({ email }).select('+password');

    if (!user) {
      return ApiResponse.unauthorized(res, 'Email hoặc mật khẩu không đúng');
    }

    // Kiểm tra account active
    if (!user.isActive) {
      return ApiResponse.forbidden(res, 'Tài khoản chưa được kích hoạt hoặc đang chờ phê duyệt');
    }

    // Kiểm tra password
    const isPasswordMatch = await user.matchPassword(password);

    if (!isPasswordMatch) {
      return ApiResponse.unauthorized(res, 'Email hoặc mật khẩu không đúng');
    }

    // Cập nhật lastLogin
    // Update lastLogin and push activity atomically to avoid races
    const activity = {
      actor: user._id,
      action: 'login',
      details: { message: 'User logged in' },
      ip: req.ip,
      userAgent: req.get('User-Agent') || null,
      createdAt: new Date(),
    };
    try {
      await User.findByIdAndUpdate(user._id, { $set: { lastLogin: new Date() }, $push: { activities: { $each: [activity], $position: 0, $slice: 200 } } });
    } catch (e) {
      // ignore logging failures
    }

    // Tạo token
    const token = generateToken(user._id);

    return ApiResponse.success(
      res,
      {
        user: {
          _id: user._id,
          username: user.username,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
          avatar: user.avatar,
          lastLogin: user.lastLogin,
        },
        token,
      },
      'Đăng nhập thành công'
    );
  } catch (error) {
    console.error('Login error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Lấy thông tin user hiện tại
 * @route   GET /api/auth/me
 * @access  Private
 */
const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user._id);

    return ApiResponse.success(
      res,
      {
        user,
      },
      'Lấy thông tin thành công'
    );
  } catch (error) {
    console.error('GetMe error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Đổi mật khẩu
 * @route   PUT /api/auth/change-password
 * @access  Private
 */
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    // Validate
    if (!currentPassword || !newPassword) {
      return ApiResponse.badRequest(
        res,
        'Vui lòng nhập đầy đủ thông tin'
      );
    }

    // Lấy user với password
    const user = await User.findById(req.user._id).select('+password');

    // Kiểm tra password hiện tại
    const isPasswordMatch = await user.matchPassword(currentPassword);

    if (!isPasswordMatch) {
      return ApiResponse.badRequest(res, 'Mật khẩu hiện tại không đúng');
    }

    // Cập nhật password mới
    user.password = newPassword;
    await user.save();
    try {
      const activity = {
        actor: req.user._id,
        action: 'change_password',
        details: null,
        ip: req.ip,
        userAgent: req.get('User-Agent') || null,
        createdAt: new Date(),
      };
      await User.findByIdAndUpdate(user._id, { $push: { activities: { $each: [activity], $position: 0, $slice: 200 } } });
    } catch (e) {}

    return ApiResponse.success(res, null, 'Đổi mật khẩu thành công');
  } catch (error) {
    console.error('Change password error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Cập nhật thông tin cá nhân
 * @route   PUT /api/auth/update-profile
 * @access  Private
 */
const updateProfile = async (req, res) => {
  try {
    const { fullName, phone } = req.body;

    const user = await User.findById(req.user._id);

    if (fullName) user.fullName = fullName;
    if (phone) user.phone = phone;

    await user.save();
    try {
      const activity = {
        actor: req.user._id,
        action: 'update_profile',
        details: { fullName: fullName || undefined, phone: phone || undefined },
        ip: req.ip,
        userAgent: req.get('User-Agent') || null,
        createdAt: new Date(),
      };
      await User.findByIdAndUpdate(user._id, { $push: { activities: { $each: [activity], $position: 0, $slice: 200 } } });
    } catch (e) {}

    return ApiResponse.updated(res, { user }, 'Cập nhật thành công');
  } catch (error) {
    console.error('Update profile error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  login,
  getMe,
  changePassword,
  updateProfile,
};