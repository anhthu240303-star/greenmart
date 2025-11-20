const Product = require('../models/Product');
const StockIn = require('../models/StockIn');
const StockOut = require('../models/StockOut');
const BatchLot = require('../models/BatchLot');
const ApiResponse = require('../utils/response');
const PDFGenerator = require('../utils/pdfGenerator');

/**
 * 🔹 B. BÁO CÁO CHI TIẾT (DETAIL REPORTS)
 * Chi tiết từng phiếu, từng sản phẩm, từng lô
 */

/**
 * @desc    Báo cáo nhập kho chi tiết
 * @route   GET /api/reports/detail/stock-in/pdf
 * @access  Private
 */
const getStockInDetailPDF = async (req, res) => {
  try {
    const { startDate, endDate, supplier } = req.query;

    const query = { status: 'completed' };
    
    if (startDate || endDate) {
      query.importDate = {};
      if (startDate) query.importDate.$gte = new Date(startDate);
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        query.importDate.$lte = end;
      }
    }
    
    if (supplier) query.supplier = supplier;

    const stockIns = await StockIn.find(query)
      .populate('supplier', 'name code')
      .populate('items.product', 'name sku unit')
      .populate('createdBy', 'fullName username')
      .populate('approvedBy', 'fullName username')
      .sort({ importDate: -1 })
      .limit(50); // Giới hạn 50 phiếu

    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139'
    );

    pdf.addReportTitle(
      'BÁO CÁO NHẬP KHO CHI TIẾT',
      `Chi tiết từng phiếu nhập và sản phẩm`,
      'STOCK_IN'
    );

    const reportCode = `SIN-DETAIL-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    // Summary
    const totalReceipts = stockIns.length;
    const totalValue = stockIns.reduce((sum, si) => sum + si.totalAmount, 0);
    const totalItems = stockIns.reduce((sum, si) => sum + si.items.length, 0);
    const totalQuantity = stockIns.reduce((sum, si) => 
      sum + si.items.reduce((s, item) => s + item.quantity, 0), 0
    );

    pdf.addSummaryCards([
      {
        label: 'Tổng số phiếu',
        value: totalReceipts.toString(),
        subtitle: 'Phiếu nhập',
        color: '#4CAF50'
      },
      {
        label: 'Tổng giá trị',
        value: new Intl.NumberFormat('vi-VN').format(Math.round(totalValue / 1000000)) + 'M',
        subtitle: 'VND',
        color: '#2196F3'
      },
      {
        label: 'Tổng SP',
        value: totalItems.toString(),
        subtitle: 'Loại sản phẩm',
        color: '#FF9800'
      },
      {
        label: 'Tổng SL',
        value: new Intl.NumberFormat('vi-VN').format(totalQuantity),
        subtitle: 'Đơn vị',
        color: '#9C27B0'
      }
    ]);

    // Chi tiết từng phiếu
    for (const stockIn of stockIns) {
      pdf.addSectionHeader(`PHIẾU NHẬP: ${stockIn.code}`);

      // Thông tin phiếu
      const infoY = pdf.doc.y;
      pdf.doc
        .fontSize(8)
        .font('Arial')
        .fillColor('#666')
        .text(`Nhà cung cấp: ${stockIn.supplier?.name || 'N/A'}`, 50, infoY)
        .text(`Ngày nhập: ${new Date(stockIn.importDate).toLocaleDateString('vi-VN')}`, 50, infoY + 12)
        .text(`Người tạo: ${stockIn.createdBy?.fullName || stockIn.createdBy?.username || 'N/A'}`, 300, infoY)
        .text(`Người duyệt: ${stockIn.approvedBy?.fullName || 'Chưa duyệt'}`, 300, infoY + 12);

      pdf.doc.moveDown(1.5);

      // Bảng sản phẩm trong phiếu
      const headers = ['STT', 'Sản phẩm', 'SL', 'Đơn giá', 'Thành tiền', 'Số lô', 'HSD'];
      const columnWidths = [30, 150, 50, 70, 80, 60, 75];
      const alignments = ['center', 'left', 'right', 'right', 'right', 'center', 'center'];
      
      const rows = stockIn.items.map((item, index) => [
        index + 1,
        (item.product?.name || 'N/A').substring(0, 30),
        item.quantity + ' ' + (item.product?.unit || ''),
        new Intl.NumberFormat('vi-VN').format(item.unitPrice),
        new Intl.NumberFormat('vi-VN').format(item.totalPrice),
        item.batchNumber || '-',
        item.expiryDate ? new Date(item.expiryDate).toLocaleDateString('vi-VN') : '-'
      ]);

      pdf.drawTable(headers, rows, columnWidths, { alignments });

      // Tổng phiếu
      pdf.doc
        .fontSize(9)
        .font('Arial-Bold')
        .fillColor('#1a1a1a')
        .text(`Tổng giá trị phiếu: ${new Intl.NumberFormat('vi-VN').format(stockIn.totalAmount)} VND`, 
          50, pdf.doc.y + 10);

      pdf.doc.moveDown(2);
    }

    pdf.addWatermark('GREENMART');
    pdf.addFooter(false); // Không có chữ ký vì nhiều phiếu

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="nhap-kho-chi-tiet-${Date.now()}.pdf"`);
    
    pdf.doc.pipe(res);
    pdf.doc.end();

  } catch (error) {
    console.error('Error generating stock-in detail PDF:', error);
    return ApiResponse.error(res, 'Lỗi khi tạo báo cáo nhập kho chi tiết', 500);
  }
};

