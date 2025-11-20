const mongoose = require('mongoose');

const productSchema = new mongoose.Schema(
  {
    barcode: {
      type: String,
      trim: true,
      unique: true,
      sparse: true, // Cho phép null nhưng unique
    },
    name: {
      type: String,
      required: [true, 'Vui lòng nhập tên sản phẩm'],
      trim: true,
      maxlength: [200, 'Tên sản phẩm không được quá 200 ký tự'],
    },
    description: {
      type: String,
      trim: true,
      maxlength: [2000, 'Mô tả không được quá 2000 ký tự'],
    },
    category: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Category',
      required: [true, 'Vui lòng chọn danh mục'],
    },
    images: [
      {
        url: String,
        publicId: String,
        isPrimary: {
          type: Boolean,
          default: false,
        },
      },
    ],
    // Giá và đơn vị
    unit: {
      type: String,
      required: [true, 'Vui lòng nhập đơn vị tính'],
      trim: true,
      default: 'Cái',
    },
    costPrice: {
      type: Number,
      required: [true, 'Vui lòng nhập giá vốn'],
      min: [0, 'Giá vốn không được âm'],
    },
    sellingPrice: {
      type: Number,
      required: [true, 'Vui lòng nhập giá bán'],
      min: [0, 'Giá bán không được âm'],
    },
    // Tồn kho
    currentStock: {
      type: Number,
      default: 0,
      min: [0, 'Số lượng tồn không được âm'],
    },
    minStock: {
      type: Number,
      default: 10,
      min: [0, 'Số lượng tồn tối thiểu không được âm'],
    },

    // Vị trí lưu trữ
    location: {
      zone: String,
      shelf: String,
      bin: String,
    },
    // Trạng thái
    status: {
      type: String,
      enum: {
        values: ['active', 'inactive', 'out_of_stock', 'discontinued'],
        message: '{VALUE} không phải là trạng thái hợp lệ',
      },
      default: 'active',
    },
    // Nhà cung cấp mặc định
    defaultSupplier: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Supplier',
    },
    // Liên kết tới các BatchLot (nếu có)
    batchLots: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'BatchLot',
      },
    ],
    
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Indexes
productSchema.index({ category: 1 });
productSchema.index({ status: 1 });
productSchema.index({ name: 'text', description: 'text' });

// Virtual: Kiểm tra tồn kho thấp
productSchema.virtual('isLowStock').get(function () {
  return this.currentStock <= this.minStock;
});

// Virtual: Kiểm tra hết hàng
productSchema.virtual('isOutOfStock').get(function () {
  return this.currentStock === 0;
});

// Virtual: Tính lợi nhuận
productSchema.virtual('profitMargin').get(function () {
  if (this.costPrice === 0) return 0;
  return ((this.sellingPrice - this.costPrice) / this.costPrice) * 100;
});

// Middleware: Cập nhật status khi currentStock thay đổi
productSchema.pre('save', function (next) {
  if (this.isModified('currentStock')) {
    if (this.currentStock === 0) {
      this.status = 'out_of_stock';
    } else if (this.status === 'out_of_stock') {
      this.status = 'active';
    }
  }
  next();
});

// model will be attached after static methods

// Static: đếm sản phẩm sắp hết hàng theo hai quy tắc:
// - currentStock <= minStock OR
// - tổng remainingQuantity của tất cả batch (BatchLot) < minStock
productSchema.statics.countLowStock = async function () {
  // aggregation để tính tổng remainingQuantity từ collection batchlots
  const result = await this.aggregate([
    { $match: { status: 'active' } },
    {
      $lookup: {
        from: 'batchlots',
        localField: '_id',
        foreignField: 'product',
        as: 'batches',
      },
    },
    {
      $addFields: {
        batchesRemaining: { $sum: '$batches.remainingQuantity' },
      },
    },
    {
      $match: {
        $or: [
          { $expr: { $lte: ['$currentStock', '$minStock'] } },
          { $expr: { $lt: ['$batchesRemaining', '$minStock'] } },
        ],
      },
    },
    { $count: 'count' },
  ]);

  return (result[0] && result[0].count) ? result[0].count : 0;
};

// Static: lấy danh sách sản phẩm sắp hết hàng, kèm thông tin tổng lô
productSchema.statics.findLowStockProducts = async function ({ limit = 50, skip = 0 } = {}) {
  const docs = await this.aggregate([
    { $match: { status: 'active' } },
    {
      $lookup: {
        from: 'batchlots',
        localField: '_id',
        foreignField: 'product',
        as: 'batches',
      },
    },
    {
      $addFields: {
        batchesRemaining: { $sum: '$batches.remainingQuantity' },
      },
    },
    {
      $match: {
        $or: [
          { $expr: { $lte: ['$currentStock', '$minStock'] } },
          { $expr: { $lt: ['$batchesRemaining', '$minStock'] } },
        ],
      },
    },
    { $sort: { currentStock: 1 } },
    { $skip: parseInt(skip, 10) },
    { $limit: parseInt(limit, 10) },
  ]);

  return docs;
};

// attach model after adding statics
const Product = mongoose.model('Product', productSchema);

module.exports = Product;