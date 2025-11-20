const mongoose = require('mongoose');

const supplierSchema = new mongoose.Schema(
  {
    code: {
      type: String,
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

// Middleware: Tạo mã tự động nếu chưa có
supplierSchema.pre('save', async function(next) {
  if (!this.code && this.isNew) {
    try {
      // Generate code SUP01, SUP02, ...
      const lastSupplier = await this.constructor.findOne({ code: /^SUP\d+$/ })
        .sort({ code: -1 })
        .select('code')
        .lean();
      
      if (!lastSupplier || !lastSupplier.code) {
        this.code = 'SUP01';
      } else {
        const lastNumber = parseInt(lastSupplier.code.replace('SUP', '')) || 0;
        const newNumber = String(lastNumber + 1).padStart(2, '0');
        this.code = `SUP${newNumber}`;
      }
    } catch (error) {
      console.error('Error generating supplier code:', error);
      this.code = `SUP${Date.now().toString().slice(-4)}`;
    }
  }
  next();
});

// NOTE: `StockTransaction` feature removed — no virtual totalTransactions

const Supplier = mongoose.model('Supplier', supplierSchema);

module.exports = Supplier;