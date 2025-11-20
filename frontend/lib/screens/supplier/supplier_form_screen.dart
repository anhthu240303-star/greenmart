import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/supplier.dart';
import '../../services/api_service.dart';

class SupplierFormScreen extends StatefulWidget {
  final Supplier? supplier;
  const SupplierFormScreen({Key? key, this.supplier}) : super(key: key);

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _contactPersonCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _taxCodeCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _nameCtrl.text = widget.supplier!.name;
      _contactPersonCtrl.text = widget.supplier!.contactPerson ?? '';
      _phoneCtrl.text = widget.supplier!.phone ?? '';
      _emailCtrl.text = widget.supplier!.email ?? '';
      _streetCtrl.text = widget.supplier!.street ?? '';
      _districtCtrl.text = widget.supplier!.district ?? '';
      _cityCtrl.text = widget.supplier!.city ?? '';
      _countryCtrl.text = widget.supplier!.country ?? 'Việt Nam';
      _taxCodeCtrl.text = widget.supplier!.taxCode ?? '';
      _bankNameCtrl.text = widget.supplier!.bankName ?? '';
      _accountNumberCtrl.text = widget.supplier!.accountNumber ?? '';
      _accountNameCtrl.text = widget.supplier!.accountName ?? '';
    } else {
      _countryCtrl.text = 'Việt Nam';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _contactPersonCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _streetCtrl.dispose();
    _districtCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _taxCodeCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> payload = {
        'name': _nameCtrl.text.trim(),
        if (_contactPersonCtrl.text.trim().isNotEmpty) 'contactPerson': _contactPersonCtrl.text.trim(),
        if (_phoneCtrl.text.trim().isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.trim().isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_taxCodeCtrl.text.trim().isNotEmpty) 'taxCode': _taxCodeCtrl.text.trim(),
      };

      // Address object
      if (_streetCtrl.text.trim().isNotEmpty || _districtCtrl.text.trim().isNotEmpty || 
          _cityCtrl.text.trim().isNotEmpty || _countryCtrl.text.trim().isNotEmpty) {
        payload['address'] = {
          if (_streetCtrl.text.trim().isNotEmpty) 'street': _streetCtrl.text.trim(),
          if (_districtCtrl.text.trim().isNotEmpty) 'district': _districtCtrl.text.trim(),
          if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
          if (_countryCtrl.text.trim().isNotEmpty) 'country': _countryCtrl.text.trim(),
        };
      }

      // Bank account object
      if (_bankNameCtrl.text.trim().isNotEmpty || _accountNumberCtrl.text.trim().isNotEmpty || 
          _accountNameCtrl.text.trim().isNotEmpty) {
        payload['bankAccount'] = {
          if (_bankNameCtrl.text.trim().isNotEmpty) 'bankName': _bankNameCtrl.text.trim(),
          if (_accountNumberCtrl.text.trim().isNotEmpty) 'accountNumber': _accountNumberCtrl.text.trim(),
          if (_accountNameCtrl.text.trim().isNotEmpty) 'accountName': _accountNameCtrl.text.trim(),
        };
      }

      if (widget.supplier == null) {
        await ApiService.instance.createSupplier(payload);
      } else {
        await ApiService.instance.updateSupplier(widget.supplier!.id, payload);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey.shade700),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: Text(
          isEdit ? 'Chỉnh sửa nhà cung cấp' : 'Thêm nhà cung cấp',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thông tin cơ bản
                const Text('THÔNG TIN CƠ BẢN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDecoration('Tên nhà cung cấp *', Icons.storefront_outlined),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(
                  controller: _contactPersonCtrl,
                  decoration: _inputDecoration('Người liên hệ', Icons.person_outline),
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: _inputDecoration('Số điện thoại *', Icons.phone_outlined),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập số điện thoại' : null,
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: _inputDecoration('Email', Icons.email_outlined),
                  keyboardType: TextInputType.emailAddress,
                ),
                
                const SizedBox(height: 24),
                const Text('ĐỊA CHỈ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _streetCtrl,
                  decoration: _inputDecoration('Địa chỉ', Icons.location_on_outlined),
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _districtCtrl,
                        decoration: _inputDecoration('Quận/Huyện', Icons.map_outlined),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cityCtrl,
                        decoration: _inputDecoration('Tỉnh/Thành phố', Icons.location_city_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(
                  controller: _countryCtrl,
                  decoration: _inputDecoration('Quốc gia', Icons.public_outlined),
                ),

                const SizedBox(height: 24),
                const Text('THÔNG TIN THUẾ & NGÂN HÀNG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxCodeCtrl,
                  decoration: _inputDecoration('Mã số thuế', Icons.receipt_long_outlined),
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(
                  controller: _bankNameCtrl,
                  decoration: _inputDecoration('Tên ngân hàng', Icons.account_balance_outlined),
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(
                  controller: _accountNumberCtrl,
                  decoration: _inputDecoration('Số tài khoản', Icons.credit_card_outlined),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppTheme.paddingMedium),
                TextFormField(
                  controller: _accountNameCtrl,
                  decoration: _inputDecoration('Tên chủ tài khoản', Icons.person_outline),
                ),

                const SizedBox(height: AppTheme.paddingLarge),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isEdit ? 'Lưu thay đổi' : 'Tạo mới',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
