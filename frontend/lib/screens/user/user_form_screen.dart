import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({Key? key}) : super(key: key);

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  String _role = 'warehouse_staff';
  bool _isSaving = false;
  bool _isEdit = false;
  String? _editUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args != null && !_isEdit) {
      _isEdit = true;
      if (args is String) {
        _editUserId = args;
      } else if (args is Map<String, dynamic>) {
        _editUserId = args['_id']?.toString() ?? args['id']?.toString();
      } else {
        _editUserId = args.toString();
      }
      if (_editUserId != null) _loadUserDetail();
    }
  }

  Future<void> _loadUserDetail() async {
    try {
      final data = await ApiService.instance.getUserById(_editUserId!);
      final map = data as Map<String, dynamic>;
      setState(() {
        _usernameCtrl.text = map['username'] ?? '';
        _emailCtrl.text = map['email'] ?? '';
        _fullNameCtrl.text = map['fullName'] ?? '';
        _phoneCtrl.text = map['phone'] ?? '';
        _role = map['role'] ?? 'warehouse_staff';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải người dùng: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final payload = {
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'fullName': _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': _role,
      };
      if (!_isEdit) payload['password'] = _passwordCtrl.text.trim();

      if (_isEdit) {
        await ApiService.instance.updateUser(_editUserId!, payload);
      } else {
        await ApiService.instance.createUser(payload);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Chỉnh sửa người dùng' : 'Tạo người dùng mới',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _isEdit ? 'Cập nhật thông tin' : 'Nhập thông tin người dùng',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildInput(
                    controller: _usernameCtrl,
                    label: 'Tên đăng nhập',
                    icon: Icons.badge_outlined,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập tên đăng nhập' : null,
                  ),
                  _buildInput(
                    controller: _emailCtrl,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null,
                  ),
                  _buildInput(
                    controller: _fullNameCtrl,
                    label: 'Họ và tên',
                    icon: Icons.person_outline,
                  ),
                  _buildInput(
                    controller: _phoneCtrl,
                    label: 'Số điện thoại',
                    icon: Icons.phone_outlined,
                  ),
                  if (!_isEdit)
                    _buildInput(
                      controller: _passwordCtrl,
                      label: 'Mật khẩu',
                      icon: Icons.lock_outline,
                      obscureText: true,
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Mật khẩu tối thiểu 6 ký tự'
                          : null,
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: InputDecoration(
                      labelText: 'Quyền hạn',
                      prefixIcon: const Icon(Icons.security_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(value: 'admin', child: Text('Quản trị viên')),
                      DropdownMenuItem(
                          value: 'warehouse_manager', child: Text('Quản lý kho')),
                      DropdownMenuItem(
                          value: 'warehouse_staff', child: Text('Nhân viên kho')),
                    ],
                    onChanged: (v) => setState(() => _role = v ?? 'warehouse_staff'),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isEdit ? 'Lưu thay đổi' : 'Tạo người dùng',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 3,
                        shadowColor: AppTheme.primary.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppTheme.primary),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
