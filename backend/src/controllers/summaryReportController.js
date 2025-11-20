const Product = require('../models/Product');
const StockIn = require('../models/StockIn');
const StockOut = require('../models/StockOut');
const Category = require('../models/Category');
const BatchLot = require('../models/BatchLot');
const ApiResponse = require('../utils/response');
const PDFGenerator = require('../utils/pdfGenerator');

/**
 * 🔹 A. BÁO CÁO TỔNG HỢP (SUMMARY REPORTS)
 * Không chi tiết từng phiếu, chỉ số tổng
 */

/**
 * @desc    Báo cáo tổng hợp theo kỳ (ngày/tuần/tháng/năm)
 * @route   GET /api/reports/summary/period/pdf
 * @access  Private
 */
const getPeriodSummaryPDF = async (req, res) => {
  try {
    const { startDate, endDate, period = 'day' } = req.query;

    const start = startDate ? new Date(startDate) : new Date(new Date().setDate(1));
    const end = endDate ? new Date(endDate) : new Date();
    end.setHours(23, 59, 59, 999);

    // Tổng nhập trong kỳ
    const stockIns = await StockIn.find({
      importDate: { $gte: start, $lte: end },
      status: 'completed'
    });
    
    const totalStockInQuantity = stockIns.reduce((sum, si) => 
      sum + si.items.reduce((s, item) => s + item.quantity, 0), 0
    );
    const totalStockInValue = stockIns.reduce((sum, si) => sum + si.totalAmount, 0);

    // Tổng xuất trong kỳ
    const stockOuts = await StockOut.find({
      issueDate: { $gte: start, $lte: end },
      status: 'completed'
    });
    
    const totalStockOutQuantity = stockOuts.reduce((sum, so) => 
      sum + so.items.reduce((s, item) => s + item.quantity, 0), 0
    );
    const totalStockOutValue = stockOuts.reduce((sum, so) => sum + so.totalAmount, 0);

    // Tồn hiện tại
    const products = await Product.find({ status: { $in: ['active', 'out_of_stock'] } });
    const currentStockValue = products.reduce((sum, p) => sum + (p.currentStock * p.costPrice), 0);
    const currentStockQuantity = products.reduce((sum, p) => sum + p.currentStock, 0);

    // Chênh lệch
    const stockDifference = totalStockInQuantity - totalStockOutQuantity;
    const valueDifference = totalStockInValue - totalStockOutValue;

    // Tạo PDF
    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139'
    );

    pdf.addReportTitle(
      'BÁO CÁO TỔNG HỢP THEO KỲ',
      `Từ ${start.toLocaleDateString('vi-VN')} đến ${end.toLocaleDateString('vi-VN')}`,
      'SUMMARY'
    );

    const reportCode = `SUM-PERIOD-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    // Summary cards
    pdf.addSummaryCards([
      {
        label: 'Tổng nhập trong kỳ',
        value: new Intl.NumberFormat('vi-VN').format(totalStockInQuantity),
        subtitle: `${new Intl.NumberFormat('vi-VN').format(Math.round(totalStockInValue / 1000000))}M VND`,
        color: '#4CAF50'
      },
      {
        label: 'Tổng xuất trong kỳ',
        value: new Intl.NumberFormat('vi-VN').format(totalStockOutQuantity),
        subtitle: `${new Intl.NumberFormat('vi-VN').format(Math.round(totalStockOutValue / 1000000))}M VND`,
        color: '#FF9800'
      },
      {
        label: 'Chênh lệch',
        value: (stockDifference >= 0 ? '+' : '') + new Intl.NumberFormat('vi-VN').format(stockDifference),
        subtitle: `${valueDifference >= 0 ? '+' : ''}${new Intl.NumberFormat('vi-VN').format(Math.round(valueDifference / 1000000))}M VND`,
        color: stockDifference >= 0 ? '#2196F3' : '#F44336'
      },
      {
        label: 'Tồn cuối kỳ',
        value: new Intl.NumberFormat('vi-VN').format(currentStockQuantity),
        subtitle: `${new Intl.NumberFormat('vi-VN').format(Math.round(currentStockValue / 1000000))}M VND`,
        color: '#9C27B0'
      }
    ]);

    pdf.addSectionHeader('CHI TIẾT TỔNG HỢP');

    const headers = ['Chỉ tiêu', 'Số lượng', 'Giá trị (VND)'];
    const columnWidths = [200, 120, 160];
    const alignments = ['left', 'right', 'right'];
    
    const rows = [
      ['Tổng nhập kho', 
        new Intl.NumberFormat('vi-VN').format(totalStockInQuantity),
        new Intl.NumberFormat('vi-VN').format(totalStockInValue)
      ],
      ['Tổng xuất kho', 
        new Intl.NumberFormat('vi-VN').format(totalStockOutQuantity),
        new Intl.NumberFormat('vi-VN').format(totalStockOutValue)
      ],
      ['Chênh lệch tăng/giảm', 
        (stockDifference >= 0 ? '+' : '') + new Intl.NumberFormat('vi-VN').format(stockDifference),
        (valueDifference >= 0 ? '+' : '') + new Intl.NumberFormat('vi-VN').format(valueDifference)
      ],
      ['Tồn cuối kỳ', 
        new Intl.NumberFormat('vi-VN').format(currentStockQuantity),
        new Intl.NumberFormat('vi-VN').format(currentStockValue)
      ],
    ];

    pdf.drawTable(headers, rows, columnWidths, { alignments });

    pdf.addWatermark('GREENMART');
    pdf.addFooter(true);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="bao-cao-tong-hop-${Date.now()}.pdf"`);
    
    pdf.doc.pipe(res);
    pdf.doc.end();

  } catch (error) {
    console.error('Error generating period summary PDF:', error);
    return ApiResponse.error(res, 'Lỗi khi tạo báo cáo tổng hợp theo kỳ', 500);
  }
};

