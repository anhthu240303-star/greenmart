import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/stock_out.dart';
import '../../services/api_service.dart';

class StockOutListScreen extends StatefulWidget {
  const StockOutListScreen({Key? key}) : super(key: key);

  @override
  State<StockOutListScreen> createState() => _StockOutListScreenState();
}

class _StockOutListScreenState extends State<StockOutListScreen> with SingleTickerProviderStateMixin {
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final _searchController = TextEditingController();
  int _selectedTabIndex = 0;

  bool _isLoading = true;
  List<StockOutModel> _items = [];
  List<StockOutModel> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    // Defer loading until after first frame so navigation stays responsive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Add a short timeout so UI doesn't appear frozen when backend is down
      final list = await ApiService.instance.getStockOuts().timeout(const Duration(seconds: 6));
      _items = list.map((e) => StockOutModel.fromJson(e as Map<String, dynamic>)).toList();
      _filterByStatus();
    } on TimeoutException catch (_) {
      // swallow timeout to avoid blocking UI; keep UI responsive
      if (kDebugMode) print('[StockOutList] timeout while loading stock-outs');
    } catch (e) {
      // swallow errors silently in production to avoid blocking UX
      if (kDebugMode) print('[StockOutList] load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterByStatus() {
    final statusMap = ['all', 'pending', 'completed', 'cancelled'];
    final selectedStatus = statusMap[_selectedTabIndex];
    setState(() {
      if (selectedStatus == 'all') {
        _filteredItems = List<StockOutModel>.from(_items);
      } else {
        _filteredItems = _items.where((item) => item.status == selectedStatus).toList();
      }
    });
  }

  void _searchItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filterByStatus();
      } else {
        final q = query.toLowerCase();
        _filteredItems = _items.where((item) {
          final code = item.code.toLowerCase();
          final dest = item.destination.toLowerCase();
          return code.contains(q) || dest.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: _selectedTabIndex,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Phiếu xuất kho'),
        bottom: TabBar(
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
            _filterByStatus();
          },
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Chờ duyệt'),
            Tab(text: 'Hoàn thành'),
            Tab(text: 'Đã hủy'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/stock-outs/create'),
        icon: const Icon(Icons.add),
        label: const Text('Tạo phiếu'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo mã phiếu hoặc nơi đến...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchItems('');
                        },
                      )
                    : null,
              ),
              onChanged: _searchItems,
            ),
          ),
          Expanded(
            child: SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _filteredItems.isEmpty
                          ? ListView(children: const [Padding(padding: EdgeInsets.all(24), child: Text('Không có phiếu xuất'))])
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppTheme.paddingMedium),
                              itemCount: _filteredItems.length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppTheme.paddingSmall),
                              itemBuilder: (context, i) {
                                final s = _filteredItems[i];
                                return Card(
                                  child: ListTile(
                                    title: Text(s.code, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text('${s.items.length} sản phẩm'),
                                    trailing: Text(_currencyFormat.format(s.totalAmount), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                    onTap: () => Navigator.pushNamed(context, '/stock-outs/detail', arguments: s.id),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
