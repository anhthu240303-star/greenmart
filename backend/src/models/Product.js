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
productSchema.index({ sku: 1 });
productSchema.index({ barcode: 1 });
productSchema.index({ category: 1 });
productSchema.index({ status: 1 });
productSchema.index({ name: 'text', description: 'text', tags: 'text' });

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

const Product = mongoose.model('Product', productSchema);

module.exports = Product;