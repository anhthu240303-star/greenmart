const mongoose = require('mongoose');

const stockInSchema = new mongoose.Schema(
  {
    code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      uppercase: true,
    },
    supplier: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Supplier',
      required: [true, 'Vui lòng chọn nhà cung cấp'],
    },
    // Danh sách sản phẩm nhập
    items: [
      {
        product: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'Product',
          required: true,
        },
        quantity: {
          type: Number,
          required: true,
          min: [1, 'Số lượng phải lớn hơn 0'],
        },
        unitPrice: {
          type: Number,
          required: true,
          min: [0, 'Đơn giá không được âm'],
        },
        totalPrice: {
          type: Number,
          default: 0,
        },
        // Thông tin lô hàng
        batchNumber: {
          type: String,
          trim: true,
          uppercase: true,
        },
        manufacturingDate: {
          type: Date,
        },
        expiryDate: {
          type: Date,
        },
        // Tham chiếu đến BatchLot được tạo
        batchLotRef: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'BatchLot',
        },
        // Tham chiếu đến transaction (feature removed) - lưu ObjectId nếu cần
        transactionRef: {
          type: mongoose.Schema.Types.ObjectId,
        },
      },
    ],
    // Tổng giá trị phiếu nhập
    totalAmount: {
      type: Number,
      required: true,
      default: 0,
    },
    // Ngày nhập
    importDate: {
      type: Date,
      required: [true, 'Vui lòng chọn ngày nhập hàng'],
      default: Date.now,
    },
    // Trạng thái
    status: {
      type: String,
      enum: {
        values: ['pending', 'in_progress', 'completed', 'cancelled'],
        message: '{VALUE} không phải là trạng thái hợp lệ',
      },
      default: 'pending',
    },
    
  
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    approvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    approvedAt: {
      type: Date,
    },
    // Thông tin hủy phiếu (nếu có)
    cancelledBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    cancelledAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes
stockInSchema.index({ supplier: 1 });
stockInSchema.index({ status: 1 });
stockInSchema.index({ createdAt: -1 });

// Middleware: Tính tổng tiền cho từng item
stockInSchema.pre('save', function (next) {
  // Tính totalPrice cho từng item
  this.items.forEach((item) => {
    item.totalPrice = item.quantity * item.unitPrice;
  });

  // Tính tổng tiền của phiếu nhập
  this.totalAmount = this.items.reduce((sum, item) => sum + item.totalPrice, 0);

  next();
});

const StockIn = mongoose.model('StockIn', stockInSchema);

module.exports = StockIn;