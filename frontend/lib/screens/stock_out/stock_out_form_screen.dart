import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/stock_out.dart';
import '../../services/api_service.dart';
import '../../widgets/item_line_widget.dart';

typedef ProductMap = Map<String, dynamic>;

class StockOutFormScreen extends StatefulWidget {
  final StockOutModel? stockOut;
  const StockOutFormScreen({Key? key, this.stockOut}) : super(key: key);

  @override
  State<StockOutFormScreen> createState() => _StockOutFormScreenState();
}

class _StockOutFormScreenState extends State<StockOutFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _destCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingProducts = true;
  List<ProductMap> _products = [];
  final List<ItemLine> _items = [];
  String? _selectedType;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.stockOut != null) {
      // existing StockOutModel doesn't expose type/reason in the current model.
      // If editing is needed later, populate fields here from the raw API model.
      // TODO: populate items when editing
    }
    _items.add(ItemLine());
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoadingProducts = true);
    try {
      // Request a larger page size so dropdown contains all products (same as stock-in form)
      final list = await ApiService.instance.getProducts(query: {'page': 1, 'limit': 1000});
      // keep raw maps for dropdown and id lookup
      _products = List<Map<String, dynamic>>.from(list.map((e) => e as Map<String, dynamic>));
    } catch (e) {
      _products = [];
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  @override
  void dispose() {
    _destCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final itemsPayload = _items.map((i) => i.toJson()).toList();
      final payload = {
        'type': _selectedType,
        'reason': _reasonCtrl.text.trim(),
        'note': _noteCtrl.text.trim(),
        'items': itemsPayload,
      };
      if (widget.stockOut == null) {
        await ApiService.instance.createStockOut(payload);
      } else {
        await ApiService.instance.updateStockOut(widget.stockOut!.id, payload);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.stockOut != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Chỉnh sửa phiếu xuất' : 'Tạo phiếu xuất')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Loại phiếu'),
                items: const [
                  DropdownMenuItem(value: 'sale', child: Text('Bán hàng')),
                  DropdownMenuItem(value: 'internal_use', child: Text('Sử dụng nội bộ')),
                  DropdownMenuItem(value: 'damaged', child: Text('Hỏng')),
                  DropdownMenuItem(value: 'expired', child: Text('Hết hạn')),
                  DropdownMenuItem(value: 'return_to_supplier', child: Text('Trả NCC')),
                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                ],
                onChanged: (v) => setState(() => _selectedType = v),
                validator: (v) => (v == null || v.isEmpty) ? 'Chọn loại phiếu' : null,
              ),
              const SizedBox(height: AppTheme.paddingMedium),
              TextFormField(controller: _reasonCtrl, decoration: const InputDecoration(labelText: 'Lý do'), validator: (v) => (v==null||v.trim().isEmpty)?'Nhập lý do':null),
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
                            if (_items.length > 1) setState(() => _items.removeAt(idx));
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
              SizedBox(height: 50, child: ElevatedButton(onPressed: _isSaving?null:_save, child: _isSaving?const CircularProgressIndicator(color: Colors.white):Text(isEdit?'Lưu':'Tạo'))),
            ]),
          ),
        ),
      ),
    );
  }
}
