const mongoose = require('mongoose');

const stockTransactionSchema = new mongoose.Schema(
  {
    transactionCode: {
      type: String,
      required: true,
      unique: true,
      trim: true,
      uppercase: true,
    },
    type: {
      type: String,
      enum: {
        values: ['in', 'out', 'adjustment'],
        message: '{VALUE} không phải là loại giao dịch hợp lệ',
      },
      required: [true, 'Vui lòng chọn loại giao dịch'],
    },
    product: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Product',
      required: [true, 'Vui lòng chọn sản phẩm'],
    },
    quantity: {
      type: Number,
      required: [true, 'Vui lòng nhập số lượng'],
      min: [1, 'Số lượng phải lớn hơn 0'],
    },
    // Giá tại thời điểm giao dịch
    unitPrice: {
      type: Number,
      required: [true, 'Vui lòng nhập đơn giá'],
      min: [0, 'Đơn giá không được âm'],
    },
    totalAmount: {
      type: Number,
      required: true,
      min: [0, 'Tổng tiền không được âm'],
    },
    // Nhà cung cấp (cho nhập kho)
    supplier: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Supplier',
    },
    // Tồn kho trước và sau giao dịch
    stockBefore: {
      type: Number,
      required: true,
      min: [0, 'Tồn kho trước không được âm'],
    },
    stockAfter: {
      type: Number,
      required: true,
      min: [0, 'Tồn kho sau không được âm'],
    },
    // Trạng thái giao dịch
    status: {
      type: String,
      enum: {
        values: ['pending', 'approved', 'rejected', 'cancelled'],
        message: '{VALUE} không phải là trạng thái hợp lệ',
      },
      default: 'pending',
    },
  
    // Người thực hiện và duyệt
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
    // Tham chiếu đến phiếu nhập/xuất
    stockInRef: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'StockIn',
    },
    stockOutRef: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'StockOut',
    },
  },
  {
    timestamps: true,
  }
);

// Indexes
stockTransactionSchema.index({ transactionCode: 1 });
stockTransactionSchema.index({ type: 1, status: 1 });
stockTransactionSchema.index({ product: 1, createdAt: -1 });
stockTransactionSchema.index({ supplier: 1 });
stockTransactionSchema.index({ createdBy: 1 });

// Middleware: Tính totalAmount trước khi lưu
stockTransactionSchema.pre('save', function (next) {
  this.totalAmount = this.quantity * this.unitPrice;
  next();
});

const StockTransaction = mongoose.model('StockTransaction', stockTransactionSchema);

module.exports = StockTransaction;