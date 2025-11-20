import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'batch_edit_screen.dart';
import '../../services/api_service.dart';
import '../../services/batch_history_service.dart';

class BatchDetailScreen extends StatefulWidget {
  const BatchDetailScreen({Key? key}) : super(key: key);

  @override
  State<BatchDetailScreen> createState() => _BatchDetailScreenState();
}

class _BatchDetailScreenState extends State<BatchDetailScreen> {
  Future<void> _showHistory(dynamic batchIdRaw) async {
    final batchId = batchIdRaw?.toString() ?? '';
    final entries = BatchHistoryService.getFor(batchId);
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có lịch sử thay đổi trong phiên này.')));
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: MediaQuery.of(ctx).viewInsets + const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(height: 4, width: 48, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              const Text('Lịch sử chỉnh sửa (phiên hiện tại)', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (context, idx) {
                    final e = entries[idx];
                    final ts = e['timestamp'] ?? '';
                    final payload = e['payload'] as Map<String, dynamic>? ?? {};
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: ListTile(
                        title: Text(ts),
                        subtitle: Text('Còn lại: ${payload['remainingQuantity'] ?? '-'} • Giá vốn: ${payload['costPrice'] ?? '-'}'),
                        trailing: TextButton(
                          child: const Text('Hoàn tác'),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                              title: const Text('Xác nhận hoàn tác'),
                              content: const Text('Bạn có chắc muốn hoàn tác về trạng thái này không?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Hủy')),
                                ElevatedButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Hoàn tác')),
                              ],
                            ));
                            if (confirm != true) return;

                            try {
                              // record current state into history before rollback
                              final argsMap = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
                              final current = Map<String, dynamic>.from(argsMap);
                              BatchHistoryService.add(batchId, current);
                              final resp = await ApiService.instance.updateBatchLot(batchId, payload);
                              // merge returned fields into current screen's batch args
                              setState(() {
                                resp.forEach((k, v) {
                                  // if args were passed in ModalRoute, we must update that map as well
                                  // get route args map and merge
                                  final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
                                  if (args != null) args[k] = v;
                                });
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hoàn tác thành công')));
                              Navigator.of(ctx).pop();
                            } catch (err) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hoàn tác thất bại: ${err.toString()}')));
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      }
    );
  }
  

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final b = args ?? {};
    final batchNumber = b['batchNumber'] ?? '—';
    final initialQuantity = b['initialQuantity'] ?? 0;
    final remainingQuantity = b['remainingQuantity'] ?? 0;
    final costPrice =
        b['costPrice'] != null ? (b['costPrice']).toString() : '—';
    final receivedDate = b['receivedDate'] != null
        ? b['receivedDate'].toString().split('T').first
        : '—';
    final expiryDate = b['expiryDate'] != null
        ? b['expiryDate'].toString().split('T').first
        : '—';
    final manufacturingDate = b['manufacturingDate'] != null
        ? b['manufacturingDate'].toString().split('T').first
        : '—';

    return Scaffold(
      /// ------------------- APP BAR -------------------
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Chi tiết lô $batchNumber',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary,
                // fallback: if primaryDark not defined, use slightly darker via opacity
                // but using only AppTheme.primary to stay compatible:
                AppTheme.primary.withOpacity(0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      /// ------------------- BODY -------------------
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            /// Card trên cùng (số lô + icon)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppTheme.cardBackground.withOpacity(0.98),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      color: AppTheme.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Mã lô hàng",
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          batchNumber,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 24),

            /// Card thông tin chi tiết
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: AppTheme.cardBackground,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  _infoRow(Icons.qr_code_rounded, "Số lượng nhập", "$initialQuantity"),
                  const SizedBox(height: 14),
                  _infoRow(Icons.inventory_rounded, "Còn lại", "$remainingQuantity"),
                  const SizedBox(height: 14),
                  _infoRow(Icons.attach_money_rounded, "Giá vốn", costPrice),
                  const SizedBox(height: 14),
                  _infoRow(Icons.calendar_today_rounded, "Ngày nhận", receivedDate),
                  const SizedBox(height: 14),
                  _infoRow(Icons.factory_rounded, "NSX", manufacturingDate),
                  const SizedBox(height: 14),
                  _infoRow(Icons.timer_rounded, "HSD", expiryDate),
                ],
              ),
            ),

            const SizedBox(height: 26),

            /// Button hoạt động (Edit + History)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => BatchEditScreen(batch: b)));
                        if (updated != null && updated is Map<String, dynamic>) {
                          setState(() {
                            // merge returned fields into local batch
                            updated.forEach((k, v) => b[k] = v);
                          });
                        }
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Sửa lô'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.orange.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => _showHistory(b['_id'] ?? b['id']),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('Lịch sử'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ------------------- ROW THÔNG TIN -------------------
  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
