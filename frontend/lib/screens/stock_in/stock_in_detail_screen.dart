import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/stock_in.dart';
import '../../services/api_service.dart';

class StockInDetailScreen extends StatefulWidget {
  const StockInDetailScreen({Key? key}) : super(key: key);

  @override
  State<StockInDetailScreen> createState() => _StockInDetailScreenState();
}

class _StockInDetailScreenState extends State<StockInDetailScreen> {
  bool _isLoading = true;
  StockInModel? _stockIn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = ModalRoute.of(context)!.settings.arguments as String?;
    if (id != null) _load(id);
  }

  Future<void> _load(String id) async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.instance.getStockInById(id);
      _stockIn = StockInModel.fromJson(data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approve() async {
    if (_stockIn == null) return;
    try {
      await ApiService.instance.approveStockIn(_stockIn!.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã duyệt'), backgroundColor: AppTheme.success));
      _load(_stockIn!.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Future<void> _cancel() async {
    if (_stockIn == null) return;
    try {
      await ApiService.instance.cancelStockIn(_stockIn!.id);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy'), backgroundColor: AppTheme.success));
      _load(_stockIn!.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Chi tiết phiếu nhập'),
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _stockIn == null
                ? const Center(child: Text('Không tìm thấy phiếu nhập'))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Card
                        _buildHeaderCard(dateFormat, currency),

                        const SizedBox(height: 16),

                        // Product List Card
                        _buildProductListCard(currency),

                        const SizedBox(height: 24),

                        // Action Buttons
                        if (_stockIn!.status == 'pending') 
                          _buildActionButtons(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeaderCard(DateFormat dateFormat, NumberFormat currency) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _stockIn!.code,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
              _buildStatusChip(_stockIn!.status),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(Icons.factory, 'Nhà cung cấp', _stockIn!.supplierName),
          const SizedBox(height: 8),
          if (_stockIn!.importDate != null) ...[
            _buildInfoRow(Icons.local_shipping, 'Ngày nhập hàng', dateFormat.format(_stockIn!.importDate!)),
            const SizedBox(height: 8),
          ],
          _buildInfoRow(Icons.person, 'Người tạo', _stockIn!.createdByName),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today, 'Ngày tạo phiếu', dateFormat.format(_stockIn!.createdAt)),
          if (_stockIn!.approvedByName != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.check_circle, 'Người duyệt', _stockIn!.approvedByName!),
          ],
          if (_stockIn!.approvedAt != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Thời gian duyệt', dateFormat.format(_stockIn!.approvedAt!)),
          ],
          const SizedBox(height: 8),
          _buildInfoRow(Icons.price_change, 'Tổng giá trị', currency.format(_stockIn!.totalAmount), highlight: true),
        ]),
      ),
    );
  }

  Widget _buildProductListCard(NumberFormat currency) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Danh sách sản phẩm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _stockIn!.items.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final item = _stockIn!.items[index];
              final productName = item['product']?['name'] ?? item['name'] ?? 'Sản phẩm';
              final quantity = item['quantity'] ?? 0;
              final unitPrice = (item['unitPrice'] ?? 0).toDouble();
              final totalPrice = (item['totalPrice'] ?? quantity * unitPrice).toDouble();
              final unit = item['product']?['unit'] ?? item['unit'] ?? 'Cái';
              // Thông tin lô hàng
              final batchNumber = item['batchNumber'] ?? '';
              final mfg = item['manufacturingDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item['manufacturingDate'])) : '';
              final exp = item['expiryDate'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item['expiryDate'])) : '';

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade200,
                    child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text('Số lượng: $quantity $unit  -  Đơn giá: ${currency.format(unitPrice)}',
                            style: TextStyle(fontSize: 15, color: Colors.grey[700])),
                        if (batchNumber.isNotEmpty || mfg.isNotEmpty || exp.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            if (batchNumber.isNotEmpty)
                              Text('Số lô: $batchNumber', style: const TextStyle(fontSize: 13, color: Colors.blue)),
                            if (mfg.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Text('NSX: $mfg', style: const TextStyle(fontSize: 13, color: Colors.green)),
                            ],
                            if (exp.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Text('HSD: $exp', style: const TextStyle(fontSize: 13, color: Colors.red)),
                            ],
                          ]),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    currency.format(totalPrice),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ],
              );
            },
          ),
        ]),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool highlight = false}) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label:',
            style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: highlight ? 18 : 15,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: highlight ? AppTheme.primary : Colors.black87,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _cancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Hủy', style: TextStyle(fontSize: 16)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _approve,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Duyệt', style: TextStyle(fontSize: 16, color: Colors.white)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'pending':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        label = 'Chờ duyệt';
        break;
      case 'completed':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        label = 'Hoàn thành';
        break;
      case 'cancelled':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        label = 'Đã hủy';
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
