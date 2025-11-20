import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/api_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({Key? key}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isLoading = true;
  ProductModel? _product;
  Map<String, dynamic>? _rawProduct;
  final PageController _pageCtrl = PageController();
  int _currentImage = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)!.settings.arguments as String?;
    if (id != null) _load(id);
  }

  Future<void> _load(String id) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.instance.getProductById(id);
      Map<String, dynamic> productData = {};
      if (data['product'] != null && data['product'] is Map<String, dynamic>) {
        productData = Map<String, dynamic>.from(data['product'] as Map);
      } else {
        productData = Map<String, dynamic>.from(data);
      }

      _rawProduct = productData;
      _product = ProductModel.fromJson(productData);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildInfoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.5,
                height: 1.4,
                color: bold ? AppTheme.primary : Colors.black87,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    final List<String> imageUrls = [];
    if (_rawProduct != null && _rawProduct!['images'] is List) {
      for (final img in (_rawProduct!['images'] as List)) {
        if (img == null) continue;
        if (img is Map) {
          final url = img['url'] ?? img['secure_url'] ?? img['path'];
          if (url is String && url.isNotEmpty) imageUrls.add(url);
        } else if (img is String && img.isNotEmpty) {
          imageUrls.add(img);
        } else {
          final s = img.toString();
          if (s.isNotEmpty) imageUrls.add(s);
        }
      }
    }
    if (imageUrls.isEmpty && _product != null && _product!.imageUrl.isNotEmpty) {
      imageUrls.add(_product!.imageUrl);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Chi tiết sản phẩm',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _product == null
                ? const Center(child: Text('Không tìm thấy sản phẩm'))
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ========== IMAGE + BASIC INFO ==========
                        Card(
                          elevation: 1,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.paddingMedium),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // --- IMAGE CAROUSEL ---
                                if (imageUrls.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: AspectRatio(
                                      aspectRatio: 1.3,
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          PageView.builder(
                                            controller: _pageCtrl,
                                            itemCount: imageUrls.length,
                                            onPageChanged: (i) =>
                                                setState(() => _currentImage = i),
                                            itemBuilder: (context, index) {
                                              final url = imageUrls[index];
                                              return CachedNetworkImage(
                                                imageUrl: url,
                                                fit: BoxFit.cover,
                                                width: double.infinity,
                                                placeholder: (c, u) =>
                                                    const Center(child: CircularProgressIndicator()),
                                                errorWidget: (c, u, e) => const Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 48,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                          ),
                                          // dot indicators
                                          Positioned(
                                            bottom: 10,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: List.generate(
                                                imageUrls.length,
                                                (i) => AnimatedContainer(
                                                  duration: const Duration(milliseconds: 250),
                                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                                  width: _currentImage == i ? 10 : 8,
                                                  height: _currentImage == i ? 10 : 8,
                                                  decoration: BoxDecoration(
                                                    color: _currentImage == i
                                                        ? Colors.white
                                                        : Colors.white70,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    height: 160,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.inventory_2_outlined,
                                          size: 60, color: AppTheme.primary),
                                    ),
                                  ),

                                const SizedBox(height: 16),
                                Text(
                                  _product!.name,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _product!.categoryName,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_rawProduct != null &&
                                    _rawProduct!['defaultSupplier'] != null)
                                  Text(
                                    'Nhà cung cấp: ${_rawProduct!['defaultSupplier'] is Map ? (_rawProduct!['defaultSupplier']['name'] ?? '-') : (_rawProduct!['defaultSupplier'] ?? '-')}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 15,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ========== DETAIL INFO ==========
                        Card(
                          elevation: 1,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.paddingMedium),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_rawProduct != null &&
                                    (_rawProduct!['description'] is String) &&
                                    (_rawProduct!['description'] as String).isNotEmpty) ...[
                                  const Text(
                                    'Mô tả',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Html(data: _rawProduct!['description'] as String),
                                  const SizedBox(height: 16),
                                ],
                                if (_rawProduct != null && _rawProduct!['createdBy'] != null)
                                  _buildInfoRow(
                                    'Người tạo:',
                                    _rawProduct!['createdBy'] is Map
                                        ? (_rawProduct!['createdBy']['fullName'] ??
                                            _rawProduct!['createdBy']['email'] ??
                                            '-')
                                        : (_rawProduct!['createdBy']?.toString() ?? '-'),
                                  ),
                                if (_rawProduct != null && _rawProduct!['createdAt'] != null)
                                  _buildInfoRow(
                                    'Ngày tạo:',
                                    () {
                                      try {
                                        final dt = DateTime.parse(
                                            _rawProduct!['createdAt'].toString());
                                        return DateFormat('dd/MM/yyyy HH:mm').format(dt);
                                      } catch (_) {
                                        return _rawProduct!['createdAt'].toString();
                                      }
                                    }(),
                                  ),
                                if (_rawProduct != null &&
                                    (_rawProduct!['location'] != null ||
                                        _rawProduct!['warehouse'] != null))
                                  _buildInfoRow(
                                    'Kho/Địa điểm:',
                                    (_rawProduct!['location'] ??
                                            _rawProduct!['warehouse'])
                                        ?.toString() ??
                                        '-',
                                  ),
                                const Divider(height: 24, thickness: 1.1),
                                _buildInfoRow('Tồn kho:',
                                    '${_product!.currentStock} ${_product!.unit}',
                                    bold: true),
                                _buildInfoRow('Giá nhập:',
                                    currency.format(_product!.costPrice)),
                                _buildInfoRow('Giá bán:',
                                    currency.format(_product!.sellingPrice),
                                    bold: true),
                                _buildInfoRow(
                                    'Mã sản phẩm:', _product!.barcode ?? '-'),
                                _buildInfoRow(
                                    'Trạng thái:', _product!.status),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
