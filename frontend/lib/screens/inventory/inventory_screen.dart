import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }
  Future<void> _loadProducts({int page = 1, int limit = 50}) async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.instance.getProductsPaginated(query: {'page': page, 'limit': limit});
      // result is { items: List, pagination: Map }
      final items = result['items'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() {
        _products = items;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Tag màu theo trạng thái tồn kho
  Widget _statusTag(bool isLow) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLow ? Colors.orange.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isLow ? 'Thấp' : 'Còn',
        style: TextStyle(
          color: isLow ? Colors.orange.shade800 : Colors.green.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F7FA),
      appBar: AppBar(
        title: const Text('Tồn kho & HSD'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.list, color: Colors.black87),
            tooltip: 'Danh sách lô hàng',
            onPressed: () => Navigator.pushNamed(context, '/inventory/batch-lots'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _loadProducts(),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 40),
                        const Icon(Icons.error_outline, size: 50, color: Colors.red),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Lỗi: $_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                          ),
                        ),
                        Center(
                              child: ElevatedButton.icon(
                                onPressed: () => _loadProducts(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tải lại'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                            ),
                          ),
                        )
                      ],
                    )
                  : (_products.isEmpty)
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 60),
                            Icon(Icons.inventory_2_outlined,
                                size: 72, color: AppTheme.primary.withOpacity(.15)),
                            const SizedBox(height: 18),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24.0),
                              child: Text(
                                'Không có sản phẩm nào sắp hết hoặc có lô sắp hết hạn.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _loadProducts(),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Tải lại'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Fallback: show all active products if no low-stock found
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      await _loadProducts();
                                    },
                                    icon: const Icon(Icons.list_alt),
                                    label: const Text('Hiện tất cả sản phẩm'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade800,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final p = _products[index] as Map<String, dynamic>;
                            final name = p['name'] ?? '---';
                            final currentStock = p['currentStock'] ?? 0;
                            final hasBatchInfo = p.containsKey('batchesRemaining');
                            final int? batchesRemaining = hasBatchInfo ? (p['batchesRemaining'] as int? ?? 0) : null;
                            final minStock = p['minStock'] ?? 0;
                            final reason = p['reason'] ?? '';
                            final img = p['imageUrl'];
                            // If we don't have batch info, don't assume 0 — only use currentStock comparison.
                            final isLow = (currentStock <= minStock) || (hasBatchInfo && (batchesRemaining! < minStock));

                            return GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/inventory/batches',
                                  arguments: {
                                    'productId': p['_id'],
                                    'productName': name,
                                  },
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // IMAGE
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: img != null
                                            ? Image.network(
                                                img,
                                                width: 70,
                                                height: 70,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  width: 70,
                                                  height: 70,
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(Icons.image_not_supported),
                                                ),
                                              )
                                            : Container(
                                                width: 70,
                                                height: 70,
                                                color: Colors.grey.shade200,
                                                child: const Icon(Icons.photo, size: 30),
                                              ),
                                      ),
                                      const SizedBox(width: 12),

                                      // PRODUCT INFO
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                _statusTag(isLow),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tồn kho: $currentStock  •  Lô còn: ${batchesRemaining != null ? batchesRemaining : '—'}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              reason.isNotEmpty
                                                  ? 'Nguyên nhân: $reason'
                                                  : isLow
                                                      ? 'Trạng thái: Sắp hết'
                                                      : 'Trạng thái: Bình thường',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isLow
                                                    ? Colors.orange.shade800
                                                    : Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // ACTION BUTTONS
                                      Column(
                                        children: [
                                          // Refresh product details
                                          IconButton(
                                            icon: const Icon(Icons.refresh, size: 18),
                                            color: AppTheme.primary,
                                            onPressed: () async {
                                              try {
                                                final prod = await ApiService.instance
                                                    .getProductById(p['_id']);

                                                if (!mounted) return;

                                                setState(() {
                                                  _products[index] = {
                                                    ...p,
                                                    'currentStock':
                                                        prod['currentStock'] ?? p['currentStock'],
                                                    'minStock': prod['minStock'] ?? p['minStock'],
                                                    'imageUrl': prod['imageUrl'] ?? p['imageUrl'],
                                                  };
                                                });
                                              } catch (e) {
                                                if (!mounted) return;
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Không thể tải sản phẩm: ${e.toString()}',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),

                                          // Recompute stock on server from batch lots
                                          IconButton(
                                            icon: const Icon(Icons.sync_alt, size: 18),
                                            color: Colors.green.shade700,
                                            tooltip: 'Đồng bộ tồn',
                                            onPressed: () async {
                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                              final sb = ScaffoldMessenger.of(context);
                                              try {
                                                // show a transient progress indicator
                                                sb.showSnackBar(const SnackBar(
                                                  content: Text('Đang đồng bộ...'),
                                                  duration: Duration(seconds: 60),
                                                ));

                                                await ApiService.instance.recomputeProduct(p['_id']);

                                                // re-fetch product to refresh UI
                                                final prod = await ApiService.instance.getProductById(p['_id']);
                                                if (!mounted) return;
                                                setState(() {
                                                  _products[index] = {
                                                    ...p,
                                                    'currentStock':
                                                        prod['currentStock'] ?? p['currentStock'],
                                                    'minStock': prod['minStock'] ?? p['minStock'],
                                                    'imageUrl': prod['imageUrl'] ?? p['imageUrl'],
                                                  };
                                                });

                                                sb.hideCurrentSnackBar();
                                                sb.showSnackBar(const SnackBar(
                                                  content: Text('Đã đồng bộ tồn kho'),
                                                  backgroundColor: Colors.green,
                                                ));
                                              } catch (e) {
                                                sb.hideCurrentSnackBar();
                                                sb.showSnackBar(SnackBar(
                                                  content: Text('Đồng bộ thất bại: ${e.toString()}'),
                                                  backgroundColor: Colors.red,
                                                ));
                                              }
                                            },
                                          ),
                                          const Icon(Icons.chevron_right,
                                              color: Colors.grey, size: 22),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
