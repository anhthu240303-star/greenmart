import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({Key? key}) : super(key: key);

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _user;
  List<dynamic> _activities = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    if (args != null) {
      final map = args as Map<String, dynamic>;
      final id = map['_id']?.toString() ?? map['id']?.toString();
      if (id != null) _loadUser(id);
    }
  }

  Future<void> _loadUser(String id) async {
    setState(() => _isLoading = true);
    try {
      final resp = await ApiService.instance.getUserById(id);
      final acts = resp['activities'] as List<dynamic>? ?? [];
      acts.sort((a, b) {
        final da = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      setState(() {
        _user = resp;
        _activities = acts;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActive() async {
    if (_user == null) return;
    final id = _user!['_id']?.toString() ?? _user!['id']?.toString();
    if (id == null) return;
    try {
      if (_user!['isActive'] == true) {
        await ApiService.instance.deleteUser(id);
      } else {
        await ApiService.instance.activateUser(id);
      }
      await _loadUser(id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  Future<void> _resetPassword() async {
    if (_user == null) return;
    final id = _user!['_id']?.toString() ?? _user!['id']?.toString();
    if (id == null) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset mật khẩu'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Mật khẩu mới'),
          obscureText: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (ok != true) return;
    final newPwd = controller.text;
    if (newPwd.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu phải >=6 ký tự')),
      );
      return;
    }
    try {
      await ApiService.instance.resetUserPassword(id, newPwd);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset mật khẩu thành công')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }

  Widget _buildUserInfoTile(String label, String? value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? '',
              style: TextStyle(
                fontSize: 15,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 1,
        title: const Text('Chi tiết người dùng'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _user == null
                  ? const Center(child: Text('Không tìm thấy'))
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Card thông tin người dùng ---
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 32,
                                        backgroundColor: Colors.green.shade100,
                                        child: const Icon(Icons.person, size: 40, color: Colors.green),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _user!['fullName'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              _user!['email'] ?? '',
                                              style: const TextStyle(color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Chip(
                                        label: Text(
                                          _user!['isActive'] == true ? 'Đang hoạt động' : 'Đã vô hiệu hóa',
                                          style: TextStyle(
                                            color: _user!['isActive'] == true
                                                ? Colors.green.shade800
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                        backgroundColor: _user!['isActive'] == true
                                            ? Colors.green.shade50
                                            : Colors.red.shade50,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 10),
                                  _buildUserInfoTile('Tên đăng nhập:', _user!['username']),
                                  _buildUserInfoTile('Số điện thoại:', _user!['phone']),
                                  _buildUserInfoTile('Quyền:', _user!['role']),
                                  _buildUserInfoTile('Phê duyệt - Quản lý:',
                                      _user!['managerApproved'] == true ? 'Đã phê duyệt' : 'Chưa'),
                                  _buildUserInfoTile('Phê duyệt - Admin:',
                                      _user!['adminApproved'] == true ? 'Đã phê duyệt' : 'Chưa'),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // --- Các nút hành động ---
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    foregroundColor: Colors.red.shade700,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _toggleActive,
                                  icon: const Icon(Icons.block),
                                  label: Text(
                                    (_user!['isActive'] == true)
                                        ? 'Vô hiệu hóa'
                                        : 'Phê duyệt',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade50,
                                    foregroundColor: Colors.blue.shade700,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _resetPassword,
                                  icon: const Icon(Icons.key),
                                  label: const Text('Reset mật khẩu'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade50,
                                    foregroundColor: Colors.green.shade700,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    final res = await Navigator.pushNamed(
                                        context, '/users/edit',
                                        arguments: _user);
                                    if (res == true) {
                                      final id = _user!['_id']?.toString() ??
                                          _user!['id']?.toString();
                                      if (id != null) _loadUser(id);
                                    }
                                  },
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Chỉnh sửa'),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // --- Lịch sử hoạt động ---
                          const Text(
                            'Lịch sử hoạt động',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _activities.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.white,
                                  ),
                                  child: const Center(
                                    child: Text('Không có hoạt động'),
                                  ),
                                )
                              : Card(
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _activities.take(50).length,
                                    separatorBuilder: (_, __) => const Divider(height: 1),
                                    itemBuilder: (context, i) {
                                      final a = _activities[i];
                                      final at = DateTime.tryParse(
                                              a['createdAt']?.toString() ?? '') ??
                                          DateTime.now();
                                        // Try to detect referenced entity to enable "Open" action
                                        final entityType = a['entityType'] ?? (a['details'] is Map ? a['details']['entityType'] : null);
                                        final entityId = a['entityId'] ??
                                            (a['details'] is Map
                                                ? (a['details']['entityId'] ?? a['details']['id'] ?? a['details']['_id'])
                                                : null);

                                        String? routeToOpen;
                                        if (entityType != null) {
                                          final et = entityType.toString().toLowerCase();
                                          if (et.contains('stockin') || et.contains('stock_in')) routeToOpen = '/stock-ins/detail';
                                          if (et.contains('stockout') || et.contains('stock_out')) routeToOpen = '/stock-outs/detail';
                                        } else if ((a['action'] ?? '').toString().toLowerCase().contains('stock_in')) {
                                          routeToOpen = '/stock-ins/detail';
                                        } else if ((a['action'] ?? '').toString().toLowerCase().contains('stock_out')) {
                                          routeToOpen = '/stock-outs/detail';
                                        }

                                        return ListTile(
                                          dense: true,
                                          leading: const Icon(Icons.history, color: Colors.grey),
                                          title: Text(a['action'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
                                          subtitle: Text(a['details']?.toString() ?? ''),
                                          trailing: SizedBox(
                                            width: 120,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '${at.day}/${at.month}/${at.year} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                                if (routeToOpen != null && entityId != null) ...[
                                                  const SizedBox(width: 6),
                                                  IconButton(
                                                    icon: const Icon(Icons.open_in_new, size: 18),
                                                    tooltip: 'Mở phiếu',
                                                    onPressed: () {
                                                      try {
                                                        Navigator.pushNamed(context, routeToOpen!, arguments: entityId.toString());
                                                      } catch (e) {
                                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể mở: ${e.toString()}')));
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        );
                                    },
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
