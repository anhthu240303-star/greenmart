const Product = require('../models/Product');
const StockIn = require('../models/StockIn');
const StockOut = require('../models/StockOut');
const Supplier = require('../models/Supplier');
const ApiResponse = require('../utils/response');
const PDFGenerator = require('../utils/pdfGenerator');

/**
 * @desc    Báo cáo tồn kho PDF
 * @route   GET /api/reports/inventory/pdf
 * @access  Private
 */
const getInventoryReportPDF = async (req, res) => {
  try {
    const { category, minStock, maxStock } = req.query;

    const query = {};
    if (category) query.category = category;
    if (minStock) query.currentStock = { ...query.currentStock, $gte: parseInt(minStock) };
    if (maxStock) query.currentStock = { ...query.currentStock, $lte: parseInt(maxStock) };

    const products = await Product.find(query)
      .populate('category', 'name')
      .sort({ name: 1 });

    // Tính toán tổng
    const totalQuantity = products.reduce((sum, p) => sum + p.currentStock, 0);
    const totalValue = products.reduce((sum, p) => sum + (p.currentStock * p.costPrice), 0);
    const lowStockCount = products.filter(p => p.currentStock <= (p.minStock || 10)).length;
    const totalProducts = products.length;

    // Tạo PDF chuyên nghiệp
    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139'
    );

    pdf.addReportTitle(
      'BÁO CÁO TỒN KHO',
      `Tổng quan về tình trạng tồn kho hiện tại`,
      'Tồn kho'
    );

    const reportCode = `INV-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    // Summary cards
    pdf.addSummaryCards([
      {
        label: 'Tổng sản phẩm',
        value: new Intl.NumberFormat('vi-VN').format(totalProducts),
        subtitle: 'Mặt hàng',
        color: '#2196F3'
      },
      {
        label: 'Tổng số lượng',
        value: new Intl.NumberFormat('vi-VN').format(totalQuantity),
        subtitle: 'Đơn vị tồn kho',
        color: '#4CAF50'
      },
      {
        label: 'Giá trị tồn kho',
        value: new Intl.NumberFormat('vi-VN').format(Math.round(totalValue / 1000000)) + 'M',
        subtitle: 'VND',
        color: '#9C27B0'
      },
      {
        label: 'Sắp hết hàng',
        value: lowStockCount.toString(),
        subtitle: 'Cần nhập thêm',
        color: '#FF9800'
      }
    ]);

    pdf.addSectionHeader('DANH SÁCH SẢN PHẨM TỒN KHO');

    // Bảng dữ liệu
    const headers = ['STT', 'Tên sản phẩm', 'SKU', 'Loại', 'Tồn', 'Giá vốn', 'Giá trị'];
    const columnWidths = [35, 140, 75, 85, 50, 75, 85];
    const alignments = ['center', 'left', 'left', 'left', 'right', 'right', 'right'];
    
    const rows = products.map((product, index) => [
      index + 1,
      product.name.substring(0, 30) + (product.name.length > 30 ? '...' : ''),
      product.sku || '-',
      product.category?.name || '-',
      product.currentStock + ' ' + (product.unit || ''),
      new Intl.NumberFormat('vi-VN').format(product.costPrice || 0),
      new Intl.NumberFormat('vi-VN').format((product.currentStock * (product.costPrice || 0)))
    ]);

    pdf.drawTable(headers, rows, columnWidths, { alignments });

    pdf.addWatermark('GREENMART');
    pdf.addFooter(true);

    // Response headers
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=bao-cao-ton-kho-${reportCode}.pdf`);
    
    pdf.pipe(res).end();
  } catch (error) {
    console.error('Get inventory report PDF error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Báo cáo nhập kho PDF
 * @route   GET /api/reports/stock-in/pdf
 * @access  Private
 */
const getStockInReportPDF = async (req, res) => {
  try {
    const { startDate, endDate, supplier } = req.query;

    const query = {};
    if (startDate || endDate) {
      query.importDate = {};
      if (startDate) query.importDate.$gte = new Date(startDate);
      if (endDate) query.importDate.$lte = new Date(endDate);
    }
    if (supplier) query.supplier = supplier;

    const stockIns = await StockIn.find(query)
      .populate('supplier', 'name code')
      .populate('items.product', 'name sku')
      .sort({ importDate: -1 });

    const totalAmount = stockIns.reduce((sum, si) => sum + si.totalAmount, 0);
    const totalQuantity = stockIns.reduce((sum, si) => {
      return sum + si.items.reduce((itemSum, item) => itemSum + item.quantity, 0);
    }, 0);
    const approvedCount = stockIns.filter(s => s.status === 'approved').length;

    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139',
    );

    pdf.addReportTitle(
      'BÁO CÁO NHẬP KHO',
      startDate || endDate 
        ? `Từ ${startDate ? new Date(startDate).toLocaleDateString('vi-VN') : '...'} đến ${endDate ? new Date(endDate).toLocaleDateString('vi-VN') : '...'}`
        : 'Tất cả giao dịch nhập kho',
      'Nhập kho'
    );

    const reportCode = `SIN-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    pdf.addSummaryCards([
      {
        label: 'Tổng phiếu nhập',
        value: new Intl.NumberFormat('vi-VN').format(stockIns.length),
        subtitle: 'Phiếu',
        color: '#4CAF50'
      },
      {
        label: 'Tổng số lượng',
        value: new Intl.NumberFormat('vi-VN').format(totalQuantity),
        subtitle: 'Đơn vị',
        color: '#2196F3'
      },
      {
        label: 'Tổng giá trị',
        value: new Intl.NumberFormat('vi-VN').format(Math.round(totalAmount / 1000000)) + 'M',
        subtitle: 'VND',
        color: '#9C27B0'
      },
      {
        label: 'Đã duyệt',
        value: approvedCount.toString(),
        subtitle: `/ ${stockIns.length} phiếu`,
        color: '#4CAF50'
      }
    ]);

    pdf.addSectionHeader('CHI TIẾT PHIẾU NHẬP KHO');

    const headers = ['STT', 'Mã phiếu', 'Ngày nhập', 'NCC', 'SL', 'Tổng tiền', 'TT'];
    const columnWidths = [35, 75, 75, 120, 45, 90, 60];
    const alignments = ['center', 'left', 'center', 'left', 'right', 'right', 'center'];
    
    const rows = stockIns.map((item, index) => {
      const quantity = item.items.reduce((sum, i) => sum + i.quantity, 0);
      return [
        index + 1,
        item.code,
        new Date(item.importDate).toLocaleDateString('vi-VN'),
        item.supplier?.name?.substring(0, 20) || '-',
        quantity,
        new Intl.NumberFormat('vi-VN').format(item.totalAmount || 0),
        item.status === 'completed' ? 'Hoàn thành' : item.status === 'pending' ? 'Chờ duyệt' : 'ủy'
      ];
    });

    pdf.drawTable(headers, rows, columnWidths, { alignments });

    pdf.addWatermark('GREENMART');
    pdf.addFooter(true);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=bao-cao-nhap-kho-${reportCode}.pdf`);
    
    pdf.pipe(res).end();
  } catch (error) {
    console.error('Get stock in report PDF error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Báo cáo xuất kho PDF
 * @route   GET /api/reports/stock-out/pdf
 * @access  Private
 */
const getStockOutReportPDF = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    const query = {};
    if (startDate || endDate) {
      query.exportDate = {};
      if (startDate) query.exportDate.$gte = new Date(startDate);
      if (endDate) query.exportDate.$lte = new Date(endDate);
    }

    const stockOuts = await StockOut.find(query)
      .populate('items.product', 'name sku')
      .sort({ exportDate: -1 });

    const totalAmount = stockOuts.reduce((sum, so) => sum + so.totalAmount, 0);
    const totalQuantity = stockOuts.reduce((sum, so) => {
      return sum + so.items.reduce((itemSum, item) => itemSum + item.quantity, 0);
    }, 0);
    const completedCount = stockOuts.filter(s => s.status === 'completed').length;

    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139',
    );

    pdf.addReportTitle(
      'BÁO CÁO XUẤT KHO',
      startDate || endDate 
        ? `Từ ${startDate ? new Date(startDate).toLocaleDateString('vi-VN') : '...'} đến ${endDate ? new Date(endDate).toLocaleDateString('vi-VN') : '...'}`
        : 'Tất cả giao dịch xuất kho',
      'Xuất kho'
    );

    const reportCode = `SOUT-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    pdf.addSummaryCards([
      {
        label: 'Tổng phiếu xuất',
        value: new Intl.NumberFormat('vi-VN').format(stockOuts.length),
        subtitle: 'Phiếu',
        color: '#FF9800'
      },
      {
        label: 'Tổng số lượng',
        value: new Intl.NumberFormat('vi-VN').format(totalQuantity),
        subtitle: 'Đơn vị',
        color: '#2196F3'
      },
      {
        label: 'Tổng giá trị',
        value: new Intl.NumberFormat('vi-VN').format(Math.round(totalAmount / 1000000)) + 'M',
        subtitle: 'VND',
        color: '#9C27B0'
      },
      {
        label: 'Hoàn thành',
        value: completedCount.toString(),
        subtitle: `/ ${stockOuts.length} phiếu`,
        color: '#4CAF50'
      }
    ]);

    pdf.addSectionHeader('CHI TIẾT PHIẾU XUẤT KHO');

    const headers = ['STT', 'Mã phiếu', 'Ngày xuất', 'Lý do', 'SL', 'Tổng tiền', 'TT'];
    const columnWidths = [35, 75, 75, 100, 45, 90, 80];
    const alignments = ['center', 'left', 'center', 'left', 'right', 'right', 'center'];
    
    const rows = stockOuts.map((item, index) => {
      const quantity = item.items.reduce((sum, i) => sum + i.quantity, 0);
      return [
        index + 1,
        item.code,
        new Date(item.exportDate).toLocaleDateString('vi-VN'),
        item.reason?.substring(0, 20) || '-',
        quantity,
        new Intl.NumberFormat('vi-VN').format(item.totalAmount || 0),
        item.status === 'completed' ? 'Hoan thanh' : item.status === 'pending' ? 'Cho duyet' : 'Huy'
      ];
    });

    pdf.drawTable(headers, rows, columnWidths, { alignments });

    pdf.addWatermark('GREENMART');
    pdf.addFooter(true);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=bao-cao-xuat-kho-${reportCode}.pdf`);
    
    pdf.pipe(res).end();
  } catch (error) {
    console.error('Get stock out report PDF error:', error);
    return ApiResponse.error(res, error.message);
  }
};