/**
 * @desc    Báo cáo tổng hợp tồn kho
 * @route   GET /api/reports/summary/inventory/pdf
 * @access  Private
 */
const getInventorySummaryPDF = async (req, res) => {
  try {
    const { category } = req.query;

    const query = { status: { $in: ['active', 'out_of_stock'] } };
    if (category) query.category = category;

    const products = await Product.find(query)
      .populate('category', 'name')
      .sort({ name: 1 });

    // Group by category
    const categoryGroups = {};
    products.forEach(p => {
      const catName = p.category?.name || 'Không phân loại';
      if (!categoryGroups[catName]) {
        categoryGroups[catName] = {
          products: 0,
          quantity: 0,
          value: 0
        };
      }
      categoryGroups[catName].products += 1;
      categoryGroups[catName].quantity += p.currentStock;
      categoryGroups[catName].value += p.currentStock * p.costPrice;
    });

    // Totals
    const totalProducts = products.length;
    const totalQuantity = products.reduce((sum, p) => sum + p.currentStock, 0);
    const totalValue = products.reduce((sum, p) => sum + (p.currentStock * p.costPrice), 0);

    // Tạo PDF
    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139'
    );

    pdf.addReportTitle(
      'BÁO CÁO TỒN KHO TỔNG HỢP',
      'Tổng quan tồn kho hiện tại theo danh mục',
      'INVENTORY'
    );

    const reportCode = `INV-SUM-${Date.now().toString().slice(-8)}`;
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
        label: 'Tổng số lượng tồn',
        value: new Intl.NumberFormat('vi-VN').format(totalQuantity),
        subtitle: 'Đơn vị',
        color: '#4CAF50'
      },
      {
        label: 'Giá trị tồn kho',
        value: new Intl.NumberFormat('vi-VN').format(Math.round(totalValue / 1000000)) + 'M',
        subtitle: 'VND',
        color: '#9C27B0'
      },
      {
        label: 'Số danh mục',
        value: Object.keys(categoryGroups).length.toString(),
        subtitle: 'Phân loại',
        color: '#FF9800'
      }
    ]);

    pdf.addSectionHeader('TỒN KHO THEO DANH MỤC');

    const headers = ['Danh mục', 'SP', 'Số lượng', 'Giá trị (VND)'];
    const columnWidths = [200, 80, 100, 135];
    const alignments = ['left', 'right', 'right', 'right'];
    
    const rows = Object.entries(categoryGroups).map(([catName, data]) => [
      catName,
      new Intl.NumberFormat('vi-VN').format(data.products),
      new Intl.NumberFormat('vi-VN').format(data.quantity),
      new Intl.NumberFormat('vi-VN').format(data.value)
    ]);

    // Tổng cộng
    rows.push([
      'TỔNG CỘNG',
      new Intl.NumberFormat('vi-VN').format(totalProducts),
      new Intl.NumberFormat('vi-VN').format(totalQuantity),
      new Intl.NumberFormat('vi-VN').format(totalValue)
    ]);

    pdf.drawTable(headers, rows, columnWidths, { alignments });

    pdf.addWatermark('GREENMART');
    pdf.addFooter(true);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="ton-kho-tong-hop-${Date.now()}.pdf"`);
    
    pdf.doc.pipe(res);
    pdf.doc.end();

  } catch (error) {
    console.error('Error generating inventory summary PDF:', error);
    return ApiResponse.error(res, 'Lỗi khi tạo báo cáo tồn kho tổng hợp', 500);
  }
};

/**
 * @desc    Báo cáo tổng hợp theo danh mục
 * @route   GET /api/reports/summary/category/pdf
 * @access  Private
 */
const getCategorySummaryPDF = async (req, res) => {
  try {
    const { startDate, endDate } = req.query;

    const start = startDate ? new Date(startDate) : new Date(new Date().setMonth(new Date().getMonth() - 1));
    const end = endDate ? new Date(endDate) : new Date();
    end.setHours(23, 59, 59, 999);

    const categories = await Category.find();
    const categoryData = [];

    for (const cat of categories) {
      const products = await Product.find({ category: cat._id });
      const productIds = products.map(p => p._id);

      // Nhập trong kỳ
      const stockIns = await StockIn.find({
        importDate: { $gte: start, $lte: end },
        status: 'completed',
        'items.product': { $in: productIds }
      });

      const importQty = stockIns.reduce((sum, si) => {
        return sum + si.items
          .filter(item => productIds.some(id => id.equals(item.product)))
          .reduce((s, item) => s + item.quantity, 0);
      }, 0);

      const importValue = stockIns.reduce((sum, si) => {
        return sum + si.items
          .filter(item => productIds.some(id => id.equals(item.product)))
          .reduce((s, item) => s + item.totalPrice, 0);
      }, 0);

      // Xuất trong kỳ
      const stockOuts = await StockOut.find({
        issueDate: { $gte: start, $lte: end },
        status: 'completed',
        'items.product': { $in: productIds }
      });

      const exportQty = stockOuts.reduce((sum, so) => {
        return sum + so.items
          .filter(item => productIds.some(id => id.equals(item.product)))
          .reduce((s, item) => s + item.quantity, 0);
      }, 0);

      const exportValue = stockOuts.reduce((sum, so) => {
        return sum + so.items
          .filter(item => productIds.some(id => id.equals(item.product)))
          .reduce((s, item) => s + item.totalPrice, 0);
      }, 0);

      // Tồn hiện tại
      const currentStock = products.reduce((sum, p) => sum + p.currentStock, 0);
      const currentValue = products.reduce((sum, p) => sum + (p.currentStock * p.costPrice), 0);

      categoryData.push({
        name: cat.name,
        importQty,
        importValue,
        exportQty,
        exportValue,
        currentStock,
        currentValue
      });
    }

    // Tạo PDF
    const pdf = new PDFGenerator();
    
    pdf.addCompanyHeader(
      'GREENMART - HỆ THỐNG QUẢN LÝ KHO',
      '236B Lê Văn Sỹ, Quận Tân Bình, Thành phố Hồ Chí Minh',
      '0832 493 139'
    );

    pdf.addReportTitle(
      'BÁO CÁO TỔNG HỢP THEO DANH MỤC',
      `Từ ${start.toLocaleDateString('vi-VN')} đến ${end.toLocaleDateString('vi-VN')}`,
      'SUMMARY'
    );

    const reportCode = `CAT-SUM-${Date.now().toString().slice(-8)}`;
    pdf.addReportMeta(
      new Date(),
      req.user?.fullName || req.user?.username || 'Hệ thống',
      reportCode
    );

    pdf.addSectionHeader('TỔNG HỢP XU HƯỚNG THEO DANH MỤC');

    const headers = ['Danh mục', 'Nhập', 'Xuất', 'Tồn', 'GT Tồn (VND)'];
    const columnWidths = [150, 80, 80, 80, 125];
    const alignments = ['left', 'right', 'right', 'right', 'right'];
    
    const rows = categoryData.map(cat => [
      cat.name,
      new Intl.NumberFormat('vi-VN').format(cat.importQty),
      new Intl.NumberFormat('vi-VN').format(cat.exportQty),
      new Intl.NumberFormat('vi-VN').format(cat.currentStock),
      new Intl.NumberFormat('vi-VN').format(cat.currentValue)
    ]);

    pdf.drawTable(headers, rows, columnWidths, { alignments });

    pdf.addWatermark('GREENMART');
    pdf.addFooter(true);

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="danh-muc-tong-hop-${Date.now()}.pdf"`);
    
    pdf.doc.pipe(res);
    pdf.doc.end();

  } catch (error) {
    console.error('Error generating category summary PDF:', error);
    return ApiResponse.error(res, 'Lỗi khi tạo báo cáo tổng hợp theo danh mục', 500);
  }
};

module.exports = {
  getPeriodSummaryPDF,
  getInventorySummaryPDF,
  getCategorySummaryPDF
};
