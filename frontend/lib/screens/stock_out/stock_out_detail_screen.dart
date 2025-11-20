import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/stock_out.dart';
import '../../services/api_service.dart';

class StockOutDetailScreen extends StatefulWidget {
  const StockOutDetailScreen({Key? key}) : super(key: key);

  @override
  State<StockOutDetailScreen> createState() => _StockOutDetailScreenState();
}

class _StockOutDetailScreenState extends State<StockOutDetailScreen> {
  bool _isLoading = true;
  StockOutModel? _stockOut;
  Map<String, dynamic>? _stockOutRaw;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)!.settings.arguments as String?;
    if (id != null) _load(id);
  }

  Future<void> _load(String id) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.instance.getStockOutById(id);
      // Normalize response and try to find the actual stock-out object.
      Map<String, dynamic> map = Map<String, dynamic>.from(data as Map);

      Map<String, dynamic>? extractCandidate(Map<String, dynamic> m) {
        // If this map already looks like a stock-out (has items or status or code), return it
        if (m.containsKey('items') || m.containsKey('status') || m.containsKey('code') || m.containsKey('totalAmount')) return m;
        // common wrappers
        for (final k in ['data', 'stockOut', 'stock_out', 'stockout', 'result', 'payload']) {
          if (m.containsKey(k) && m[k] is Map) {
            final inner = Map<String, dynamic>.from(m[k] as Map);
            if (inner.containsKey('items') || inner.containsKey('status') || inner.containsKey('code')) return inner;
          }
        }
        // sometimes API returns { data: { stockOut: { ... } } }
        if (m.containsKey('data') && m['data'] is Map) {
          final d = Map<String, dynamic>.from(m['data'] as Map);
          for (final k in ['stockOut', 'stock_out', 'stockout']) {
            if (d.containsKey(k) && d[k] is Map) return Map<String, dynamic>.from(d[k] as Map);
          }
        }
        return null;
      }

      final found = extractCandidate(map) ?? extractCandidate(map.cast<String, dynamic>() ) ;
      if (found != null) {
        _stockOutRaw = found;
      } else {
        // fallback: use the whole map
        _stockOutRaw = Map<String, dynamic>.from(map);
      }
      _stockOut = StockOutModel.fromJson(_stockOutRaw!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve() async {
    if (_stockOut == null) return;
    try {
      await ApiService.instance.approveStockOut(_stockOut!.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã duyệt'), backgroundColor: AppTheme.success));
      _load(_stockOut!.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Future<void> _cancel() async {
    if (_stockOut == null) return;
    try {
      await ApiService.instance.cancelStockOut(_stockOut!.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy'), backgroundColor: AppTheme.success));
      _load(_stockOut!.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final raw = _stockOutRaw ?? <String, dynamic>{};

    String _rawString(List<String> keys) {
      for (final k in keys) {
        if (raw.containsKey(k) && raw[k] != null && raw[k].toString().isNotEmpty) return raw[k].toString();
      }
      return '';
    }

    List<Map<String, dynamic>> _rawItems() {
      final candidates = ['items', 'lineItems', 'products', 'itemsList', 'entries'];
      for (final k in candidates) {
        if (raw.containsKey(k) && raw[k] is List) {
          try {
            return (raw[k] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          } catch (_) {}
        }
      }
      // fallback to model items if raw absent
      try {
        return _stockOut?.items.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      } catch (_) {
        return [];
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết phiếu xuất')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _stockOut == null
                ? const Center(child: Text('Không tìm thấy phiếu xuất'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.paddingMedium),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_stockOut!.code.isNotEmpty ? _stockOut!.code : _rawString(['code','reference','_id']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Nơi đến: ${_stockOut!.destination.isNotEmpty ? _stockOut!.destination : _rawString(['destination','to','location'])}'),
                            const SizedBox(height: 8),
                            Text('Tổng: ${currency.format(_stockOut!.totalAmount)}'),
                            const SizedBox(height: 8),
                            Text('Trạng thái: ${_stockOut!.status}'),
                            const SizedBox(height: 8),
                            if (_stockOutRaw != null) ...[
                              Text('Người tạo: ${_rawString(['createdByName','createdBy','createdBy.name'])}'),
                              const SizedBox(height: 4),
                              Text('Ngày tạo: ${_rawString(['createdAt','created_at','created'])}'),
                              const SizedBox(height: 4),
                              Text('Ghi chú: ${_rawString(['note','notes','description'])}'),
                            ],
                          ]),
                        ),
                      ),
                      const SizedBox(height: AppTheme.paddingMedium),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(AppTheme.paddingMedium),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Sản phẩm', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ..._rawItems().map((it) {
                              final name = (it['product'] is Map) ? (it['product']['name'] ?? it['name']) : (it['name'] ?? it['productName'] ?? 'Sản phẩm');
                              final qty = it['quantity'] ?? it['qty'] ?? it['amount'] ?? 0;
                              final unitPrice = it['unitPrice'] ?? it['price'] ?? it['cost'] ?? 0;
                              final batchNumber = it['batchNumber'] ?? (it['batch'] is Map ? it['batch']['batchNumber'] : it['batch'] ?? '') ?? '';
                              final nsx = it['batch'] is Map ? (it['batch']['manufacturedAt'] ?? it['batch']['nsx'] ?? it['batch']['manufactureDate']) : null;
                              final hsd = it['batch'] is Map ? (it['batch']['expiryDate'] ?? it['batch']['hsd'] ?? it['batch']['expiry']) : null;
                              return ListTile(
                                title: Text(name.toString()),
                                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('Số lượng: $qty'),
                                  if ((batchNumber ?? '').toString().isNotEmpty) Text('Lô: ${batchNumber.toString()}'),
                                  if (nsx != null) Text('NSX: ${nsx.toString()}'),
                                  if (hsd != null) Text('HSD: ${hsd.toString()}'),
                                  Text('Giá: ${currency.format((double.tryParse(unitPrice.toString()) ?? 0))}'),
                                ]),
                              );
                            }),
                          ]),
                        ),
                      ),
                      const SizedBox(height: AppTheme.paddingMedium),
                      if (_stockOut!.status == 'pending') Row(children: [
                        Expanded(child: OutlinedButton(onPressed: _cancel, child: const Text('Hủy'), style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error, side: const BorderSide(color: AppTheme.error)))),
                        const SizedBox(width: AppTheme.paddingSmall),
                        Expanded(child: ElevatedButton(onPressed: _approve, child: const Text('Duyệt'))),
                      ])
                    ]),
                  ),
      ),
    );
  }
}
