const mongoose = require('mongoose');

const stockOutSchema = new mongoose.Schema(
  {
    code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      uppercase: true,
    },
    type: {
      type: String,
      enum: {
        values: ['sale', 'internal_use', 'damaged', 'expired', 'return_to_supplier', 'other'],
        message: '{VALUE} không phải là loại xuất kho hợp lệ',
      },
      required: [true, 'Vui lòng chọn loại xuất kho'],
    },
    // Danh sách sản phẩm xuất
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
        // Chi tiết các lô được xuất (FIFO/FEFO)
        batchLots: [
          {
            batchLotRef: {
              type: mongoose.Schema.Types.ObjectId,
              ref: 'BatchLot',
            },
            batchNumber: String,
            quantity: Number, // Số lượng xuất từ lô này
            costPrice: Number, // Giá vốn của lô
            expiryDate: Date,
          }
        ],
        // Tham chiếu đến transaction (feature removed) - lưu ObjectId nếu cần
        transactionRef: {
          type: mongoose.Schema.Types.ObjectId,
        },
      },
    ],
    // Tổng giá trị phiếu xuất
    totalAmount: {
      type: Number,
      required: true,
      default: 0,
    },
    // Ngày xuất
    issueDate: {
      type: Date,
      required: [true, 'Vui lòng chọn ngày xuất'],
      default: Date.now,
    },

    // Trạng thái
    status: {
      type: String,
      enum: {
        values: ['pending', 'approved', 'completed', 'cancelled'],
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
stockOutSchema.index({ type: 1 });
stockOutSchema.index({ status: 1 });
stockOutSchema.index({ createdAt: -1 });

// Middleware: Tính tổng tiền cho từng item
stockOutSchema.pre('save', function (next) {
  // Tính totalPrice cho từng item
  this.items.forEach((item) => {
    item.totalPrice = item.quantity * item.unitPrice;
  });

  // Tính tổng tiền của phiếu xuất
  this.totalAmount = this.items.reduce((sum, item) => sum + item.totalPrice, 0);

  next();
});

const StockOut = mongoose.model('StockOut', stockOutSchema);

module.exports = StockOut;