/**
 * @desc    Báo cáo tổng hợp PDF
 * @route   GET /api/reports/summary/pdf
 * @access  Private
 */
const getSummaryReportPDF = async (req, res) => {
  try {
    // Lấy dữ liệu tổng hợp
    const totalProducts = await Product.countDocuments();
    const totalSuppliers = await Supplier.countDocuments({ isActive: true });
    
    const stockValue = await Product.aggregate([
      {
        $group: {
          _id: null,
          totalValue: { $sum: { $multiply: ['$currentStock', '$costPrice'] } },
          totalQuantity: { $sum: '$currentStock' }
        }
      }
    ]);

    const lowStockProducts = await Product.countDocuments({
      $expr: { $lte: ['$currentStock', '$minStock'] }
    });

    const recentStockIns = await StockIn.find({ status: 'completed' })
      .sort({ createdAt: -1 })
      .limit(10)
      .populate('supplier', 'name');

    const recentStockOuts = await StockOut.find({ status: 'completed' })
      .sort({ createdAt: -1 })
      .limit(10);

    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139',
    );

    pdf.addReportTitle(
      'BÁO CÁO TỔNG HỢP HỆ THỐNG',
      'Tổng quan toàn bộ hoạt động kho',
      'Tổng hợp'
    );

    const reportCode = `SUM-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    // Summary overview cards
    pdf.addSummaryCards([
      {
        label: 'Tổng sản phẩm',
        value: new Intl.NumberFormat('vi-VN').format(totalProducts),
        subtitle: 'Mặt hàng đang quản lý',
        color: '#2196F3'
      },
      {
        label: 'Nhà cung cấp',
        value: new Intl.NumberFormat('vi-VN').format(totalSuppliers),
        subtitle: 'Đang hoạt động',
        color: '#4CAF50'
      },
      {
        label: 'Tồn kho',
        value: new Intl.NumberFormat('vi-VN').format(stockValue[0]?.totalQuantity || 0),
        subtitle: 'Đơn vị',
        color: '#FF9800'
      },
      {
        label: 'Giá trị kho',
        value: new Intl.NumberFormat('vi-VN').format(Math.round((stockValue[0]?.totalValue || 0) / 1000000)) + 'M',
        subtitle: 'VND',
        color: '#9C27B0'
      },
      {
        label: 'Sắp hết hàng',
        value: lowStockProducts.toString(),
        subtitle: 'Cần nhập thêm',
        color: '#F44336'
      }
    ], { columns: 3 });

    pdf.addSectionHeader('NHẬP KHO GẦN ĐÂY (10 PHIẾU)');

    const stockInHeaders = ['STT', 'Mã phiếu', 'Nhà cung cấp', 'Ngày nhập', 'Tổng tiền'];
    const stockInWidths = [35, 95, 160, 90, 120];
    const stockInAlignments = ['center', 'left', 'left', 'center', 'right'];
    const stockInRows = recentStockIns.map((item, index) => [
      index + 1,
      item.code,
      item.supplier?.name?.substring(0, 25) || '-',
      new Date(item.importDate).toLocaleDateString('vi-VN'),
      new Intl.NumberFormat('vi-VN').format(item.totalAmount || 0)
    ]);

    pdf.drawTable(stockInHeaders, stockInRows, stockInWidths, { alignments: stockInAlignments });

    pdf.doc.moveDown(1.5);

    pdf.addSectionHeader('XUẤT KHO GẦN ĐÂY (10 PHIẾU)');

    const stockOutHeaders = ['STT', 'Mã phiếu', 'Lý do', 'Ngày xuất', 'Tổng tiền'];
    const stockOutWidths = [35, 95, 160, 90, 120];
    const stockOutAlignments = ['center', 'left', 'left', 'center', 'right'];
    const stockOutRows = recentStockOuts.map((item, index) => [
      index + 1,
      item.code,
      item.reason?.substring(0, 25) || '-',
      new Date(item.exportDate).toLocaleDateString('vi-VN'),
      new Intl.NumberFormat('vi-VN').format(item.totalAmount || 0)
    ]);

    pdf.drawTable(stockOutHeaders, stockOutRows, stockOutWidths, { alignments: stockOutAlignments });

    pdf.addWatermark('GREENMART');
    pdf.addFooter(true);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `attachment; filename=bao-cao-tong-hop-${reportCode}.pdf`);
    
    pdf.pipe(res).end();
  } catch (error) {
    console.error('Get summary report PDF error:', error);
    return ApiResponse.error(res, error.message);
  }
};

module.exports = {
  getInventoryReportPDF,
  getStockInReportPDF,
  getStockOutReportPDF,
  getSummaryReportPDF
};
