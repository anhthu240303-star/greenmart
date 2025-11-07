const mongoose = require('mongoose');

const supplierSchema = new mongoose.Schema(
  {
    code: {
      type: String,
      required: [true, 'Vui lòng nhập mã nhà cung cấp'],
      unique: true,
      trim: true,
      uppercase: true,
    },
    name: {
      type: String,
      required: [true, 'Vui lòng nhập tên nhà cung cấp'],
      trim: true,
    },
    contactPerson: {
      type: String,
      trim: true,
    },
    phone: {
      type: String,
      required: [true, 'Vui lòng nhập số điện thoại'],
      trim: true,
      match: [/^[0-9]{10,11}$/, 'Số điện thoại không hợp lệ'],
    },
    email: {
      type: String,
      trim: true,
      lowercase: true,
      match: [
        /^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$/,
        'Email không hợp lệ',
      ],
    },
    address: {
      street: String,
      district: String,
      city: String,
      country: {
        type: String,
        default: 'Việt Nam',
      },
    },
    taxCode: {
      type: String,
      trim: true,
    },
    bankAccount: {
      bankName: String,
      accountNumber: String,
      accountName: String,
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
supplierSchema.index({ name: 'text', code: 'text', contactPerson: 'text' });

// Virtual để lấy tổng số giao dịch
supplierSchema.virtual('totalTransactions', {
  ref: 'StockTransaction',
  localField: '_id',
  foreignField: 'supplier',
  count: true,
});

const Supplier = mongoose.model('Supplier', supplierSchema);

module.exports = Supplier;