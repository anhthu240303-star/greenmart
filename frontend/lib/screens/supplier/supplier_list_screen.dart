import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/supplier.dart';
import '../../services/api_service.dart';
import 'supplier_form_screen.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({Key? key}) : super(key: key);

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  bool _isLoading = true;
  List<Supplier> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.instance.getSuppliers();
      _items = list.map((e) => Supplier.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi tải danh sách: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onAdd() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupplierFormScreen()),
    );
    if (res == true) await _load();
  }

  Future<void> _onEdit(Supplier s) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SupplierFormScreen(supplier: s)),
    );
    if (res == true) await _load();
  }

  void _showDetail(Supplier s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 36, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          s.code,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: s.isActive ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      s.isActive ? 'Hoạt động' : 'Ngừng',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: s.isActive ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('THÔNG TIN LIÊN HỆ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
              const SizedBox(height: 12),
              if (s.contactPerson != null) _buildDetailRow(Icons.person, 'Người liên hệ', s.contactPerson!),
              if (s.contactPerson != null) const SizedBox(height: 8),
              _buildDetailRow(Icons.phone, 'Số điện thoại', s.phone ?? '-'),
              const SizedBox(height: 8),
              _buildDetailRow(Icons.email_outlined, 'Email', s.email ?? '-'),
              const SizedBox(height: 20),
              const Text('ĐỊA CHỈ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
              const SizedBox(height: 12),
              _buildDetailRow(Icons.location_on_outlined, 'Địa chỉ đầy đủ', s.fullAddress),
              if (s.taxCode != null) ...[
                const SizedBox(height: 20),
                const Text('THÔNG TIN THUẾE & NGÂN HÀNG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.receipt_long_outlined, 'Mã số thuế', s.taxCode ?? '-'),
              ],
              if (s.bankName != null || s.accountNumber != null) ...[
                if (s.taxCode == null) const SizedBox(height: 20),
                if (s.taxCode == null) const Text('THÔNG TIN NGÂN HÀNG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                if (s.taxCode == null) const SizedBox(height: 12),
                if (s.taxCode != null) const SizedBox(height: 8),
                _buildDetailRow(Icons.account_balance_outlined, 'Ngân hàng', s.bankName ?? '-'),
                const SizedBox(height: 8),
                _buildDetailRow(Icons.credit_card_outlined, 'Số tài khoản', s.accountNumber ?? '-'),
                if (s.accountName != null) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.person_outline, 'Chủ tài khoản', s.accountName!),
                ],
              ],
              if (s.createdByName != null || s.createdAt != null) ...[
                const SizedBox(height: 20),
                const Text('THÔNG TIN KHÁC', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey)),
                const SizedBox(height: 12),
                if (s.createdByName != null) _buildDetailRow(Icons.person_add, 'Người tạo', s.createdByName!),
                if (s.createdByName != null && s.createdAt != null) const SizedBox(height: 8),
                if (s.createdAt != null) _buildDetailRow(Icons.calendar_today, 'Ngày tạo', _formatDate(s.createdAt!)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _onEdit(s);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Chỉnh sửa'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.grey.shade600, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  )),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Supplier s) {
    return GestureDetector(
      onTap: () => _showDetail(s),
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: s.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                child: Icon(Icons.local_shipping_outlined, color: s.isActive ? Colors.green : Colors.grey, size: 22),
              ),
              // transaction count badge removed
            ],
          ),
          title: Text(
            s.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                s.code,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (s.contactPerson != null) ...[
                const SizedBox(height: 2),
                Text(
                  s.contactPerson!,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
              if (s.phone != null) ...[
                const SizedBox(height: 2),
                Text(
                  s.phone!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.green),
            onPressed: () => _onEdit(s),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Nhà cung cấp',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.local_shipping_outlined,
                                      size: 72, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'Không có nhà cung cấp nào',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(AppTheme.paddingMedium),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.paddingSmall),
                        itemBuilder: (context, index) {
                          final s = _items[index];
                          return _buildCard(s);
                        },
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAdd,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm nhà cung cấp',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
