const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      required: [true, 'Vui lòng nhập tên đăng nhập'],
      unique: true,
      trim: true,
      minlength: [3, 'Tên đăng nhập phải có ít nhất 3 ký tự'],
      maxlength: [50, 'Tên đăng nhập không được quá 50 ký tự'],
    },
    email: {
      type: String,
      required: [true, 'Vui lòng nhập email'],
      unique: true,
      trim: true,
      lowercase: true,
      match: [
        /^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/,
        'Email không hợp lệ',
      ],
    },
    password: {
      type: String,
      required: [true, 'Vui lòng nhập mật khẩu'],
      minlength: [6, 'Mật khẩu phải có ít nhất 6 ký tự'],
      select: false, // Không trả về password khi query
    },
    fullName: {
      type: String,
      required: [true, 'Vui lòng nhập họ tên'],
      trim: true,
    },
    phone: {
      type: String,
      trim: true,
      match: [/^[0-9]{10,11}$/, 'Số điện thoại không hợp lệ'],
    },
    role: {
      type: String,
      enum: {
        values: ['admin', 'warehouse_manager', 'warehouse_staff'],
        message: '{VALUE} không phải là vai trò hợp lệ',
      },
      default: 'warehouse_staff',
    },
    avatar: {
      url: {
        type: String,
        default: 'https://res.cloudinary.com/demo/image/upload/avatar-default.png',
      },
      publicId: String,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    // Approval flags: manager and admin must both approve for account to be active
    managerApproved: {
      type: Boolean,
      default: false,
    },
    adminApproved: {
      type: Boolean,
      default: false,
    },
    lastLogin: {
      type: Date,
    },
    // Lightweight activity history stored as embedded docs for simplicity.
    // Note: this is simple and works for small projects; for heavy activity loads
    // a separate collection is recommended.
    activities: [
      {
        actor: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        action: { type: String },
        details: { type: mongoose.Schema.Types.Mixed },
        ip: { type: String },
        userAgent: { type: String },
        createdAt: { type: Date, default: Date.now },
      },
    ],
  },
  {
    timestamps: true,
  }
);

// Hash password trước khi lưu
userSchema.pre('save', async function (next) {
  // Chỉ hash khi password được modify
  if (!this.isModified('password')) {
    next();
  }

  const salt = await bcrypt.genSalt(10);
  this.password = await bcrypt.hash(this.password, salt);
});

// Method so sánh password
userSchema.methods.matchPassword = async function (enteredPassword) {
  return await bcrypt.compare(enteredPassword, this.password);
};

// Method để lấy thông tin user không có password
userSchema.methods.toJSON = function () {
  const user = this.toObject();
  delete user.password;
  return user;
};

const User = mongoose.model('User', userSchema);

module.exports = User;