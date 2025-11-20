import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/stock_in.dart';

// StockIn list screen now uses StockInModel (from models/stock_in.dart)

class StockInListScreen extends StatefulWidget {
  const StockInListScreen({Key? key}) : super(key: key);

  @override
  State<StockInListScreen> createState() => _StockInListScreenState();
}

class _StockInListScreenState extends State<StockInListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  
  bool _isLoading = true;
  List<StockInModel> _stockIns = [];
  List<StockInModel> _filteredStockIns = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadStockIns();
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

  Future<void> _loadStockIns() async {
    setState(() => _isLoading = true);
    
    try {
      // fetch from API
        final resp = await ApiService.instance.getStockIns();
        final list = resp as List<dynamic>;
        _stockIns = list
          .map((e) => StockInModel.fromJson(e as Map<String, dynamic>))
          .toList();
      
      _filterByStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: ${e.toString()}'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterByStatus() {
    final statusMap = ['all', 'pending', 'completed', 'cancelled'];
    final selectedStatus = statusMap[_tabController.index];
    
    setState(() {
      if (selectedStatus == 'all') {
        _filteredStockIns = List<StockInModel>.from(_stockIns);
      } else {
        _filteredStockIns = _stockIns
            .where((item) => item.status == selectedStatus)
            .toList();
      }
    });
  }

  void _searchStockIns(String query) {
    setState(() {
      if (query.isEmpty) {
        _filterByStatus();
      } else {
        _filteredStockIns = _stockIns
            .where((item) =>
                item.code.toLowerCase().contains(query.toLowerCase()) ||
                item.supplierName.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phiếu nhập kho'),
        bottom: TabBar(
          controller: _tabController,
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
        onPressed: () {
          Navigator.pushNamed(context, '/stock-ins/create');
        },
        icon: const Icon(Icons.add),
        label: const Text('Tạo phiếu'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm theo mã phiếu hoặc nhà cung cấp...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchStockIns('');
                        },
                      )
                    : null,
              ),
              onChanged: _searchStockIns,
            ),
          ),
          
          // Stock in list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStockIns.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_outlined,
                              size: 64,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không có phiếu nhập',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadStockIns,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(AppTheme.paddingMedium),
                          itemCount: _filteredStockIns.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: AppTheme.paddingSmall),
                          itemBuilder: (context, index) {
                            final stockIn = _filteredStockIns[index];
                            return _buildStockInCard(stockIn);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockInCard(StockInModel stockIn) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/stock-ins/detail',
            arguments: stockIn.id,
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stockIn.code,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          stockIn.supplierName,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(stockIn.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusDisplayName(stockIn.status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(stockIn.status),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _dateFormat.format(stockIn.createdAt),
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${stockIn.items.length} sản phẩm',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Tổng tiền',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(stockIn.totalAmount),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (stockIn.status == 'pending') ...[
                const SizedBox(height: AppTheme.paddingMedium),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _confirmCancel(stockIn);
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Hủy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: const BorderSide(color: AppTheme.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.paddingSmall),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _confirmApprove(stockIn);
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Duyệt'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmApprove(StockInModel stockIn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận duyệt'),
        content: Text('Duyệt phiếu nhập "${stockIn.code}"?\n\nHành động này sẽ cập nhật số lượng tồn kho.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.instance.approveStockIn(stockIn.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã duyệt phiếu nhập'),
                    backgroundColor: AppTheme.success,
                  ),
                );
                _loadStockIns();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Duyệt thất bại: ${e.toString()}'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            child: const Text('Duyệt'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(StockInModel stockIn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận hủy'),
        content: Text('Hủy phiếu nhập "${stockIn.code}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ApiService.instance.cancelStockIn(stockIn.id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã hủy phiếu nhập'),
                    backgroundColor: AppTheme.success,
                  ),
                );
                // Optimistically update UI: mark item as cancelled so it appears in 'Đã hủy' tab
                setState(() {
                  final idx = _stockIns.indexWhere((s) => s.id == stockIn.id);
                  if (idx != -1) {
                    final old = _stockIns[idx];
                    _stockIns[idx] = StockInModel(
                      id: old.id,
                      code: old.code,
                      supplierId: old.supplierId,
                      supplierName: old.supplierName,
                      totalAmount: old.totalAmount,
                      status: 'cancelled',
                      items: old.items,
                      createdAt: old.createdAt,
                      importDate: old.importDate,
                      createdByName: old.createdByName,
                      approvedByName: old.approvedByName,
                      approvedAt: old.approvedAt,
                    );
                  }
                  _filterByStatus();
                });
                // Also refresh from server in background to ensure sync
                _loadStockIns();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Hủy thất bại: ${e.toString()}'),
                    backgroundColor: AppTheme.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Hủy phiếu'),
          ),
        ],
      ),
    );
  }

  String _statusDisplayName(String status) {
    switch (status) {
      case 'pending':
        return 'Chờ duyệt';
      case 'in_progress':
        return 'Đang xử lý';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }
}