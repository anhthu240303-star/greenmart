import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({Key? key}) : super(key: key);

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  int _page = 1;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final data = await ApiService.instance.getCurrentUser();
      // backend returns { user: {...} } or user object
      final raw = data;
      final map = raw['user'] != null ? Map<String, dynamic>.from(raw['user'] as Map) : Map<String, dynamic>.from(raw as Map);
      _currentUser = User.fromJson(map);
      if (mounted) setState(() {});
    } catch (_) {
      // ignore
    }
  }

  Future<void> _showUserActivities(String userId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) {
        return FutureBuilder<Map<String, dynamic>>(
          future: ApiService.instance.getUserById(userId),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return SizedBox(height: 300, child: const Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError || snap.data == null) {
              return SizedBox(
                height: 200,
                child: Center(child: Text('Không thể tải hoạt động: ${snap.error}')),
              );
            }

            final data = snap.data!;
            final acts = (data['activities'] as List<dynamic>?) ?? [];

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.95,
              builder: (_, controller) => Column(
                children: [
                  const SizedBox(height: 8),
                  Container(width: 60, height: 6, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      const Text('Lịch sử hoạt động', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: acts.isEmpty
                        ? const Center(child: Text('Không có hoạt động'))
                        : ListView.separated(
                            controller: controller,
                            itemCount: acts.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final a = acts[i] as Map<String, dynamic>;
                              final created = a['createdAt'] != null ? DateTime.tryParse(a['createdAt'].toString()) : null;
                              final ts = created != null ? '${created.day}/${created.month}/${created.year} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}' : '';

                              final entityType = a['entityType'] ?? (a['details'] is Map ? a['details']['entityType'] : null);
                              final entityId = a['entityId'] ?? (a['details'] is Map ? (a['details']['entityId'] ?? a['details']['id'] ?? a['details']['_id']) : null);

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
                                leading: const Icon(Icons.history, color: Colors.grey),
                                title: Text(a['action'] ?? ''),
                                subtitle: Text(a['details']?.toString() ?? ''),
                                trailing: SizedBox(
                                  width: 120,
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Expanded(child: Text(ts, style: const TextStyle(fontSize: 12))),
                                    if (routeToOpen != null && entityId != null) IconButton(icon: const Icon(Icons.open_in_new, size: 18), onPressed: () {
                                      Navigator.pop(context);
                                      Navigator.pushNamed(this.context, routeToOpen!, arguments: entityId.toString());
                                    }),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final resp = await ApiService.instance
          .getUsers(query: {'page': _page.toString(), 'limit': '50'});
      final users = resp['users'] as List<dynamic>? ?? [];
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Vô hiệu hóa người dùng này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đồng ý')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.deleteUser(id);
      await _loadUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_outlined, color: Colors.white, size: 26),
            const SizedBox(width: 8),
            const Text(
              'Người dùng',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                color: Colors.white,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Thanh nút hành động ---
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/users/create')
                          .then((r) {
                        if (r == true) _loadUsers();
                      }),
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text(
                        'Tạo người dùng',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: _loadUsers,
                    child: const Icon(Icons.refresh_rounded, size: 22),
                  ),
                  const SizedBox(width: 8),
                  if (_currentUser != null && (_currentUser!.role == 'admin' || _currentUser!.role == 'warehouse_manager'))
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/activity-logs'),
                      icon: const Icon(Icons.timeline, size: 20),
                      label: const Text('Hoạt động'),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingLarge),

              // --- Danh sách người dùng ---
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _users.isEmpty
                        ? const Center(
                            child: Text(
                              'Chưa có người dùng nào',
                              style: TextStyle(
                                fontSize: 17,
                                color: Colors.black54,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _users.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final u = _users[index] as Map<String, dynamic>;
                              final name = u['fullName'] ?? u['username'] ?? 'Không tên';
                              final email = u['email'] ?? '';

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  leading: CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                                    child: const Icon(Icons.person_outline,
                                        color: AppTheme.primary, size: 26),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  subtitle: Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  trailing: SizedBox(
                                    width: 120,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Show activities button only for admin/manager
                                        if (_currentUser != null && (_currentUser!.role == 'admin' || _currentUser!.role == 'warehouse_manager'))
                                          IconButton(
                                            icon: const Icon(Icons.history, size: 20, color: Colors.grey),
                                            tooltip: 'Xem hoạt động',
                                            onPressed: () async {
                                              final id = u['_id']?.toString() ?? u['id']?.toString();
                                              if (id == null) return;
                                              await _showUserActivities(id);
                                            },
                                          ),
                                        PopupMenuButton<String>(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    onSelected: (v) async {
                                      if (v == 'edit') {
                                        final res = await Navigator.pushNamed(
                                            context, '/users/edit',
                                            arguments: u);
                                        if (res == true) _loadUsers();
                                      } else if (v == 'detail') {
                                        await Navigator.pushNamed(
                                            context, '/users/detail',
                                            arguments: u);
                                        _loadUsers();
                                      } else if (v == 'delete') {
                                        await _onDelete(u['_id']?.toString() ?? '');
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                          value: 'detail', child: Text('Chi tiết')),
                                      const PopupMenuItem(
                                          value: 'edit', child: Text('Chỉnh sửa')),
                                      const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Vô hiệu hóa')),
                                    ],
                                    icon: const Icon(Icons.more_vert_rounded),
                                  ),
                                  ],
                                ),
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
    );
  }
}
