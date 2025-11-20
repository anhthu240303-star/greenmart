  const mongoose = require('mongoose');

  /**
   * Model quản lý lô hàng (Batch/Lot) 
   * Dùng cho FIFO/FEFO, kiểm kê, báo cáo chi tiết tồn kho
   */
  const batchLotSchema = new mongoose.Schema(
    {
      // Mã lô (tự động hoặc từ NCC)
      batchNumber: {
        type: String,
        required: [true, 'Vui lòng nhập số lô'],
        trim: true,
        uppercase: true,
      },
      
      // Sản phẩm
      product: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Product',
        required: [true, 'Vui lòng chọn sản phẩm'],
        index: true,
      },
      
      // Nhà cung cấp
      supplier: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Supplier',
        required: [true, 'Vui lòng chọn nhà cung cấp'],
      },
      
      // Phiếu nhập liên quan
      stockInRef: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'StockIn',
        required: true,
      },
      
      // Ngày sản xuất
      manufacturingDate: {
        type: Date,
      },
      
      // Hạn sử dụng (HSD)
      expiryDate: {
        type: Date,
      },
      
      // Số lượng ban đầu
      initialQuantity: {
        type: Number,
        required: true,
        min: [0, 'Số lượng không được âm'],
      },
      
      // Số lượng còn lại (giảm dần khi xuất)
      remainingQuantity: {
        type: Number,
        required: true,
        min: [0, 'Số lượng không được âm'],
      },
      
      // Giá vốn của lô này
      costPrice: {
        type: Number,
        required: true,
        min: [0, 'Giá vốn không được âm'],
      },
      
      // Ngày nhập lô này
      receivedDate: {
        type: Date,
        required: true,
        default: Date.now,
        index: true, // Để sort FIFO
      },
      
      // Trạng thái lô
      status: {
        type: String,
        enum: {
          values: ['active', 'depleted', 'expired', 'damaged'],
          message: '{VALUE} không phải là trạng thái hợp lệ',
        },
        default: 'active',
        index: true,
      },
      
      // Ghi chú
      notes: {
        type: String,
        trim: true,
        maxlength: [500, 'Ghi chú không được quá 500 ký tự'],
      },
      
      createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true,
      },
    },
    {
      timestamps: true,
      toJSON: { virtuals: true },
      toObject: { virtuals: true },
    }
  );

  // Indexes cho query hiệu quả
  batchLotSchema.index({ product: 1, status: 1, receivedDate: 1 }); // FIFO query
  batchLotSchema.index({ product: 1, status: 1, expiryDate: 1 }); // FEFO query
  batchLotSchema.index({ expiryDate: 1 }); // Cảnh báo hết hạn
  batchLotSchema.index({ batchNumber: 1, product: 1 }, { unique: true }); // Unique per product

  // Virtual: Kiểm tra lô đã hết
  batchLotSchema.virtual('isDepleted').get(function () {
    return this.remainingQuantity === 0;
  });

  // Virtual: Kiểm tra lô sắp hết hạn (trong 30 ngày)
  batchLotSchema.virtual('isNearExpiry').get(function () {
    if (!this.expiryDate) return false;
    const daysUntilExpiry = (this.expiryDate - new Date()) / (1000 * 60 * 60 * 24);
    return daysUntilExpiry > 0 && daysUntilExpiry <= 30;
  });

  // Virtual: Kiểm tra lô đã hết hạn
  batchLotSchema.virtual('isExpired').get(function () {
    if (!this.expiryDate) return false;
    return this.expiryDate < new Date();
  });

  // Virtual: Số lượng đã xuất
  batchLotSchema.virtual('quantityUsed').get(function () {
    return this.initialQuantity - this.remainingQuantity;
  });

  // Virtual: Phần trăm còn lại
  batchLotSchema.virtual('remainingPercentage').get(function () {
    if (this.initialQuantity === 0) return 0;
    return (this.remainingQuantity / this.initialQuantity) * 100;
  });

  // Middleware: Tự động update status
  batchLotSchema.pre('save', function (next) {
    // Nếu hết hàng
    if (this.remainingQuantity === 0 && this.status === 'active') {
      this.status = 'depleted';
    }
    
    // Nếu hết hạn
    if (this.expiryDate && this.expiryDate < new Date() && this.status === 'active') {
      this.status = 'expired';
    }
    
    next();
  });

  // Static method: Lấy lô theo FIFO
  batchLotSchema.statics.findByFIFO = function (productId, requiredQuantity) {
    return this.find({
      product: productId,
      status: 'active',
      remainingQuantity: { $gt: 0 },
    })
      .sort({ receivedDate: 1 }) // Nhập trước xuất trước
      .exec();
  };

  // Static method: Lấy lô theo FEFO (First Expired First Out)
  batchLotSchema.statics.findByFEFO = function (productId, requiredQuantity) {
    return this.find({
      product: productId,
      status: 'active',
      remainingQuantity: { $gt: 0 },
      expiryDate: { $exists: true, $ne: null },
    })
      .sort({ expiryDate: 1 }) // Hết hạn sớm xuất trước
      .exec();
  };

  // Static method: Cảnh báo lô sắp hết hạn
  batchLotSchema.statics.findNearExpiry = function (days = 30) {
    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + days);
    
    return this.find({
      status: 'active',
      remainingQuantity: { $gt: 0 },
      expiryDate: {
        $exists: true,
        $gte: new Date(),
        $lte: futureDate,
      },
    })
      .populate('product', 'name sku')
      .populate('supplier', 'name')
      .sort({ expiryDate: 1 })
      .exec();
  };

  const BatchLot = mongoose.model('BatchLot', batchLotSchema);

  module.exports = BatchLot;