/**
 * @desc    Báo cáo xuất kho chi tiết
 * @route   GET /api/reports/detail/stock-out/pdf
 * @access  Private
 */
const getStockOutDetailPDF = async (req, res) => {
  try {
    const { startDate, endDate, type } = req.query;

    const query = { status: 'completed' };
    
    if (startDate || endDate) {
      query.issueDate = {};
      if (startDate) query.issueDate.$gte = new Date(startDate);
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        query.issueDate.$lte = end;
      }
    }
    
    if (type) query.type = type;

    const stockOuts = await StockOut.find(query)
      .populate('items.product', 'name sku unit costPrice sellingPrice')
      .populate('createdBy', 'fullName username')
      .populate('approvedBy', 'fullName username')
      .sort({ issueDate: -1 })
      .limit(50);

    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139'
    );

    pdf.addReportTitle(
      'BÁO CÁO XUẤT KHO CHI TIẾT',
      `Chi tiết từng phiếu xuất và sản phẩm (FIFO)`,
      'STOCK_OUT'
    );

    const reportCode = `SOUT-DETAIL-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    // Summary
    const totalReceipts = stockOuts.length;
    const totalValue = stockOuts.reduce((sum, so) => sum + so.totalAmount, 0);
    const totalItems = stockOuts.reduce((sum, so) => sum + so.items.length, 0);
    const totalQuantity = stockOuts.reduce((sum, so) => 
      sum + so.items.reduce((s, item) => s + item.quantity, 0), 0
    );

    pdf.addSummaryCards([
      {
        label: 'Tổng số phiếu',
        value: totalReceipts.toString(),
        subtitle: 'Phiếu xuất',
        color: '#FF9800'
      },
      {
        label: 'Tổng giá trị',
        value: new Intl.NumberFormat('vi-VN').format(Math.round(totalValue / 1000000)) + 'M',
        subtitle: 'VND',
        color: '#2196F3'
      },
      {
        label: 'Tổng SP',
        value: totalItems.toString(),
        subtitle: 'Loại sản phẩm',
        color: '#4CAF50'
      },
      {
        label: 'Tổng SL',
        value: new Intl.NumberFormat('vi-VN').format(totalQuantity),
        subtitle: 'Đơn vị',
        color: '#9C27B0'
      }
    ]);

    // Chi tiết từng phiếu
    for (const stockOut of stockOuts) {
      pdf.addSectionHeader(`PHIẾU XUẤT: ${stockOut.code}`);

      // Thông tin phiếu
      const typeLabels = {
        sale: 'Bán hàng',
        internal_use: 'Sử dụng nội bộ',
        damaged: 'Hư hỏng',
        expired: 'Hết hạn',
        return_to_supplier: 'Trả NCC',
        other: 'Khác'
      };

      const infoY = pdf.doc.y;
      pdf.doc
        .fontSize(8)
        .font('Arial')
        .fillColor('#666')
        .text(`Loại xuất: ${typeLabels[stockOut.type] || stockOut.type}`, 50, infoY)
        .text(`Ngày xuất: ${new Date(stockOut.issueDate).toLocaleDateString('vi-VN')}`, 50, infoY + 12)
        .text(`Người tạo: ${stockOut.createdBy?.fullName || stockOut.createdBy?.username || 'N/A'}`, 300, infoY)
        .text(`Người duyệt: ${stockOut.approvedBy?.fullName || 'Chưa duyệt'}`, 300, infoY + 12);

      pdf.doc.moveDown(1.5);

      // Bảng sản phẩm trong phiếu
      const headers = ['STT', 'Sản phẩm', 'SL', 'Giá vốn', 'Giá bán', 'Lô xuất'];
      const columnWidths = [30, 160, 50, 75, 75, 125];
      const alignments = ['center', 'left', 'right', 'right', 'right', 'left'];
      
      const rows = stockOut.items.map((item, index) => {
        const batchInfo = item.batchLots && item.batchLots.length > 0
          ? item.batchLots.map(bl => `${bl.batchNumber} (${bl.quantity})`).join(', ')
          : 'N/A';

        return [
          index + 1,
          (item.product?.name || 'N/A').substring(0, 30),
          item.quantity + ' ' + (item.product?.unit || ''),
          new Intl.NumberFormat('vi-VN').format(item.product?.costPrice || item.unitPrice),
          new Intl.NumberFormat('vi-VN').format(item.product?.sellingPrice || 0),
          batchInfo.substring(0, 25)
        ];
      });

      pdf.drawTable(headers, rows, columnWidths, { alignments });

      // Tổng phiếu
      pdf.doc
        .fontSize(9)
        .font('Arial-Bold')
        .fillColor('#1a1a1a')
        .text(`Tổng giá trị phiếu: ${new Intl.NumberFormat('vi-VN').format(stockOut.totalAmount)} VND`, 
          50, pdf.doc.y + 10);

      pdf.doc.moveDown(2);
    }

    pdf.addWatermark('GREENMART');
    pdf.addFooter(false);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="xuat-kho-chi-tiet-${Date.now()}.pdf"`);
    
    pdf.doc.pipe(res);
    pdf.doc.end();

  } catch (error) {
    console.error('Error generating stock-out detail PDF:', error);
    return ApiResponse.error(res, 'Lỗi khi tạo báo cáo xuất kho chi tiết', 500);
  }
};

