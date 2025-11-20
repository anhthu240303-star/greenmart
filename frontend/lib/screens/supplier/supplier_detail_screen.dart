import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/supplier.dart';
import '../../services/api_service.dart';

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({Key? key}) : super(key: key);

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  bool _isLoading = true;
  Supplier? _supplier;
  Map<String, dynamic>? _stats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)!.settings.arguments as String?;
    if (id != null) _load(id);
  }

  Future<void> _load(String id) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.instance.getSupplierById(id);
      _supplier = Supplier.fromJson(data);
      try {
        _stats = await ApiService.instance.getSupplierStatistics(id);
      } catch (_) {
        _stats = null;
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Chi tiết nhà cung cấp'),
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _supplier == null
                ? const Center(child: Text('Không tìm thấy nhà cung cấp'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Header Card
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 32, color: AppTheme.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _supplier!.name,
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _supplier!.code,
                                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _supplier!.isActive ? Colors.green.shade50 : Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _supplier!.isActive ? 'Hoạt động' : 'Ngừng',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _supplier!.isActive ? Colors.green.shade700 : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Thông tin liên hệ
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('THÔNG TIN LIÊN HỆ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                            const SizedBox(height: 12),
                            if (_supplier!.contactPerson != null) ...[
                              _buildInfoRow(Icons.person, 'Người liên hệ', _supplier!.contactPerson!),
                              const SizedBox(height: 8),
                            ],
                            _buildInfoRow(Icons.phone, 'Số điện thoại', _supplier!.phone ?? '-'),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.email_outlined, 'Email', _supplier!.email ?? '-'),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Địa chỉ
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('ĐỊA CHỈ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                            const SizedBox(height: 12),
                            _buildInfoRow(Icons.location_on_outlined, 'Địa chỉ đầy đủ', _supplier!.fullAddress),
                          ]),
                        ),
                      ),

                      // Thông tin thuế & ngân hàng
                      if (_supplier!.taxCode != null || _supplier!.bankName != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('THÔNG TIN THUẾ & NGÂN HÀNG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                              const SizedBox(height: 12),
                              if (_supplier!.taxCode != null) ...[
                                _buildInfoRow(Icons.receipt_long_outlined, 'Mã số thuế', _supplier!.taxCode!),
                                if (_supplier!.bankName != null) const SizedBox(height: 8),
                              ],
                              if (_supplier!.bankName != null) _buildInfoRow(Icons.account_balance_outlined, 'Ngân hàng', _supplier!.bankName!),
                              if (_supplier!.accountNumber != null) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.credit_card_outlined, 'Số tài khoản', _supplier!.accountNumber!),
                              ],
                              if (_supplier!.accountName != null) ...[
                                const SizedBox(height: 8),
                                _buildInfoRow(Icons.person_outline, 'Chủ tài khoản', _supplier!.accountName!),
                              ],
                            ]),
                          ),
                        ),
                      ],

                      // Thống kê
                      if (_stats != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('THỐNG KÊ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                              const SizedBox(height: 12),
                              // 'Tổng giao dịch' removed (feature deprecated)
                              _buildInfoRow(Icons.inventory, 'Tổng sản phẩm', '${_stats!['totalProducts'] ?? 0}'),
                              const SizedBox(height: 8),
                              _buildInfoRow(Icons.attach_money, 'Tổng giá trị', currency.format(_stats!['totalAmount'] ?? 0), highlight: true),
                            ]),
                          ),
                        ),
                      ],

                      // Thông tin khác
                      if (_supplier!.createdByName != null || _supplier!.createdAt != null) ...[
                        const SizedBox(height: 16),
                        Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('THÔNG TIN KHÁC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                              const SizedBox(height: 12),
                              if (_supplier!.createdByName != null) _buildInfoRow(Icons.person_add, 'Người tạo', _supplier!.createdByName!),
                              if (_supplier!.createdByName != null && _supplier!.createdAt != null) const SizedBox(height: 8),
                              if (_supplier!.createdAt != null) _buildInfoRow(Icons.calendar_today, 'Ngày tạo', dateFormat.format(_supplier!.createdAt!)),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 16 : 14,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: highlight ? AppTheme.primary : Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
