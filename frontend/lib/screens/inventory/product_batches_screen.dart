import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class ProductBatchesScreen extends StatefulWidget {
  const ProductBatchesScreen({Key? key}) : super(key: key);

  @override
  State<ProductBatchesScreen> createState() => _ProductBatchesScreenState();
}

class _ProductBatchesScreenState extends State<ProductBatchesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _batches = [];
  String? _productId;
  String? _productName;
  String? _productImage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _productId = args?['productId'] as String?;
    _productName = args?['productName'] as String? ?? 'Sản phẩm';
    _loadBatches();
  }

  Future<void> _loadBatches() async {
    if (_productId == null) return;
    setState(() => _loading = true);
    try {
      final items = await ApiService.instance.getProductBatches(_productId!);
      // try to fetch product details to get image
      try {
        final prod = await ApiService.instance.getProductById(_productId!);
        // ApiService now returns the product object (normalized) and may include `imageUrl`
        String? img;
        if (prod['imageUrl'] is String && (prod['imageUrl'] as String).isNotEmpty) {
          img = prod['imageUrl'] as String;
        } else if (prod['images'] is List && (prod['images'] as List).isNotEmpty) {
          final imgs = prod['images'] as List<dynamic>;
          final primary = imgs.firstWhere((e) => e is Map && (e['isPrimary'] == true), orElse: () => null);
          final chosen = primary ?? imgs.first;
          if (chosen is Map && chosen['url'] is String) img = chosen['url'] as String;
        }
        _productImage = img;
      } catch (_) {
        _productImage = null;
      }
      if (!mounted) return;
      // debug: print product object for inspection
      try {
        if (items.isNotEmpty) {
          final firstProd = (items[0] as Map<String, dynamic>)['product'];
          // use debugPrint so it appears in Flutter logs
          // ignore: avoid_print
          debugPrint('Product from getProductBatches: ' + firstProd.toString());
        }
      } catch (_) {}

      setState(() {
        _batches = items;
        _error = null;
      });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_productImage != null && _productImage!.isNotEmpty) ...[
              ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(_productImage!, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 40, height: 40, color: Colors.grey.shade200))),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text('Lô hàng - ${_productName ?? ''}')),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBatches,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [Padding(padding: const EdgeInsets.all(16.0), child: Text('Lỗi: $_error', style: const TextStyle(color: Colors.red)))]
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _batches.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, i) {
                        final b = _batches[i] as Map<String, dynamic>;
                        final batchNo = b['batchNumber'] ?? '—';
                        final rem = b['remainingQuantity'] ?? 0;
                        final init = b['initialQuantity'] ?? 0;
                        final expiry = b['expiryDate'];
                        String expiryText = expiry != null ? expiry.toString().split('T').first : '—';

                        return ListTile(
                          title: Text(batchNo, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('Còn: $rem / $init • HSD: $expiryText'),
                          trailing: Icon(Icons.chevron_right, color: AppTheme.primary),
                          onTap: () => Navigator.pushNamed(context, '/inventory/batch', arguments: b),
                        );
                      }
                    ),
        ),
      ),
    );
  }
}
