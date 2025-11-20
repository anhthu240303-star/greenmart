import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;
  const ProductFormScreen({Key? key, this.product}) : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingCategories = true;
  List<Category> _categories = [];
  String? _selectedCategoryId;
  final ImagePicker _picker = ImagePicker();
  List<XFile> _pickedImages = [];
  List<Map<String, dynamic>> _existingImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameCtrl.text = widget.product!.name;
      _barcodeCtrl.text = widget.product!.barcode ?? '';
      _costCtrl.text = widget.product!.costPrice.toString();
      _priceCtrl.text = widget.product!.sellingPrice.toString();
      _unitCtrl.text = widget.product!.unit;
      _stockCtrl.text = widget.product!.currentStock.toString();
      _selectedCategoryId = widget.product!.categoryId;
    }
    _loadCategories();
    // If editing, load full product details (includes images)
    if (widget.product != null) {
      _loadProductDetails();
    }
  }

  Future<void> _loadProductDetails() async {
    try {
      final data = await ApiService.instance.getProductById(widget.product!.id);
      Map<String, dynamic> productData = {};
      if (data['product'] != null && data['product'] is Map<String, dynamic>) {
        productData = Map<String, dynamic>.from(data['product'] as Map);
      } else {
        productData = Map<String, dynamic>.from(data as Map);
      }

      // Update all controllers with latest data from server
      if (productData['name'] != null) _nameCtrl.text = productData['name'].toString();
      if (productData['barcode'] != null) _barcodeCtrl.text = productData['barcode'].toString();
      if (productData['costPrice'] != null) _costCtrl.text = productData['costPrice'].toString();
      if (productData['sellingPrice'] != null) _priceCtrl.text = productData['sellingPrice'].toString();
      if (productData['unit'] != null) _unitCtrl.text = productData['unit'].toString();
      if (productData['currentStock'] != null) _stockCtrl.text = productData['currentStock'].toString();
      
      final categoryId = productData['category'];
      if (categoryId != null) {
        if (categoryId is Map) {
          _selectedCategoryId = (categoryId['_id'] ?? categoryId['id'])?.toString();
        } else {
          _selectedCategoryId = categoryId.toString();
        }
      }

      final imgs = productData['images'];
      if (imgs is List) {
        _existingImages = imgs.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>)).toList();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải thông tin sản phẩm: ${e.toString()}')));
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    try {
      final list = await ApiService.instance.getAllCategories();
      _categories = list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      // If no category selected, pick first
      _selectedCategoryId ??= _categories.isNotEmpty ? _categories.first.id : null;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải danh mục: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _costCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final payload = {
        'name': _nameCtrl.text.trim(),
        'barcode': _barcodeCtrl.text.trim(),
        if (_selectedCategoryId != null) 'category': _selectedCategoryId,
        'costPrice': double.tryParse(_costCtrl.text) ?? 0,
        'sellingPrice': double.tryParse(_priceCtrl.text) ?? 0,
        'unit': _unitCtrl.text.trim(),
        'currentStock': int.tryParse(_stockCtrl.text) ?? 0,
      };

      print('=== SAVING PRODUCT ===');
      print('Is Edit: ${widget.product != null}');
      print('Payload: $payload');

      if (widget.product == null) {
        final created = await ApiService.instance.createProduct(payload);
        final id = created['_id'] ?? created['id'];
        if (_pickedImages.isNotEmpty && id != null) {
          // upload images
          final paths = _pickedImages.map((x) => x.path).toList();
          await ApiService.instance.uploadProductImages(id.toString(), paths);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo sản phẩm thành công')));
        }
      } else {
        print('Updating product ID: ${widget.product!.id}');
        await ApiService.instance.updateProduct(widget.product!.id, payload);
        if (_pickedImages.isNotEmpty) {
          final paths = _pickedImages.map((x) => x.path).toList();
          await ApiService.instance.uploadProductImages(widget.product!.id, paths);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật sản phẩm thành công')));
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      print('Error saving product: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Chỉnh sửa sản phẩm' : 'Thêm sản phẩm')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image picker & preview
                const Text('Ảnh sản phẩm', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    // Existing uploaded images (when editing)
                    ..._existingImages.map((img) {
                      final url = img['url'] ?? img['uri'] ?? '';
                      final imgId = img['_id']?.toString() ?? img['id']?.toString();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)),
                              child: url.isNotEmpty
                                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(url, width: 80, height: 80, fit: BoxFit.cover))
                                  : const SizedBox.shrink(),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      title: const Text('Xác nhận'),
                                      content: const Text('Xóa ảnh này?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
                                        ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  // Optimistic remove
                                  setState(() => _existingImages.removeWhere((e) => (e['_id']?.toString() ?? e['id']?.toString()) == imgId));
                                  try {
                                    await ApiService.instance.deleteProductImage(widget.product!.id, imgId ?? '');
                                  } catch (err) {
                                    // Rollback on failure
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xóa ảnh thất bại: ${err.toString()}')));
                                      _loadProductDetails();
                                    }
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    // Newly picked images
                    ..._pickedImages.map((x) => Padding(padding: const EdgeInsets.only(right: 8.0), child: Image.file(File(x.path), width: 80, height: 80, fit: BoxFit.cover))),

                    // Add button
                    GestureDetector(
                      onTap: () async {
                        final imgs = await _picker.pickMultiImage(imageQuality: 80);
                        if (imgs.isNotEmpty) {
                          setState(() => _pickedImages.addAll(imgs));
                        }
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey)),
                        child: const Center(child: Icon(Icons.add_a_photo)),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tên sản phẩm'), validator: (v) => (v==null||v.trim().isEmpty)?'Vui lòng nhập tên':null),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(controller: _barcodeCtrl, decoration: const InputDecoration(labelText: 'Mã vạch')),
                const SizedBox(height: AppTheme.paddingMedium),
                _isLoadingCategories
                    ? const SizedBox(height: 56, child: Center(child: CircularProgressIndicator()))
                    : DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(labelText: 'Danh mục'),
                        items: _categories
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCategoryId = v),
                        validator: (v) => (v == null || v.isEmpty) ? 'Vui lòng chọn danh mục' : null,
                      ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(controller: _costCtrl, decoration: const InputDecoration(labelText: 'Giá nhập'), keyboardType: TextInputType.number),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(controller: _priceCtrl, decoration: const InputDecoration(labelText: 'Giá bán'), keyboardType: TextInputType.number),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(controller: _unitCtrl, decoration: const InputDecoration(labelText: 'Đơn vị')),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(
                  controller: _stockCtrl,
                  decoration: const InputDecoration(labelText: 'Số lượng tồn kho'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Vui lòng nhập số lượng';
                    final n = int.tryParse(v);
                    if (n == null || n < 0) return 'Số lượng không hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: AppTheme.paddingLarge),
                SizedBox(height: 50, child: ElevatedButton(onPressed: _isSaving?null:_save, child: _isSaving?const CircularProgressIndicator(color: Colors.white):Text(isEdit?'Lưu':'Tạo'))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
