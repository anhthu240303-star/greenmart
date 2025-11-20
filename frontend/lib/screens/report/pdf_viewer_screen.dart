import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PdfViewerScreen extends StatefulWidget {
  final String pdfUrl;
  final String reportTitle;
  final String reportType;

  const PdfViewerScreen({
    super.key,
    required this.pdfUrl,
    required this.reportTitle,
    required this.reportType,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  bool _isDownloading = false;
  bool _isLoading = true;
  int _currentPage = 0;
  int _totalPages = 0;
  Uint8List? _pdfBytes;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPdfWithAuth();
  }

  Future<void> _loadPdfWithAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        throw Exception('Chưa đăng nhập');
      }

      print('📄 Loading PDF from: ${widget.pdfUrl}');

      // Add timeout to prevent hanging
      final response = await http.get(
        Uri.parse(widget.pdfUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ Timeout loading PDF');
          throw Exception('Timeout: Không thể tải PDF sau 30 giây');
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📦 Response size: ${response.bodyBytes.length} bytes');
      print('📋 Content-Type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        // Check if response is actually PDF
        if (response.bodyBytes.isEmpty) {
          throw Exception('PDF rỗng');
        }
        
        // Check PDF magic number
        if (response.bodyBytes.length >= 4) {
          final header = String.fromCharCodes(response.bodyBytes.take(4));
          print('📄 File header: $header');
          if (!header.startsWith('%PDF')) {
            print('⚠️ Warning: Not a valid PDF file');
          }
        }
        
        print('✅ PDF loaded successfully');
        
        setState(() {
          _pdfBytes = response.bodyBytes;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn');
      } else {
        throw Exception('Lỗi tải PDF: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('❌ Error loading PDF: $e');
      
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      // Show error in SnackBar too
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Thử lại',
              textColor: Colors.white,
              onPressed: _loadPdfWithAuth,
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.reportTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_totalPages > 0)
              Text(
                'Trang ${_currentPage + 1}/$_totalPages',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel + 0.25;
            },
            tooltip: 'Phóng to',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              _pdfViewerController.zoomLevel = _pdfViewerController.zoomLevel - 0.25;
            },
            tooltip: 'Thu nhỏ',
          ),
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.download),
            onPressed: _isDownloading ? null : _downloadPdf,
            tooltip: 'Tải xuống',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang tải PDF...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Lỗi tải PDF',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadPdfWithAuth,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // PDF Viewer
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          try {
                            return SfPdfViewer.memory(
                              _pdfBytes!,
                              controller: _pdfViewerController,
                              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                                setState(() {
                                  _totalPages = details.document.pages.count;
                                });
                              },
                              onPageChanged: (PdfPageChangedDetails details) {
                                setState(() {
                                  _currentPage = details.newPageNumber;
                                });
                              },
                              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                                setState(() {
                                  _errorMessage = 'Lỗi load PDF: ${details.error}\n${details.description}';
                                });
                              },
                            );
                          } catch (e) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.error, size: 64, color: Colors.red),
                                  const SizedBox(height: 16),
                                  Text('Lỗi hiển thị PDF: ${e.toString()}'),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _pdfBytes = null;
                                      });
                                      _loadPdfWithAuth();
                                    },
                                    child: const Text('Thử lại'),
                                  ),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    
                    // Bottom toolbar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.first_page),
                                onPressed: () {
                                  _pdfViewerController.jumpToPage(1);
                                },
                                tooltip: 'Trang đầu',
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 0
                                    ? () {
                                        _pdfViewerController.previousPage();
                                      }
                                    : null,
                                tooltip: 'Trang trước',
                              ),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _totalPages > 0 ? '${_currentPage + 1} / $_totalPages' : 'Đang tải...',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage < _totalPages - 1
                                    ? () {
                                        _pdfViewerController.nextPage();
                                      }
                                    : null,
                                tooltip: 'Trang sau',
                              ),
                              IconButton(
                                icon: const Icon(Icons.last_page),
                                onPressed: () {
                                  _pdfViewerController.jumpToPage(_totalPages);
                                },
                                tooltip: 'Trang cuối',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _isLoading || _errorMessage != null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isDownloading ? null : _downloadPdf,
              backgroundColor: Colors.green,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(_isDownloading ? 'Đang tải...' : 'Tải xuống'),
            ),
    );
  }

  Future<void> _downloadPdf() async {
    if (_pdfBytes == null) return;

    setState(() => _isDownloading = true);

    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        
        if (!status.isGranted) {
          // Try manageExternalStorage for Android 11+
          var manageStatus = await Permission.manageExternalStorage.status;
          if (!manageStatus.isGranted) {
            manageStatus = await Permission.manageExternalStorage.request();
          }
        }
      }

      // Get Downloads directory
      Directory? downloadsDir;
      
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          final appDir = await getExternalStorageDirectory();
          downloadsDir = Directory('${appDir!.path}/Download');
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      } else {
        downloadsDir = await getDownloadsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Không tìm thấy thư mục Download');
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'bao_cao_${widget.reportType}_$timestamp.pdf';
      final filePath = '${downloadsDir.path}/$filename';

      final file = File(filePath);
      await file.writeAsBytes(_pdfBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tải thành công!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Đã lưu tại: $filePath',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }
}
