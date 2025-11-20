import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/inventory_check.dart';
import '../../services/api_service.dart';

class InventoryCheckScreen extends StatefulWidget {
  const InventoryCheckScreen({Key? key}) : super(key: key);

  @override
  State<InventoryCheckScreen> createState() => _InventoryCheckScreenState();
}

class _InventoryCheckScreenState extends State<InventoryCheckScreen> {
  bool _isLoading = true;
  InventoryCheckModel? _check;
  Map<String, dynamic>? _checkRaw;
  bool _isCreate = false;
  final _titleCtrl = TextEditingController();
  List<Map<String, dynamic>> _itemsForCreate = [];
  bool _saving = false;
  Map<String, dynamic>? _currentUser;
  List<Map<String, dynamic>> _editableItems = [];
  bool _approving = false;
  List<dynamic> _users = [];
  List<dynamic> _categories = [];
  String? _selectedAssigneeId;
  String _scope = 'all'; // 'all', 'category' or 'product'
  String? _selectedCategoryId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)!.settings.arguments as String?;
    if (id != null) {
      _load(id);
    } else {
      // No id -> create mode
      if (!_isCreate) {
        _prepareCreate();
      }
    }
  }

  Future<void> _prepareCreate() async {
    setState(() {
      _isCreate = true;
      _isLoading = false;
    });
    try {
      // Fetch users (simple defensive parsing)
      try {
        final uResp = await ApiService.instance.getUsers(query: {'limit': 100});
        List<dynamic> users = [];
        if (uResp is Map && uResp['items'] is List) users = uResp['items'] as List<dynamic>;
        else if (uResp is Map && uResp['data'] is List) users = uResp['data'] as List<dynamic>;
        else if (uResp is Map && uResp['users'] is List) users = uResp['users'] as List<dynamic>;
        _users = users;
      } catch (_) {
        _users = [];
      }

      // Fetch categories
      try {
        final cats = await ApiService.instance.getAllCategories();
        _categories = cats as List<dynamic>? ?? [];
      } catch (_) {
        _categories = [];
      }
      if (mounted) setState(() {});
    } catch (_) {
      // ignore
    }
  }

  Future<void> _loadProductsForScope({String? categoryId}) async {
    try {
      final qp = <String, dynamic>{'limit': 1000, 'page': 1};
      if (categoryId != null) qp['category'] = categoryId;
      final resp = await ApiService.instance.getProductsPaginated(query: qp);
      final items = resp['items'] as List<dynamic>? ?? [];
      // map to _itemsForCreate shape
      final list = items.map((p) {
        final prod = p as Map<String, dynamic>;
        return {
          'product': prod,
          'productId': prod['_id'],
          'systemQuantity': prod['currentStock'] ?? 0,
          'actualQuantity': 0,
          'batches': <dynamic>[],
          'batchId': null,
          'discrepancyReason': null,
        };
      }).toList();

      // Populate batches for each product (sequential to avoid too many parallel requests)
      for (var i = 0; i < list.length; i++) {
        final prod = list[i]['product'] as Map<String, dynamic>?;
        if (prod == null) continue;
        try {
          final batches = await ApiService.instance.getProductBatches(prod['_id'] as String);
          list[i]['batches'] = batches;
          // if batch list provides remainingQuantity, optionally update systemQuantity to first batch remaining
        } catch (_) {
          // ignore batch fetch error and leave empty
        }
      }

      setState(() {
        _itemsForCreate = List<Map<String, dynamic>>.from(list);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải sản phẩm theo phạm vi: $e')));
    }
  }

  void _onScopeChanged(String v) {
    setState(() {
      _scope = v;
      _selectedCategoryId = null;
      _itemsForCreate.clear();
    });
    if (v == 'all') {
      _loadProductsForScope();
    }
    // if 'category' we wait for category selection to load
  }

  Future<void> _load(String id) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.instance.getInventoryCheckById(id);
      // Normalize response similar to stock out detail
      Map<String, dynamic> map = Map<String, dynamic>.from(data as Map);

      // Common wrappers from backend: { check: {...} } or { inventoryCheck: {...} } or { data: { check: {...} } }
      if (map.containsKey('check') && map['check'] is Map) {
        map = Map<String, dynamic>.from(map['check'] as Map);
      } else if (map.containsKey('inventoryCheck') && map['inventoryCheck'] is Map) {
        map = Map<String, dynamic>.from(map['inventoryCheck'] as Map);
      } else if (map.containsKey('data') && map['data'] is Map) {
        final inner = map['data'] as Map<String, dynamic>;
        if (inner.containsKey('check') && inner['check'] is Map) {
          map = Map<String, dynamic>.from(inner['check'] as Map);
        } else if (inner.containsKey('inventoryCheck') && inner['inventoryCheck'] is Map) {
          map = Map<String, dynamic>.from(inner['inventoryCheck'] as Map);
        }
      } else if (map.length == 1) {
        // sometimes backend returns a single-key wrapper like { inventory_check: { ... } }
        final firstVal = map.values.first;
        if (firstVal is Map && (firstVal.containsKey('items') || firstVal.containsKey('status') || firstVal.containsKey('code'))) {
          map = Map<String, dynamic>.from(firstVal);
        }
      }

      _checkRaw = Map<String, dynamic>.from(map);
      _check = InventoryCheckModel.fromJson(_checkRaw!);
      // prepare editable items for in-progress perform mode
      try {
        _editableItems = (_checkRaw!['items'] as List<dynamic>? ?? []).map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return {
            'productId': (m['product'] is Map) ? (m['product']['_id'] ?? m['product']['id']) : (m['product'] ?? m['productId']),
            'actualQuantity': m['actualQuantity'] ?? 0,
            'systemQuantity': m['systemQuantity'] ?? (m['product'] is Map ? (m['product']['currentStock'] ?? 0) : 0),
            'notes': m['notes'] ?? '',
            'discrepancyReason': m['discrepancyReason'],
            'raw': m,
          };
        }).toList();
      } catch (_) {
        _editableItems = [];
      }
      _isCreate = false;
      // fetch current user to decide approve permissions
      try {
        final resp = await ApiService.instance.getCurrentUser();
        final Map<String, dynamic> respMap = Map<String, dynamic>.from(resp as Map);
        Map<String, dynamic> cu = {};
        if (respMap.containsKey('user') && respMap['user'] is Map) {
          cu = Map<String, dynamic>.from(respMap['user'] as Map);
        } else if (respMap.containsKey('data') && respMap['data'] is Map) {
          final d = respMap['data'] as Map;
          if (d.containsKey('user') && d['user'] is Map) cu = Map<String, dynamic>.from(d['user'] as Map);
          else cu = Map<String, dynamic>.from(d);
        } else {
          cu = Map<String, dynamic>.from(respMap);
        }
        if (!cu.containsKey('_id') && cu.containsKey('id')) cu['_id'] = cu['id'];
        _currentUser = cu;
      } catch (_) {
        _currentUser = null;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Initialize create mode
  void _initCreateMode() {
    _isCreate = true;
    _isLoading = false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_check == null) return;
    try {
      // Ensure latest edits saved before completing
      if (_editableItems.isNotEmpty) {
        await _saveItems();
      }
      await ApiService.instance.completeInventoryCheck(_check!.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hoàn tất'),
          backgroundColor: AppTheme.success,
        ),
      );
      _load(_check!.id);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Future<void> _approve() async {
    if (_check == null) return;
    setState(() => _approving = true);
    try {
      await ApiService.instance.approveInventoryCheck(_check!.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã duyệt phiếu'),
          backgroundColor: AppTheme.success,
        ),
      );
      await _load(_check!.id);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _saveItems() async {
    if (_check == null) return;
    try {
      final payload = {
        'items': _editableItems.map((it) => {
          'productId': it['productId'],
          'actualQuantity': it['actualQuantity'] ?? 0,
          'notes': it['notes'] ?? '',
          'discrepancyReason': it['discrepancyReason'],
        }).toList(),
      };
      await ApiService.instance.updateInventoryCheckItems(_check!.id, payload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lưu kết quả thành công'), backgroundColor: AppTheme.success));
      // reload to reflect server-side computed fields
      await _load(_check!.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lưu kết quả: $e')));
    }
  }

  String _rawString(List<String> keys) {
    final raw = _checkRaw ?? <String, dynamic>{};
    for (final k in keys) {
      if (raw.containsKey(k) && raw[k] != null && raw[k].toString().isNotEmpty) return raw[k].toString();
    }
    return '';
  }

  String _assigneeName() {
    final raw = _checkRaw;
    if (raw == null) return '';
    final a = raw['assignee'];
    if (a is Map) {
      if (a['fullName'] != null && a['fullName'].toString().isNotEmpty) return a['fullName'].toString();
      if (a['name'] != null && a['name'].toString().isNotEmpty) return a['name'].toString();
    }
    if (raw.containsKey('assigneeName') && raw['assigneeName'] != null && raw['assigneeName'].toString().isNotEmpty) return raw['assigneeName'].toString();
    return '';
  }

  String _creatorName() {
    final raw = _checkRaw;
    if (raw == null) return '';
    final c = raw['createdBy'];
    if (c is Map) {
      if (c['fullName'] != null && c['fullName'].toString().isNotEmpty) return c['fullName'].toString();
      if (c['name'] != null && c['name'].toString().isNotEmpty) return c['name'].toString();
    }
    if (raw.containsKey('createdByName') && raw['createdByName'] != null && raw['createdByName'].toString().isNotEmpty) return raw['createdByName'].toString();
    return '';
  }

  String _reasonLabel(dynamic code) {
    if (code == null) return '';
    switch (code.toString()) {
      case 'damaged':
        return 'Hư hỏng';
      case 'lost':
        return 'Mất';
      case 'mistake':
        return 'Nhầm';
      case 'expired':
        return 'Hết hạn';
      case 'other':
        return 'Khác';
      default:
        return code.toString();
    }
  }

  Future<void> _cancel() async {
    if (_check == null) return;
    try {
      await ApiService.instance.cancelInventoryCheck(_check!.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã hủy'),
          backgroundColor: AppTheme.success,
        ),
      );
      _load(_check!.id);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Widget _statusTag(String status) {
    Color bg;
    Color text;

    switch (status) {
      case 'in_progress':
        bg = Colors.orange.shade100;
        text = Colors.orange.shade700;
        break;
      case 'submitted':
        bg = Colors.orange.shade50;
        text = Colors.orange.shade800;
        break;
      case 'completed':
        bg = Colors.green.shade100;
        text = Colors.green.shade700;
        break;
      case 'approved':
        bg = Colors.blue.shade100;
        text = Colors.blue.shade700;
        break;
      case 'canceled':
        bg = Colors.red.shade100;
        text = Colors.red.shade700;
        break;
      default:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        // map internal status keys to Vietnamese labels
        ({
          'in_progress': 'Đang thực hiện',
          'submitted': 'Chờ duyệt',
          'completed': 'Đã hoàn tất',
          'approved': 'Đã duyệt',
          'cancelled': 'Đã hủy'
        }[status] ?? status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: text,
        ),
      ),
    );
  }

  Widget _buildItemCard(Map item) {
    final product = item["product"];
    final name = product?["name"] ?? item["name"] ?? "Sản phẩm";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        // ⭐ Dùng shadow trực tiếp để không bị lỗi AppTheme.cardShadow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey.shade200,
            ),
            clipBehavior: Clip.hardEdge,
            child: product?["image"] != null
                ? Image.network(product["image"], fit: BoxFit.cover)
                : const Icon(Icons.inventory_2, size: 28, color: Colors.grey),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                // Show system quantity only to admin / warehouse_manager
                Builder(builder: (context) {
                  final roles = (_currentUser != null && _currentUser!['roles'] is List) ? List<String>.from(_currentUser!['roles'] as List<dynamic>) : <String>[];
                  final showSystem = roles.contains('admin') || roles.contains('warehouse_manager');
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (showSystem) Text('Tồn hệ thống: ${item['systemQuantity'] ?? '-'}', style: TextStyle(color: Colors.grey.shade700)),
                      const SizedBox(height: 4),
                      Text(
                        'Số lượng thực tế: ${item["actualQuantity"] ?? "-"}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      if (showSystem) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Chênh lệch: ${((item['actualQuantity'] ?? 0) - (item['systemQuantity'] ?? 0))}', style: TextStyle(color: Colors.red.shade700)),
                        if (item['discrepancyReason'] != null && item['discrepancyReason'].toString().isNotEmpty)
                          Text('Lý do: ${_reasonLabel(item['discrepancyReason'])}', style: TextStyle(color: Colors.grey.shade700)),
                      ]),
                  ]);
                }),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // detect if called for create (no id arg)
    final id = ModalRoute.of(context)!.settings.arguments as String?;
    if (!_isLoading && id == null && !_isCreate && _check == null) {
      // enter create mode
      _initCreateMode();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiếu kiểm kê'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isCreate
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.paddingMedium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(labelText: 'Tiêu đề phiếu'),
                        ),
                        const SizedBox(height: 12),
                        // Assignee (who will perform the inventory)
                        DropdownButtonFormField<String?>(
                          value: _selectedAssigneeId,
                          decoration: const InputDecoration(labelText: 'Người thực hiện'),
                          items: _users.map((u) {
                            final m = u as Map<String, dynamic>;
                            return DropdownMenuItem(
                                value: m['_id'] as String?,
                                child: Text(m['fullName'] ?? 'Người dùng'));
                          }).toList(),
                          onChanged: (v) { setState(() { _selectedAssigneeId = v; }); },
                        ),
                        const SizedBox(height: 12),
                        // Scope selector
                        Row(children: [
                          Expanded(child: DropdownButtonFormField<String>(
                            value: _scope,
                            decoration: const InputDecoration(labelText: 'Phạm vi kiểm kê'),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Toàn kho')),
                              DropdownMenuItem(value: 'category', child: Text('Theo danh mục')),
                              DropdownMenuItem(value: 'product', child: Text('Theo sản phẩm')),
                            ],
                            onChanged: (v) { if (v != null) _onScopeChanged(v); },
                          )),
                        ]),
                        const SizedBox(height: 12),
                        if (_scope == 'category')
                          DropdownButtonFormField<String?>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(labelText: 'Chọn danh mục'),
                            items: _categories.map((c) {
                              final m = c as Map<String, dynamic>;
                              return DropdownMenuItem(value: m['_id'] as String?, child: Text(m['name'] ?? 'Danh mục'));
                            }).toList(),
                            onChanged: (v) async { setState(() { _selectedCategoryId = v; }); if (v != null) await _loadProductsForScope(categoryId: v); },
                          ),
                        const SizedBox(height: 12),
                        const Text('Sản phẩm'),
                        const SizedBox(height: 8),
                        ..._itemsForCreate.map((it) => _buildCreateItemCard(it)).toList(),
                        const SizedBox(height: 8),
                        Row(children: [
                          if (_scope == 'product') ElevatedButton.icon(onPressed: _addProductDialog, icon: const Icon(Icons.add), label: const Text('Thêm sản phẩm')),
                          const SizedBox(width: 12),
                          TextButton(onPressed: () { setState(() { _itemsForCreate.clear(); _titleCtrl.clear(); }); }, child: const Text('Xóa hết')),
                        ]),
                        const SizedBox(height: 20),
                        Row(children: [
                          Expanded(child: OutlinedButton(onPressed: () { Navigator.of(context).pop(); }, child: const Text('Hủy'))),
                          const SizedBox(width: 12),
                          Expanded(child: ElevatedButton(onPressed: _saving ? null : _saveCreate, child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu'))),
                        ])
                      ],
                    ),
                  )
                : _check == null
                    ? const Center(child: Text('Không tìm thấy phiếu kiểm kê'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(AppTheme.paddingMedium),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // HEADER CARD
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _check!.code,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [const Text('Trạng thái: ', style: TextStyle(fontWeight: FontWeight.w500)), _statusTag(_check!.status)]),
                                      const SizedBox(height: 6),
                                      Text('Người tạo: ${_creatorName()}'),
                                      const SizedBox(height: 4),
                                      Text('Người thực hiện: ${_assigneeName()}'),
                                    ])),
                                    // timestamps/status summary
                                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                      Text('Ngày tạo: ${_rawString(['createdAt'])}'),
                                      const SizedBox(height: 4),
                                      Text('Nộp: ${_rawString(['submittedAt','completedAt'])}'),
                                      const SizedBox(height: 4),
                                      Text('Duyệt: ${_rawString(['approvedAt'])}'),
                                    ]),
                                  ]),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),

                            const Text(
                              "Danh sách sản phẩm",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Items listing: if in_progress and user is assignee, show editable inputs (staff only see actualQuantity)
                            if (_check!.status == 'in_progress')
                              ...(() {
                                final roles = (_currentUser != null && _currentUser!['roles'] is List) ? List<String>.from(_currentUser!['roles'] as List<dynamic>) : <String>[];
                                final isAssignee = (_checkRaw != null && _checkRaw!['assignee'] != null && _currentUser != null && (_checkRaw!['assignee'] is Map ? (_checkRaw!['assignee']['_id'] == _currentUser!['_id']) : (_checkRaw!['assignee'].toString() == _currentUser!['_id'].toString())));
                                // Only the assigned staff can edit actual quantities
                                final canEdit = isAssignee;
                                final showSystem = roles.contains('admin') || roles.contains('warehouse_manager');
                                if (!canEdit) {
                                  return _check!.items.map((e) => _buildItemCard(e as Map)).toList();
                                }

                                // render editable cards backed by _editableItems
                                return _editableItems.map((it) {
                                  final prod = (it['raw'] != null && it['raw']['product'] is Map) ? it['raw']['product'] as Map<String, dynamic> : <String, dynamic>{'name': ''};
                                  final name = prod['name'] ?? it['raw']?['name'] ?? 'Sản phẩm';
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        )
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            if (showSystem)
                                              Text(
                                                'Tồn hệ thống: ${it['systemQuantity'] ?? '-'}',
                                                style: TextStyle(color: Colors.grey.shade700),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                initialValue: (it['actualQuantity'] ?? '').toString(),
                                                keyboardType: TextInputType.number,
                                                decoration: const InputDecoration(labelText: 'Số lượng thực tế'),
                                                onChanged: (v) {
                                                  final n = int.tryParse(v) ?? 0;
                                                  setState(() {
                                                    it['actualQuantity'] = n;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                              width: 160,
                                              child: DropdownButtonFormField<String?>(
                                                value: it['discrepancyReason'],
                                                decoration: const InputDecoration(labelText: 'Lý do'),
                                                items: const [
                                                  DropdownMenuItem(value: null, child: Text('Không')),
                                                  DropdownMenuItem(value: 'damaged', child: Text('Hư hỏng')),
                                                  DropdownMenuItem(value: 'lost', child: Text('Mất')),
                                                  DropdownMenuItem(value: 'mistake', child: Text('Nhầm')),
                                                  DropdownMenuItem(value: 'expired', child: Text('Hết hạn')),
                                                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                                                ],
                                                onChanged: (v) {
                                                  setState(() {
                                                    it['discrepancyReason'] = v;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              }())
                            else
                              ..._check!.items.map((e) => _buildItemCard(e as Map)).toList(),

                            const SizedBox(height: 20),
                              const SizedBox(height: 20),

                              // If in progress and current user can edit (assignee or admin/manager), show Save Results
                            if (_check!.status == 'in_progress')
                              Builder(builder: (context) {
                                final isAssignee = (_checkRaw != null && _checkRaw!['assignee'] != null && _currentUser != null && (_checkRaw!['assignee'] is Map ? (_checkRaw!['assignee']['_id'] == _currentUser!['_id']) : (_checkRaw!['assignee'].toString() == _currentUser!['_id'].toString())));
                                if (!isAssignee) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(children: [
                                    Expanded(child: OutlinedButton(onPressed: _saveItems, child: const Text('Lưu kết quả'))),
                                  ]),
                                );
                              }),

                              if (_check!.status == 'in_progress')
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _cancel,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        side: const BorderSide(
                                          color: AppTheme.error,
                                          width: 1.4,
                                        ),
                                        foregroundColor: AppTheme.error,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text("Hủy"),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _complete,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text(
                                        "Gửi kết quả",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            // Approve button for submitted checks (admin / warehouse_manager)
                            if (_check!.status == 'submitted')
                              Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: Builder(builder: (context) {
                                  final roles = (_currentUser != null && _currentUser!['roles'] is List) ? List<String>.from(_currentUser!['roles'] as List<dynamic>) : <String>[];
                                  final canApprove = roles.contains('admin') || roles.contains('warehouse_manager');
                                  if (!canApprove) return const SizedBox.shrink();
                                  return Row(children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _approving ? null : _approve,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: _approving
                                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Text('Duyệt phiếu', style: TextStyle(color: Colors.white)),
                                      ),
                                    ),
                                  ]);
                                }),
                              ),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildCreateItemCard(Map<String, dynamic> it) {
    final product = it['product'] as Map<String, dynamic>?;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(product?['name'] ?? 'Sản phẩm')),
          IconButton(onPressed: () { setState(() { _itemsForCreate.remove(it); }); }, icon: const Icon(Icons.delete, color: Colors.red)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Số lượng hệ thống: ${it['systemQuantity'] ?? '-'}')),
          const SizedBox(width: 8),
          SizedBox(width: 120, child: TextFormField(initialValue: (it['actualQuantity'] ?? '').toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Thực tế'), onChanged: (v) { final n = int.tryParse(v) ?? 0; setState(() { it['actualQuantity'] = n; }); })),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String?>(isExpanded: true, value: it['batchId'], items: (it['batches'] as List<dynamic>? ?? []).map((b) => DropdownMenuItem(value: b['_id'] as String, child: Text('${b['batchNumber']} (còn ${b['remainingQuantity']})', overflow: TextOverflow.ellipsis, maxLines: 1))).toList(), onChanged: (v) async { setState(() { it['batchId'] = v; }); if (v != null) { // update systemQuantity from selected batch
                final batches = it['batches'] as List<dynamic>? ?? [];
                final sel = batches.firstWhere((x) => x['_id'] == v, orElse: () => null);
                if (sel != null) setState(() { it['systemQuantity'] = sel['remainingQuantity']; });
              } }, decoration: const InputDecoration(labelText: 'Chọn lô (nếu có)'))),
          const SizedBox(width: 12),
          SizedBox(width: 160, child: DropdownButtonFormField<String?>(value: it['discrepancyReason'], decoration: const InputDecoration(labelText: 'Lý do'), items: const [
            DropdownMenuItem(value: null, child: Text('Không')), DropdownMenuItem(value: 'damaged', child: Text('Hư hỏng')), DropdownMenuItem(value: 'lost', child: Text('Mất')), DropdownMenuItem(value: 'mistake', child: Text('Nhầm')), DropdownMenuItem(value: 'expired', child: Text('Hết hạn')), DropdownMenuItem(value: 'other', child: Text('Khác'))
          ], onChanged: (v) { setState(() { it['discrepancyReason'] = v; }); })),
        ])
      ]),
    );
  }

  Future<void> _addProductDialog() async {
    // fetch products (first page)
    try {
      final data = await ApiService.instance.getProductsPaginated(query: {'limit': 50, 'page': 1});
      final items = data['items'] as List<dynamic>;
      await showModalBottomSheet(context: context, builder: (c) {
        return ListView.separated(padding: const EdgeInsets.all(12), itemBuilder: (context, index) {
          final p = items[index] as Map<String, dynamic>;
          return ListTile(title: Text(p['name'] ?? ''), subtitle: Text('Tồn: ${p['currentStock'] ?? 0}'), onTap: () async {
            // fetch batches for product
            final batches = await ApiService.instance.getProductBatches(p['_id'] as String);
            setState(() {
              _itemsForCreate.add({ 'product': p, 'productId': p['_id'], 'systemQuantity': p['currentStock'] ?? 0, 'actualQuantity': 0, 'batches': batches, 'batchId': null, 'discrepancyReason': null });
            });
            Navigator.of(c).pop();
          });
        }, separatorBuilder: (_,__) => const Divider(), itemCount: items.length);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải sản phẩm: $e')));
    }
  }

  Future<void> _saveCreate() async {
    if (_titleCtrl.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tiêu đề'))); return; }
    if (_itemsForCreate.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng thêm ít nhất 1 sản phẩm'))); return; }
    setState(() { _saving = true; });
    try {
      final payload = {
        'title': _titleCtrl.text.trim(),
        'products': _itemsForCreate.map((it) => {
          'productId': it['productId'],
          if (it['batchId'] != null) 'batchId': it['batchId'],
          'actualQuantity': it['actualQuantity'] ?? 0,
          'discrepancyReason': it['discrepancyReason'],
        }).toList(),
        // optional fields: assignee and scope/category
        if (_selectedAssigneeId != null) 'assigneeId': _selectedAssigneeId,
        'scope': _scope,
        if (_scope == 'category' && _selectedCategoryId != null) 'categoryId': _selectedCategoryId,
        'notes': ''
      };
      await ApiService.instance.createInventoryCheck(payload);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tạo phiếu thành công'), backgroundColor: AppTheme.success));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      setState(() { _saving = false; });
    }
  }
}
