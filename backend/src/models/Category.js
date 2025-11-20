const mongoose = require('mongoose');

const categorySchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, 'Vui lòng nhập tên danh mục'],
      unique: true,
      trim: true,
      maxlength: [100, 'Tên danh mục không được quá 100 ký tự'],
    },
    code: {
      type: String,
      required: [true, 'Vui lòng nhập mã danh mục'],
      unique: true,
      trim: true,
      uppercase: true,
    },
    description: {
      type: String,
      trim: true,
      maxlength: [500, 'Mô tả không được quá 500 ký tự'],
    },
    image: {
      url: String,
      publicId: String,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// Index cho tìm kiếm
categorySchema.index({ name: 'text', code: 'text', description: 'text' });

const Category = mongoose.model('Category', categorySchema);

module.exports = Category;