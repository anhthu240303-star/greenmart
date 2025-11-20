import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/stock_in.dart';
import '../../models/supplier.dart';
import '../../services/api_service.dart';
import '../../widgets/item_line_widget.dart';

// local alias for readability
typedef ProductMap = Map<String, dynamic>;

class StockInFormScreen extends StatefulWidget {
  final StockInModel? stockIn;
  const StockInFormScreen({Key? key, this.stockIn}) : super(key: key);

  @override
  State<StockInFormScreen> createState() => _StockInFormScreenState();
}

class _StockInFormScreenState extends State<StockInFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingSuppliers = true;
  List<Supplier> _suppliers = [];
  String? _selectedSupplierId;
  bool _isLoadingProducts = true;
  List<ProductMap> _products = [];
  final List<ItemLine> _items = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
    _loadProducts();
    // start with one empty item row
    _items.add(ItemLine());
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    try {
      final list = await ApiService.instance.getSuppliers();
      _suppliers = list.map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoadingSuppliers = false);
    }
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      // Request a larger page size so dropdown contains all products.
      // Backend supports `limit` query param (default 10), so set a high limit here.
      final list = await ApiService.instance.getProducts(query: {'page': 1, 'limit': 1000});
      // keep raw maps for dropdown and id lookup
      _products = List<Map<String, dynamic>>.from(list.map((e) => e as Map<String, dynamic>));
    } catch (e) {
      _products = [];
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final itemsPayload = _items.map((i) => i.toJson()).toList();
      final payload = {
        'supplier': _selectedSupplierId,
        'note': _noteCtrl.text.trim(),
        'items': itemsPayload,
      };
      if (widget.stockIn == null) {
        await ApiService.instance.createStockIn(payload);
      } else {
        await ApiService.instance.updateStockIn(widget.stockIn!.id, payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.stockIn != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Chỉnh sửa phiếu nhập' : 'Tạo phiếu nhập')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _isLoadingSuppliers
                  ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                  : DropdownButtonFormField<String>(
                      value: _selectedSupplierId,
                      decoration: const InputDecoration(labelText: 'Nhà cung cấp'),
                      items: _suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                      onChanged: (v) => setState(() => _selectedSupplierId = v),
                      validator: (v) => (v == null || v.isEmpty) ? 'Chọn nhà cung cấp' : null,
                    ),
              const SizedBox(height: AppTheme.paddingMedium),
              TextFormField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'Ghi chú'), maxLines: 3),
              const SizedBox(height: AppTheme.paddingMedium),
              _isLoadingProducts
                  ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                  : Column(children: [
                      const Align(alignment: Alignment.centerLeft, child: Text('Danh sách hàng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                      const SizedBox(height: 8),
                      ..._items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final line = entry.value;
                        return ItemLineWidget(
                          line: line,
                          products: _products,
                          onRemove: () {
                            if (_items.length > 1) {
                              setState(() => _items.removeAt(idx));
                            }
                          },
                          onChanged: (l) => setState(() {}),
                        );
                      }).toList(),
                      const SizedBox(height: 6),
                      Row(children: [
                        ElevatedButton.icon(onPressed: () => setState(() => _items.add(ItemLine())), icon: const Icon(Icons.add), label: const Text('Thêm hàng')),
                        const SizedBox(width: 12),
                        Expanded(child: Container()),
                        Text('Tổng: ${_items.fold<double>(0.0, (p, e) => p + e.total).toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ])
                    ]),
              const SizedBox(height: AppTheme.paddingLarge),
              SizedBox(height: 50, child: ElevatedButton(onPressed: _isSaving ? null : _save, child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : Text(isEdit ? 'Lưu' : 'Tạo'))),
            ]),
          ),
        ),
      ),
    );
  }
}