/**
 * @desc    Báo cáo tồn kho chi tiết theo lô
 * @route   GET /api/reports/detail/batch-inventory/pdf
 * @access  Private
 */
const getBatchInventoryDetailPDF = async (req, res) => {
  try {
    const { product, nearExpiry } = req.query;

    const query = { 
      status: 'active',
      remainingQuantity: { $gt: 0 }
    };
    
    if (product) query.product = product;
    
    if (nearExpiry === 'true') {
      const futureDate = new Date();
      futureDate.setDate(futureDate.getDate() + 30);
      query.expiryDate = {
        $exists: true,
        $gte: new Date(),
        $lte: futureDate
      };
    }

    const batches = await BatchLot.find(query)
      .populate('product', 'name sku unit')
      .populate('supplier', 'name code')
      .populate('stockInRef', 'code')
      .sort({ expiryDate: 1, receivedDate: 1 })
      .limit(200);

    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139'
    );

    pdf.addReportTitle(
      'BÁO CÁO TỒN KHO CHI TIẾT THEO LÔ',
      'Dùng cho kiểm kê và quản lý FIFO/FEFO',
      'INVENTORY'
    );

    const reportCode = `BATCH-INV-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    // Summary
    const totalBatches = batches.length;
    const totalQuantity = batches.reduce((sum, b) => sum + b.remainingQuantity, 0);
    const totalValue = batches.reduce((sum, b) => sum + (b.remainingQuantity * b.costPrice), 0);
    const nearExpiryCount = batches.filter(b => {
      if (!b.expiryDate) return false;
      const daysLeft = (b.expiryDate - new Date()) / (1000 * 60 * 60 * 24);
      return daysLeft > 0 && daysLeft <= 30;
    }).length;

    pdf.addSummaryCards([
      {
        label: 'Tổng số lô',
        value: totalBatches.toString(),
        subtitle: 'Lô hàng',
        color: '#2196F3'
      },
      {
        label: 'Tổng SL tồn',
        value: new Intl.NumberFormat('vi-VN').format(totalQuantity),
        subtitle: 'Đơn vị',
        color: '#4CAF50'
      },
      {
        label: 'Giá trị tồn',
        value: new Intl.NumberFormat('vi-VN').format(Math.round(totalValue / 1000000)) + 'M',
        subtitle: 'VND',
        color: '#9C27B0'
      },
      {
        label: 'Sắp hết hạn',
        value: nearExpiryCount.toString(),
        subtitle: 'Trong 30 ngày',
        color: '#FF9800'
      }
    ]);

    pdf.addSectionHeader('CHI TIẾT TỒN KHO THEO LÔ');

    const headers = ['Sản phẩm', 'Số lô', 'HSD', 'SL tồn', 'Giá vốn', 'Ngày nhập'];
    const columnWidths = [150, 65, 70, 60, 70, 70];
    const alignments = ['left', 'center', 'center', 'right', 'right', 'center'];
    
    const rows = batches.map(batch => [
      (batch.product?.name || 'N/A').substring(0, 30),
      batch.batchNumber,
      batch.expiryDate ? new Date(batch.expiryDate).toLocaleDateString('vi-VN') : '-',
      batch.remainingQuantity + ' ' + (batch.product?.unit || ''),
      new Intl.NumberFormat('vi-VN').format(batch.costPrice),
      new Date(batch.receivedDate).toLocaleDateString('vi-VN')
    ]);

    pdf.drawTable(headers, rows, columnWidths, { alignments });

    pdf.addWatermark('GREENMART');
    pdf.addFooter(true);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="ton-kho-theo-lo-${Date.now()}.pdf"`);
    
    pdf.doc.pipe(res);
    pdf.doc.end();

  } catch (error) {
    console.error('Error generating batch inventory detail PDF:', error);
    return ApiResponse.error(res, 'Lỗi khi tạo báo cáo tồn kho theo lô', 500);
  }
};

module.exports = {
  getStockInDetailPDF,
  getStockOutDetailPDF,
  getBatchInventoryDetailPDF
};
