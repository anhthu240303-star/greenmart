const mongoose = require('mongoose');

const inventoryCheckSchema = new mongoose.Schema(
  {
    code: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      uppercase: true,
    },
    title: {
      type: String,
      required: [true, 'Vui lòng nhập tiêu đề kiểm kê'],
      trim: true,
    },
    checkDate: {
      type: Date,
      required: [true, 'Vui lòng chọn ngày kiểm kê'],
      default: Date.now,
    },
    // Danh sách sản phẩm kiểm kê
    items: [
      {
        product: {
          type: mongoose.Schema.Types.ObjectId,
          ref: 'Product',
          required: true,
        },
        // Số lượng trong hệ thống
        systemQuantity: {
          type: Number,
          required: true,
          min: [0, 'Số lượng hệ thống không được âm'],
        },
        // Số lượng thực tế đếm được
        actualQuantity: {
          type: Number,
          required: true,
          min: [0, 'Số lượng thực tế không được âm'],
        },
        // Chênh lệch
        difference: {
          type: Number,
          default: 0,
        },
        // Ghi chú cho từng sản phẩm
        notes: String,
        // Trạng thái
        status: {
          type: String,
          enum: ['matched', 'excess', 'shortage'],
          default: 'matched',
        },
      },
    ],
    // Tổng kết
    summary: {
      totalProducts: {
        type: Number,
        default: 0,
      },
      matched: {
        type: Number,
        default: 0,
      },
      excess: {
        type: Number,
        default: 0,
      },
      shortage: {
        type: Number,
        default: 0,
      },
    },
    // Trạng thái kiểm kê
    status: {
      type: String,
      enum: {
        values: ['in_progress', 'completed', 'approved', 'cancelled'],
        message: '{VALUE} không phải là trạng thái hợp lệ',
      },
      default: 'in_progress',
    },
    notes: {
      type: String,
      maxlength: [2000, 'Ghi chú không được quá 2000 ký tự'],
    },
    // Người thực hiện
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    // Người kiểm tra
    checkedBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],
    // Người phê duyệt
    approvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
    },
    approvedAt: {
      type: Date,
    },
    // Hoàn thành kiểm kê
    completedAt: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

// Indexes
inventoryCheckSchema.index({ code: 1 });
inventoryCheckSchema.index({ status: 1 });
inventoryCheckSchema.index({ checkDate: -1 });

// Middleware: Tính chênh lệch và cập nhật summary
inventoryCheckSchema.pre('save', function (next) {
  let matched = 0;
  let excess = 0;
  let shortage = 0;

  // Tính difference và status cho từng item
  this.items.forEach((item) => {
    item.difference = item.actualQuantity - item.systemQuantity;

    if (item.difference === 0) {
      item.status = 'matched';
      matched++;
    } else if (item.difference > 0) {
      item.status = 'excess';
      excess++;
    } else {
      item.status = 'shortage';
      shortage++;
    }
  });

  // Cập nhật summary
  this.summary = {
    totalProducts: this.items.length,
    matched,
    excess,
    shortage,
  };

  next();
});

const InventoryCheck = mongoose.model('InventoryCheck', inventoryCheckSchema);

module.exports = InventoryCheck;