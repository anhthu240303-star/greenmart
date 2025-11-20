import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({Key? key}) : super(key: key);

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen> {
  final List<String> _actions = [
    'create_stock_in',
    'approve_stock_in',
    'cancel_stock_in',
    'create_stock_out',
    'approve_stock_out',
    'cancel_stock_out',
    'change_selling_price',
    'create_product',
    'delete_product',
  ];

  final Map<String, String> _actionLabels = {
    'create_stock_in': 'Tạo phiếu nhập',
    'approve_stock_in': 'Duyệt phiếu nhập',
    'cancel_stock_in': 'Hủy phiếu nhập',
    'create_stock_out': 'Tạo phiếu xuất',
    'approve_stock_out': 'Duyệt phiếu xuất',
    'cancel_stock_out': 'Hủy phiếu xuất',
    'change_selling_price': 'Thay đổi giá bán',
    'create_product': 'Tạo sản phẩm',
    'delete_product': 'Xóa sản phẩm',
  };

  // kept mapping inline in code; this top-level map is no longer used

  String _selectedAction = '';
  String _userQuery = '';
  List<Map<String, dynamic>> _userOptions = [];

  // Increase limit to fetch a large portion of history (show "full" history).
  // If your dataset grows extremely large, consider server-side paging or an autocomplete filter.
  int _limit = 10000;
  bool _loading = false;
  List<dynamic> _items = [];
  // No pagination state when loading a large 'full' history

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadUserOptions();
  }

  Future<void> _loadUserOptions() async {
    try {
      final resp = await ApiService.instance.getUsers(query: {'page': '1', 'limit': '200'});
      final list = resp['users'] as List<dynamic>? ?? [];
      final raw = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      // Deduplicate users by id (stringified) to avoid duplicate DropdownMenuItem values
      final Map<String, Map<String, dynamic>> uniq = {};
      for (final u in raw) {
        final id = (u['_id'] ?? u['id'])?.toString() ?? '';
        final key = id.trim();
        if (key.isEmpty) continue; // skip items without an id
        if (!uniq.containsKey(key)) uniq[key] = u;
      }
      _userOptions = uniq.values.toList();
      if (mounted) setState(() {});
    } catch (_) {
      // ignore
    }
  }

  Future<void> _fetch({int page = 1}) async {
    setState(() {
      _loading = true;
    });
    try {
      final qp = <String, dynamic>{
        'page': page,
        'limit': _limit,
      };
      if (_selectedAction.isNotEmpty) qp['action'] = _selectedAction;
      if (_userQuery.isNotEmpty) qp['user'] = _userQuery;

      final res = await ApiService.instance.getActivityLogs(query: qp);
      setState(() {
        _items = res['items'] as List<dynamic>? ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      setState(() => _loading = false);
    }
  }

  // Dates removed for simplified filter UI

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử hoạt động'), backgroundColor: AppTheme.primary),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    // Simplified filters: only Action + User
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedAction,
                            items: [const DropdownMenuItem<String>(value: '', child: Text('Tất cả'))]
                              .followedBy(_actions.map((a) => DropdownMenuItem<String>(value: a, child: Text(_actionLabels[a] ?? a))))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedAction = v ?? ''),
                          decoration: const InputDecoration(labelText: 'Action'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _userQuery,
                          items: [const DropdownMenuItem<String>(value: '', child: Text('Tất cả'))]
                              .followedBy(_userOptions.map((u) => DropdownMenuItem<String>(value: (u['_id'] ?? u['id'])?.toString() ?? '', child: Text(u['fullName'] ?? u['username'] ?? u['email'] ?? ''))))
                              .toList(),
                          onChanged: (v) => setState(() => _userQuery = v ?? ''),
                          decoration: const InputDecoration(labelText: 'Người dùng'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _fetch(page: 1), child: const Text('Áp dụng')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () {
                        setState(() { _selectedAction = ''; _userQuery = ''; });
                        _fetch(page: 1);
                      }, child: const Text('Đặt lại')),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? const Center(child: Text('Không có bản ghi'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final a = _items[i] as Map<String, dynamic>;
                              final created = a['createdAt'] != null ? DateTime.tryParse(a['createdAt'].toString()) : null;
                              final ts = created != null ? df.format(created) : '';
                              final user = a['user'] is Map ? (a['user']['fullName'] ?? a['user']['email'] ?? a['user']['_id']) : (a['user']?.toString() ?? '');
                              final entityType = a['entityType'] ?? (a['meta'] is Map ? a['meta']['entityType'] : null);
                              final entityId = a['entityId'] ?? (a['meta'] is Map ? (a['meta']['entityId'] ?? a['meta']['id']) : null);

                              final Map<String, dynamic> meta = (a['meta'] is Map) ? Map<String, dynamic>.from(a['meta']) : {};
                              final actionCode = (a['action'] as String?) ?? '';
                              final actionLabel = (meta['actionLabel'] as String?) ?? (_actionLabels[actionCode] ?? actionCode);

                              // Robust entity label detection
                              final etRaw = (entityType?.toString().toLowerCase() ?? '');
                              String etLabel;
                              if (etRaw.contains('stockin') || etRaw.contains('stock_in')) {
                                etLabel = 'Phiếu nhập';
                              } else if (etRaw.contains('stockout') || etRaw.contains('stock_out')) {
                                etLabel = 'Phiếu xuất';
                              } else if (etRaw.contains('product')) {
                                etLabel = 'Sản phẩm';
                              } else if (etRaw.contains('user')) {
                                etLabel = 'Người dùng';
                              } else {
                                etLabel = entityType?.toString() ?? '';
                              }
                              final entityLine = (entityType != null && entityId != null) ? 'Đối tượng: $etLabel #${entityId.toString()}' : '';

                              return ListTile(
                                leading: const Icon(Icons.history, color: Colors.grey),
                                title: Text(actionLabel),
                                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  // description (if any)
                                  if ((a['description']?.toString() ?? '').isNotEmpty) Text(a['description']?.toString() ?? ''),
                                  if (entityLine.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(entityLine, style: const TextStyle(fontSize: 12)),
                                  ],
                                  const SizedBox(height: 4),
                                  Text('Người: $user', style: const TextStyle(fontSize: 12)),
                                ]),
                                trailing: SizedBox(
                                  width: 120,
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Expanded(child: Text(ts, style: const TextStyle(fontSize: 12))),
                                    if (entityType != null && entityId != null) IconButton(icon: const Icon(Icons.open_in_new, size: 18), onPressed: () {
                                      String? route;
                                      final et = entityType.toString().toLowerCase();
                                      if (et.contains('stockin') || et.contains('stock_in')) route = '/stock-ins/detail';
                                      if (et.contains('stockout') || et.contains('stock_out')) route = '/stock-outs/detail';
                                      if (route != null) Navigator.pushNamed(context, route, arguments: entityId.toString());
                                    }),
                                  ]),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
