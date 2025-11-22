import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../widgets/stat_card.dart';
import 'package:http/http.dart' as http;
import 'pdf_viewer_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _isLoading = false;
  String? _message;
  String? _categoryId;
  String? _supplierId;
  List<dynamic> _categories = [];
  List<dynamic> _suppliers = [];
  DashboardStats? _stats;
  bool _statsLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() => _statsLoading = true);
    try {
      final data = await ApiService.instance.getDashboardOverview();
      if (!mounted) return;
      _stats = DashboardStats.fromJson(data);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<void> _loadLookups() async {
    try {
      final cats = await ApiService.instance.getAllCategories();
      final sups = await ApiService.instance.getSuppliers();
      setState(() {
        _categories = cats;
        _suppliers = sups;
      });
    } catch (e) {
      // ignore
    }
  }

  Future<void> _viewPdfReport(String reportType, {String? customTitle}) async {
    // Map report type to title
    final Map<String, String> reportTitles = {
      'inventory': 'Báo cáo tồn kho',
      'stock-in': 'Báo cáo nhập kho',
      'stock-out': 'Báo cáo xuất kho',
      'summary': 'Báo cáo tổng hợp',
    };

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang chuẩn bị PDF...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Chưa đăng nhập');
      }

      // Build URL with query parameters
      String url = 'http://10.0.2.2:5000/api/reports/$reportType/pdf';
      List<String> queryParams = [];

      if (_startDate != null) {
        queryParams.add('startDate=${DateFormat('yyyy-MM-dd').format(_startDate!)}');
      }
      if (_endDate != null) {
        queryParams.add('endDate=${DateFormat('yyyy-MM-dd').format(_endDate!)}');
      }
      if (_supplierId != null && reportType == 'stock-in') {
        queryParams.add('supplier=$_supplierId');
      }
      if (_categoryId != null && reportType == 'inventory') {
        queryParams.add('category=$_categoryId');
      }

      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to PDF viewer
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
                  pdfUrl: url,
                  reportTitle: customTitle ?? reportTitles[reportType] ?? 'Báo cáo',
                  reportType: reportType,
                ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if open
      if (mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      // don't allow selecting future dates for reports
      lastDate: DateTime.now(), 
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final today = DateTime.now();
      if (picked.start.isAfter(DateTime(today.year, today.month, today.day)) || picked.end.isAfter(DateTime(today.year, today.month, today.day))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không được chọn ngày trong tương lai cho báo cáo.')));
        }
        return;
      }
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
  
  // Hàm tải xuống PDF (ĐÃ SỬA: SỬ DỤNG getExternalStorageDirectory cho thư mục công cộng)
  Future<void> _downloadPdfReport(String reportType, {String? customTitle}) async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Chưa đăng nhập');
      }

      // Xây dựng URL (Giữ nguyên logic query parameters)
      String url = 'http://10.0.2.2:5000/api/reports/$reportType/pdf';
      List<String> queryParams = [];

      if (_startDate != null) {
        queryParams.add('startDate=${DateFormat('yyyy-MM-dd').format(_startDate!)}');
      }
      if (_endDate != null) {
        queryParams.add('endDate=${DateFormat('yyyy-MM-dd').format(_endDate!)}');
      }
      if (_supplierId != null && _supplierId!.isNotEmpty && reportType == 'stock-in') {
        queryParams.add('supplier=$_supplierId');
      }
      if (_categoryId != null && _categoryId!.isNotEmpty && reportType == 'inventory') {
        queryParams.add('category=$_categoryId');
      }
      if (queryParams.isNotEmpty) {
        url += '?${queryParams.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // ------------------------------------------------------------------
        // SỬA ĐỔI QUAN TRỌNG: LƯU VÀO THƯ MỤC DOWNLOADS CÔNG CỘNG
        // ------------------------------------------------------------------
        // Lưu ý: getExternalStorageDirectory() có thể cần quyền truy cập bộ nhớ ngoài
        // Tên thư mục 'Download' là convention (phổ biến)
        
        final directory = await getExternalStorageDirectory(); 
        
        // Tạo đường dẫn file: /storage/emulated/0/Download/bao_cao_...pdf
        final downloadsPath = '${directory!.path}/Download';
        final downloadsDir = Directory(downloadsPath);

        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final safeTitle = (customTitle ?? reportType).replaceAll(' ', '_').toLowerCase();
        final filePath = '${downloadsDir.path}/bao_cao_${safeTitle}_$timestamp.pdf';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          setState(() => _message = 'Tải thành công: $filePath');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã tải báo cáo PDF vào thư mục Downloads: $filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        throw Exception('Lỗi tải báo cáo: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = 'Lỗi: ${e.toString()}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _exportCsv() async {
    // Logic xuất CSV giữ nguyên (vẫn dùng getApplicationDocumentsDirectory)
    // ... (logic export CSV giữ nguyên như code trước đó)
    setState(() {
      _isLoading = true;
      _message = null;
    });

    try {
      final query = <String, dynamic>{};
      if (_categoryId != null && _categoryId!.isNotEmpty) query['categoryId'] = _categoryId;
      if (_supplierId != null && _supplierId!.isNotEmpty) query['supplierId'] = _supplierId;

      final data = await ApiService.instance.getInventoryReport(queryParameters: query);

      final products = (data['products'] as List<dynamic>? ) ?? [];

      // Build CSV
      final headers = [
        'SKU','Name','Barcode','Stock','MinStock','MaxStock','Unit','CostPrice','SellingPrice','StockValue','StockStatus'
      ];
      final csv = StringBuffer();
      csv.writeln(headers.join(','));

      for (final p in products) {
        final row = [
          '"${p['sku'] ?? ''}"',
          '"${(p['name'] ?? '').toString().replaceAll('"', '""')}"',
          '"${p['barcode'] ?? ''}"',
          '${p['stock'] ?? 0}',
          '${p['minStock'] ?? 0}',
          '${p['maxStock'] ?? 0}',
          '"${p['unit'] ?? ''}"',
          '${p['costPrice'] ?? 0}',
          '${p['sellingPrice'] ?? 0}',
          '${p['stockValue'] ?? 0}',
          '"${p['stockStatus'] ?? ''}"',
        ];
        csv.writeln(row.join(','));
      }

      final dir = await getApplicationDocumentsDirectory();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/inventory_report_$ts.csv');
      await file.writeAsString(csv.toString());

      final resultPath = file.path;
      if (mounted) {
        setState(() => _message = 'Export thành công: $resultPath');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export thành công, lưu tại: $resultPath')));
      }
    } catch (e) {
      if (mounted) setState(() => _message = 'Export thất bại: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    // ...
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview / statistics
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              clipBehavior: Clip.hardEdge,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thống kê', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (_statsLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                    else if (_stats != null)
                      Row(
                        children: [
                          Expanded(child: StatCard(title: 'Sản phẩm', value: _stats!.totalProducts.toString(), icon: Icons.inventory_2_outlined)),
                          const SizedBox(width: 8),
                          Expanded(child: StatCard(title: 'Danh mục', value: _stats!.totalCategories.toString(), icon: Icons.category_outlined)),
                          const SizedBox(width: 8),
                          Expanded(child: StatCard(title: 'Nhà cung cấp', value: _stats!.totalSuppliers.toString(), icon: Icons.local_shipping_outlined)),
                          const SizedBox(width: 8),
                          Expanded(child: StatCard(title: 'Sắp hết', value: _stats!.lowStockProducts.toString(), icon: Icons.warning_amber_rounded, color: AppTheme.warning)),
                        ],
                      )
                    else
                      const Text('Không có dữ liệu thống kê'),
                  ],
                ),
              ),
            ),

            // Filters
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bộ lọc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categoryId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Danh mục (tùy chọn)'),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('Tất cả')),
                              ..._categories.map((c) => DropdownMenuItem<String>(value: c['_id'] ?? c['id'], child: Text(c['name'] ?? ''))),
                            ],
                            onChanged: (v) => setState(() => _categoryId = (v != null && v.isNotEmpty) ? v : null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _supplierId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Nhà cung cấp (tùy chọn)'),
                            items: [
                              const DropdownMenuItem<String>(value: null, child: Text('Tất cả')),
                              ..._suppliers.map((s) => DropdownMenuItem<String>(value: s['_id'] ?? s['id'], child: Text(s['name'] ?? ''))),
                            ],
                            onChanged: (v) => setState(() => _supplierId = (v != null && v.isNotEmpty) ? v : null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDateRange,
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _startDate != null && _endDate != null
                                  ? 'Từ ${DateFormat('dd/MM/yyyy').format(_startDate!)} - ${DateFormat('dd/MM/yyyy').format(_endDate!)}'
                                  : 'Chọn khoảng thời gian',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (_startDate != null)
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _startDate = null;
                              _endDate = null;
                            }),
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Xóa'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // PDF Reports
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Báo cáo PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _buildPdfReportButtons(),
                    const SizedBox(height: 8),
                
                  ],
                ),
              ),
            ),

            // Export
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: (_isLoading || _statsLoading) ? null : _exportCsv,
                      icon: const Icon(Icons.download_outlined),
                      label: Text(_isLoading ? 'Đang tạo...' : 'Xuất CSV'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    if (_message != null) Expanded(child: Text(_message!, style: const TextStyle(fontSize: 12))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfReportButtons() {
    final summaryReports = [
      {
        'title': 'Tổng hợp theo kỳ',
        'icon': Icons.calendar_month,
        'color': Colors.blue,
        'type': 'summary/period',
        'desc': 'Tổng nhập/xuất, tồn kho, chênh lệch theo ngày/tuần/tháng/năm',
      },
      {
        'title': 'Báo cáo chênh lệch',
        'icon': Icons.balance,
        'color': Colors.red,
        'type': 'discrepancy/period',
        'desc': 'Báo cáo chênh lệch kiểm kê theo kỳ',
      },
      {
        'title': 'Tồn kho tổng hợp',
        'icon': Icons.inventory_2,
        'color': Colors.green,
        'type': 'summary/inventory',
        'desc': 'Tổng hợp tồn kho theo danh mục',
      },
      {
        'title': 'Tổng hợp theo danh mục',
        'icon': Icons.category,
        'color': Colors.purple,
        'type': 'summary/category',
        'desc': 'Xu hướng nhập/xuất/tồn theo danh mục',
      },
    ];
    final detailReports = [
      {
        'title': 'Nhập kho chi tiết',
        'icon': Icons.arrow_downward,
        'color': Colors.blue,
        'type': 'detail/stock-in',
        'desc': 'Từng phiếu nhập, sản phẩm, số lô, HSD',
      },
      {
        'title': 'Xuất kho chi tiết',
        'icon': Icons.arrow_upward,
        'color': Colors.orange,
        'type': 'detail/stock-out',
        'desc': 'Từng phiếu xuất, sản phẩm, lô xuất FIFO',
      },
      {
        'title': 'Tồn kho theo lô',
        'icon': Icons.qr_code_2,
        'color': Colors.green,
        'type': 'detail/batch-inventory',
        'desc': 'Chi tiết từng lô: số lô, HSD, SL tồn, giá vốn',
      },
    ];

    

    // Use LayoutBuilder once to compute tile width and create a responsive grid
    Widget buildTiles(List<Map<String, dynamic>> reports) {
      return LayoutBuilder(builder: (context, constraints) {
        const double spacing = 12.0;
        const double minTileWidth = 140.0;
        // decide number of columns based on available width
        final int columns = (constraints.maxWidth >= (minTileWidth * 2 + spacing)) ? 2 : 1;
        final double totalSpacing = spacing * (columns - 1);
        final double tileWidth = (constraints.maxWidth - totalSpacing) / columns;
        final double finalTileWidth = tileWidth.clamp(minTileWidth, constraints.maxWidth);

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: reports.map((report) {
            final Color color = report['color'] as Color;
            return SizedBox(
              width: finalTileWidth,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: color.withOpacity(0.2)),
                ),
                color: color.withOpacity(0.04),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(report['icon'] as IconData, size: 22, color: color),
                          const SizedBox(width: 8),
                          Flexible(child: Text(report['title'] as String, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(report['desc'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: _isLoading ? null : () => _viewPdfReport(report['type'] as String, customTitle: report['title'] as String),
                            icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                            label: const Text('Xem'),
                            style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          ),
                          TextButton.icon(
                            onPressed: _isLoading ? null : () => _downloadPdfReport(report['type'] as String, customTitle: report['title'] as String),
                            icon: const Icon(Icons.file_download_outlined, size: 16),
                            label: const Text('Tải'),
                            style: TextButton.styleFrom(foregroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        const Text('BÁO CÁO TỔNG HỢP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        buildTiles(summaryReports),
        const SizedBox(height: 12),
        const Text('BÁO CÁO CHI TIẾT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        buildTiles(detailReports),
      ],
    );
  }
}