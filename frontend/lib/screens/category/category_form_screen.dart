import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';

class CategoryFormScreen extends StatefulWidget {
  final Category? category;
  const CategoryFormScreen({Key? key, this.category}) : super(key: key);

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameCtrl.text = widget.category!.name;
      _descCtrl.text = widget.category!.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final payload = {'name': _nameCtrl.text.trim(), 'description': _descCtrl.text.trim()};
      if (widget.category == null) {
        await ApiService.instance.createCategory(payload);
      } else {
        await ApiService.instance.updateCategory(widget.category!.id, payload);
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
    final isEdit = widget.category != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Chỉnh sửa danh mục' : 'Thêm danh mục')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Tên danh mục'), validator: (v) => (v==null||v.trim().isEmpty)?'Vui lòng nhập tên':null),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Mô tả'), maxLines: 3),
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
