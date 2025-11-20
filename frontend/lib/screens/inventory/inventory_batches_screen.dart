import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../config/theme.dart';

class InventoryBatchesScreen extends StatefulWidget {
  const InventoryBatchesScreen({Key? key}) : super(key: key);

  @override
  State<InventoryBatchesScreen> createState() => _InventoryBatchesScreenState();
}

class _InventoryBatchesScreenState extends State<InventoryBatchesScreen> {
  bool _loading = true;
  String? _error;
  List<dynamic> _batches = [];
  int _page = 1;
  int _limit = 20;
  int _totalPages = 1;
  String _search = '';
  bool _filterExpired = false;
  bool _filterNearExpiry = false;
  bool _filterLowStock = false;
  int _nearExpiryDays = 30;
  DateTime? _receivedFrom;
  DateTime? _receivedTo;
  String? _filterProductId;
  List<dynamic> _productsForFilter = [];
  bool _onlyRemainingPositive = false;

  @override
  void initState() {
    super.initState();
    _loadBatches();
  }

  Future<void> _loadBatches({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final Map<String, dynamic> qp = {
        'page': page,
        'limit': _limit,
      };
      if (_search.isNotEmpty) qp['search'] = _search;
      if (_filterExpired) qp['expired'] = 'true';
      if (_filterNearExpiry) qp['nearExpiry'] = 'true';
      if (_filterNearExpiry) qp['nearExpiryDays'] = _nearExpiryDays;
      if (_filterLowStock) qp['lowStock'] = 'true';
      if (_filterProductId != null) qp['productId'] = _filterProductId;
      if (_receivedFrom != null) qp['receivedFrom'] = _receivedFrom!.toIso8601String();
      if (_receivedTo != null) qp['receivedTo'] = _receivedTo!.toIso8601String();
      if (_onlyRemainingPositive) qp['onlyRemaining'] = 'true';

      final resp = await ApiService.instance.getBatchLotsPaginated(query: qp);
      final items = resp['items'] as List<dynamic>? ?? [];
      final pagination = resp['pagination'] as Map<String, dynamic>? ?? {};
      setState(() {
        _batches = items;
        _page = pagination['page'] as int? ?? page;
        final total = pagination['total'] as int? ?? items.length;
        _totalPages = (total / _limit).ceil();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Tìm theo tên sản phẩm, mã lô hoặc mã phiếu',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => _search = v,
                  onSubmitted: (_) => _loadBatches(page: 1),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Bộ lọc nâng cao',
                onPressed: () async {
                  await _openFilterSheet();
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Choice chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const SizedBox(width: 4),
                ChoiceChip(
                  label: const Text('Hết hạn'),
                  avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                  selected: _filterExpired,
                  selectedColor: Colors.red.shade100,
                  onSelected: (v) {
                    setState(() => _filterExpired = v);
                    _loadBatches(page: 1);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Sắp hết hạn ($_nearExpiryDays ngày)'),
                  avatar: const Icon(Icons.schedule, size: 18),
                  selected: _filterNearExpiry,
                  selectedColor: Colors.orange.shade100,
                  onSelected: (v) {
                    setState(() => _filterNearExpiry = v);
                    _loadBatches(page: 1);
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Sắp hết hàng'),
                  avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                  selected: _filterLowStock,
                  selectedColor: Colors.amber.shade100,
                  onSelected: (v) {
                    setState(() => _filterLowStock = v);
                    _loadBatches(page: 1);
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Active filters summary
          _buildActiveFiltersSummary(),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersSummary() {
    final List<Widget> chips = [];
    if (_filterExpired) chips.add(const Chip(label: Text('Hết hạn')));
    if (_filterNearExpiry) chips.add(Chip(label: Text('Sắp hết: $_nearExpiryDays ngày')));
    if (_filterLowStock) chips.add(const Chip(label: Text('Sắp hết hàng')));
    if (_filterProductId != null) chips.add(const Chip(label: Text('Theo sản phẩm')));
    if (_receivedFrom != null || _receivedTo != null) {
      final from = _receivedFrom != null ? _receivedFrom!.toLocal().toString().split(' ')[0] : '';
      final to = _receivedTo != null ? _receivedTo!.toLocal().toString().split(' ')[0] : '';
      chips.add(Chip(label: Text('Ngày nhập: $from → $to')));
    }
    if (_onlyRemainingPositive) chips.add(const Chip(label: Text('Chỉ lô còn > 0')));

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: chips.map((c) => Padding(padding: const EdgeInsets.only(right: 6.0), child: c)).toList()),
    );
  }

  Widget _buildItem(Map<String, dynamic> b) {
    final product = b['product'] as Map<String, dynamic>?;
    final supplier = b['supplier'] as Map<String, dynamic>?;
    final stockIn = b['stockIn'] as Map<String, dynamic>?;
    final expiry = b['expiryDate'];
    final received = b['receivedDate'];

    String expiryText = '-';
    String receivedText = '-';
    if (expiry != null) {
      final d = DateTime.tryParse(expiry.toString());
      if (d != null) expiryText = d.toLocal().toString().split(' ')[0];
    }
    if (received != null) {
      final d = DateTime.tryParse(received.toString());
      if (d != null) receivedText = d.toLocal().toString().split(' ')[0];
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: () {
          Navigator.pushNamed(context, '/inventory/batch', arguments: b);
        },
        leading: () {
          String? imgUrl;
          if (product != null && product['imageUrl'] is String && (product['imageUrl'] as String).isNotEmpty) {
            imgUrl = product['imageUrl'] as String;
          } else if (product != null && product['images'] is List && (product['images'] as List).isNotEmpty) {
            final imgs = product['images'] as List<dynamic>;
            final primary = imgs.firstWhere((x) => x is Map && (x['isPrimary'] == true), orElse: () => null);
            final chosen = primary ?? imgs.first;
            if (chosen is Map && chosen['url'] is String) imgUrl = chosen['url'] as String;
          } else if (product != null && product['image'] is String && (product['image'] as String).isNotEmpty) {
            imgUrl = product['image'] as String;
          }

          if (imgUrl != null) {
            return ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(imgUrl, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width:56, height:56, color: Colors.grey.shade200)));
          }
          return Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.photo, color: Colors.white54));
        }(),
        title: Text('${product != null ? product['name'] ?? '---' : '---'}  •  Lô: ${b['batchNumber'] ?? '---'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text('Còn: ${b['remainingQuantity'] ?? 0}  •  Nhập: ${b['initialQuantity'] ?? 0}  •  Giá vốn: ${b['costPrice'] ?? '-'}'),
            const SizedBox(height: 4),
            Text('HSD: $expiryText  •  NCC: ${supplier != null ? supplier['name'] ?? '-' : '-'}  •  Phiếu: ${stockIn != null ? stockIn['code'] ?? '-' : '-'}  •  Ngày nhập: $receivedText'),
            // Debug: show resolved image URL if available (debug builds only)
            if (kDebugMode) ...[
              const SizedBox(height: 6),
              Builder(builder: (_) {
                String? debugImg;
                try {
                  if (product != null && product['imageUrl'] is String && (product['imageUrl'] as String).isNotEmpty) {
                    debugImg = product['imageUrl'] as String;
                  } else if (product != null && product['images'] is List && (product['images'] as List).isNotEmpty) {
                    final imgs = product['images'] as List<dynamic>;
                    final primary = imgs.firstWhere((x) => x is Map && (x['isPrimary'] == true), orElse: () => null);
                    final chosen = primary ?? imgs.first;
                    if (chosen is Map && chosen['url'] is String) debugImg = chosen['url'] as String;
                  } else if (product != null && product['image'] is String && (product['image'] as String).isNotEmpty) {
                    debugImg = product['image'] as String;
                  }
                } catch (_) {}
                return Text('debug image: ${debugImg ?? '—'}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
              })
            ],
          ],
        ),
        trailing: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    // load products for selector lazily
    try {
      if (_productsForFilter.isEmpty) {
        final resp = await ApiService.instance.getProductsPaginated(query: {'page': 1, 'limit': 200});
        _productsForFilter = resp['items'] as List<dynamic>? ?? [];
      }
    } catch (_) {
      // ignore product load failure for now
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String? tmpProduct = _filterProductId;
        DateTime? tmpFrom = _receivedFrom;
        DateTime? tmpTo = _receivedTo;
        int tmpNearDays = _nearExpiryDays;
        bool tmpOnlyRemaining = _onlyRemainingPositive;

        return StatefulBuilder(builder: (c, setStateModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bộ lọc nâng cao', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // product selector
                  DropdownButtonFormField<String?>(
                    value: tmpProduct,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tất cả sản phẩm')),
                      ..._productsForFilter.map((p) {
                        final map = p as Map<String, dynamic>;
                        return DropdownMenuItem(value: map['_id'] as String?, child: Text(map['name'] ?? ''));
                      }).toList()
                    ],
                    onChanged: (v) => setStateModal(() => tmpProduct = v),
                    decoration: const InputDecoration(labelText: 'Sản phẩm'),
                  ),
                  const SizedBox(height: 12),

                  // date range picker
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: c,
                            firstDate: DateTime(2020),
                            // prevent selecting future dates in filter
                            lastDate: DateTime.now(),
                            initialDateRange: (tmpFrom != null && tmpTo != null) ? DateTimeRange(start: tmpFrom!, end: tmpTo!) : null,
                          );
                          if (picked != null) setStateModal(() { tmpFrom = picked.start; tmpTo = picked.end; });
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(tmpFrom != null && tmpTo != null ? '${tmpFrom!.toLocal().toString().split(' ')[0]} → ${tmpTo!.toLocal().toString().split(' ')[0]}' : 'Chọn khoảng ngày nhập'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade100, foregroundColor: Colors.black87),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),

                  // near expiry slider
                  Text('Sắp hết trong (ngày): $tmpNearDays'),
                  Slider(value: tmpNearDays.toDouble(), min: 7, max: 90, divisions: 83, label: '$tmpNearDays', onChanged: (v) => setStateModal(() => tmpNearDays = v.round())),

                  Row(children: [
                    Checkbox(value: tmpOnlyRemaining, onChanged: (v) => setStateModal(() => tmpOnlyRemaining = v ?? false)),
                    const SizedBox(width: 6),
                    const Expanded(child: Text('Chỉ lô còn > 0')),
                  ]),

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () {
                        tmpProduct = null; tmpFrom = null; tmpTo = null; tmpNearDays = 30; tmpOnlyRemaining = false;
                        setState(() {});
                      }, child: const Text('Xóa')), 
                      const SizedBox(width: 12),
                      ElevatedButton(onPressed: () async {
                        // validate date range
                        if (tmpFrom != null && tmpTo != null) {
                          if (tmpFrom!.isAfter(tmpTo!)) {
                            await showDialog(context: c, builder: (d) => AlertDialog(title: const Text('Lỗi ngày'), content: const Text('Ngày bắt đầu (fromDate) phải nhỏ hơn hoặc bằng ngày kết thúc (toDate).\nKhông cho phép fromDate > toDate.\nKhi thay đổi một trường thì validate lại cả hai.'), actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Đóng'))]));
                            return;
                          }
                          final today = DateTime.now();
                          if (tmpFrom!.isAfter(DateTime(today.year, today.month, today.day)) || tmpTo!.isAfter(DateTime(today.year, today.month, today.day))) {
                            await showDialog(context: c, builder: (d) => AlertDialog(title: const Text('Lỗi ngày'), content: const Text('Ngày bắt đầu và kết thúc không được lớn hơn ngày hiện tại.'), actions: [TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Đóng'))]));
                            return;
                          }
                        }

                        // apply
                        setState(() {
                          _filterProductId = tmpProduct;
                          _receivedFrom = tmpFrom;
                          _receivedTo = tmpTo;
                          _nearExpiryDays = tmpNearDays;
                          _onlyRemainingPositive = tmpOnlyRemaining;
                        });
                        Navigator.of(c).pop();
                        _loadBatches(page: 1);
                      }, child: const Text('Áp dụng')),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách lô hàng'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
        elevation: 1,
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Debug: show first product JSON',
              icon: const Icon(Icons.bug_report, color: Colors.black54),
              onPressed: () {
                if (_batches.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có lô hàng để debug')));
                  return;
                }
                final first = _batches.first as Map<String, dynamic>;
                final prod = first['product'];
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Product JSON'),
                    content: SingleChildScrollView(child: Text(const JsonEncoder.withIndent('  ').convert(prod ?? {}))),
                    actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Đóng'))],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('Lỗi: $_error'))
                      : _batches.isEmpty
                          ? Center(child: Text('Không tìm thấy lô hàng'))
                          : ListView.builder(
                              itemCount: _batches.length,
                              itemBuilder: (context, index) {
                                final b = _batches[index] as Map<String, dynamic>;
                                return _buildItem(b);
                              },
                            ),
            ),
            // pagination controls
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _page > 1 ? () => _loadBatches(page: _page - 1) : null,
                    child: const Text('Trước'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Text('Trang $_page / $_totalPages'),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _page < _totalPages ? () => _loadBatches(page: _page + 1) : null,
                    child: const Text('Sau'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
