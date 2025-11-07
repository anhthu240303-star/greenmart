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
 * @desc    Đăng ký tài khoản mới
 * @route   POST /api/auth/register
 * @access  Public
 */
const register = async (req, res) => {
  try {
    const { username, email, password, fullName, phone, role } = req.body;

    // Kiểm tra user đã tồn tại
    const userExists = await User.findOne({ $or: [{ email }, { username }] });

    if (userExists) {
      return ApiResponse.badRequest(
        res,
        'Email hoặc tên đăng nhập đã tồn tại'
      );
    }

    // Tạo user mới
    const user = await User.create({
      username,
      email,
      password,
      fullName,
      phone,
      role: role || 'warehouse_staff',
    });

    // Tạo token
    const token = generateToken(user._id);

    return ApiResponse.created(
      res,
      {
        user: {
          _id: user._id,
          username: user.username,
          email: user.email,
          fullName: user.fullName,
          role: user.role,
          avatar: user.avatar,
        },
        token,
      },
      'Đăng ký thành công'
    );
  } catch (error) {
    console.error('Register error:', error);
    return ApiResponse.error(res, error.message);
  }
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
      return ApiResponse.forbidden(res, 'Tài khoản đã bị vô hiệu hóa');
    }

    // Kiểm tra password
    const isPasswordMatch = await user.matchPassword(password);

    if (!isPasswordMatch) {
      return ApiResponse.unauthorized(res, 'Email hoặc mật khẩu không đúng');
    }

    // Cập nhật lastLogin
    user.lastLogin = new Date();
    await user.save();

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

    return ApiResponse.updated(res, { user }, 'Cập nhật thành công');
  } catch (error) {
    console.error('Update profile error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  register,
  login,
  getMe,
  changePassword,
  updateProfile,
};