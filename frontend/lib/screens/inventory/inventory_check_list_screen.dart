import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/inventory_check.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';

class InventoryCheckListScreen extends StatefulWidget {
  const InventoryCheckListScreen({Key? key}) : super(key: key);

  @override
  State<InventoryCheckListScreen> createState() =>
      _InventoryCheckListScreenState();
}

class _InventoryCheckListScreenState
    extends State<InventoryCheckListScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  bool _isLoading = true;
  List<InventoryCheckModel> _items = [];
  List<InventoryCheckModel> _filtered = [];
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Load current user first, then load checks (so server-side staff filter applies)
    _loadCurrentUser().then((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    _filterByStatus();
  }
  String? _search;
  String? _statusFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  Future<void> _loadCurrentUser() async {
    try {
      final data = await ApiService.instance.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = User.fromJson(data['user'] ?? data);
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final query = <String, dynamic>{};
      if (_search != null && _search!.isNotEmpty) query['search'] = _search;
      if (_statusFilter != null && _statusFilter!.isNotEmpty) query['status'] = _statusFilter;
      if (_startDate != null) query['startDate'] = _startDate!.toIso8601String();
      if (_endDate != null) query['endDate'] = _endDate!.toIso8601String();

      final list = await ApiService.instance.getInventoryChecks(query: query.isEmpty ? null : query);
      _items = list
          .map((e) => InventoryCheckModel.fromJson(e as Map<String, dynamic>))
          .toList();
      _filterByStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showFilterDialog() async {
    final searchCtrl = TextEditingController(text: _search ?? '');
    String? status = _statusFilter;
    DateTime? start = _startDate;
    DateTime? end = _endDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: searchCtrl, decoration: const InputDecoration(labelText: 'Tìm kiếm (mã/tên)')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Tất cả')),
                  DropdownMenuItem(value: 'in_progress', child: Text('Đang thực hiện')),
                  DropdownMenuItem(value: 'submitted', child: Text('Chờ duyệt')),
                  DropdownMenuItem(value: 'completed', child: Text('Hoàn tất')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Đã hủy')),
                ],
                onChanged: (v) => status = v,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextButton(onPressed: () async {
                  final picked = await showDatePicker(context: c, initialDate: start ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) start = picked;
                }, child: Text(start != null ? 'Từ: ${start!.toLocal().toIso8601String().substring(0,10)}' : 'Chọn ngày bắt đầu'))),
                const SizedBox(width: 8),
                Expanded(child: TextButton(onPressed: () async {
                  final picked = await showDatePicker(context: c, initialDate: end ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) end = picked;
                }, child: Text(end != null ? 'Đến: ${end!.toLocal().toIso8601String().substring(0,10)}' : 'Chọn ngày kết thúc'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                TextButton(onPressed: () {
                  // clear
                  searchCtrl.text = '';
                  status = '';
                  start = null;
                  end = null;
                  Navigator.of(c).pop();
                }, child: const Text('Xóa bộ lọc')),
                const Spacer(),
                ElevatedButton(onPressed: () {
                  _search = searchCtrl.text.trim().isEmpty ? null : searchCtrl.text.trim();
                  _statusFilter = (status == null || status == '') ? null : status;
                  _startDate = start;
                  _endDate = end;
                  Navigator.of(c).pop();
                  _load();
                }, child: const Text('Áp dụng')),
              ])
            ]),
          ),
        );
      }
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return Colors.orange;
      case 'submitted':
        return Colors.orangeAccent;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  void _filterByStatus() {
    final statusMap = ['all', 'submitted', 'completed', 'cancelled'];
    final selected = statusMap[_tabController.index];
    setState(() {
      if (selected == 'all') _filtered = List<InventoryCheckModel>.from(_items);
      else _filtered = _items.where((i) => i.status == selected).toList();
    });
  }

  void _searchItems(String q) {
    setState(() {
      _search = q.trim().isEmpty ? null : q.trim();
    });
    _load();
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return Icons.play_circle_fill_rounded;
      case 'submitted':
        return Icons.hourglass_bottom_rounded;
      case 'completed':
        return Icons.verified_rounded;
      case 'cancelled':
        return Icons.block_rounded;
      default:
        return Icons.pending_actions_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// ---------------- APP BAR ----------------
      appBar: AppBar(
        title: const Text('Phiếu Kiểm Kê', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [Tab(text: 'Tất cả'), Tab(text: 'Chờ duyệt'), Tab(text: 'Hoàn thành'), Tab(text: 'Đã hủy')],
        ),
        actions: [IconButton(onPressed: _showFilterDialog, icon: const Icon(Icons.filter_list))],
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4CAF50)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
      ),

      /// ---------------- BUTTON TẠO PHIẾU ----------------
      floatingActionButton: (_currentUser != null &&
              (_currentUser!.role == 'admin' ||
                  _currentUser!.role == 'warehouse_manager'))
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xff1A73E8),
              icon: const Icon(Icons.add, size: 28),
              label: const Text("Tạo phiếu",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              onPressed: () =>
                  Navigator.pushNamed(context, '/inventory-checks/create'),
            )
          : null,

      /// ---------------- BODY ----------------
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 4))
            : Column(children: [
                // search
                Padding(padding: const EdgeInsets.all(AppTheme.paddingMedium), child: TextField(controller: _searchController, decoration: InputDecoration(hintText: 'Tìm theo mã/tên...', prefixIcon: const Icon(Icons.search), suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _searchItems(''); }) : null), onChanged: _searchItems)),
                Expanded(child: RefreshIndicator(onRefresh: _load, child: _filtered.isEmpty ? ListView(children: const [Padding(padding: EdgeInsets.only(top: 180), child: Center(child: Text('Không có phiếu kiểm kê', style: TextStyle(fontSize: 18, color: Colors.grey))))]) : ListView.separated(padding: const EdgeInsets.all(16), separatorBuilder: (_, __) => const SizedBox(height: 16), itemCount: _filtered.length, itemBuilder: (context, index) {
                  final it = _filtered[index];
                          final color = _statusColor(it.status);

                          AnimationController anim = AnimationController(
                            vsync: this,
                            duration: const Duration(milliseconds: 450),
                          )..forward();

                          return FadeTransition(
                            opacity: CurvedAnimation(
                                parent: anim, curve: Curves.easeOut),
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: anim, curve: Curves.easeOut)),
                              child: GestureDetector(
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/inventory-checks/detail',
                                  arguments: it.id,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: Colors.white.withOpacity(0.95),
                                    border: Border.all(
                                        color: Colors.black.withOpacity(0.05)),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withOpacity(0.08),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      /// Icon trạng thái
                                      Container(
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(12),
                                        child: Icon(
                                          _statusIcon(it.status),
                                          size: 30,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      /// Nội dung
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              it.code,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                it.status.toUpperCase(),
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const Icon(Icons.chevron_right_rounded,
                                          size: 32, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },))),
              ]),
      ),
    );
  }
}
