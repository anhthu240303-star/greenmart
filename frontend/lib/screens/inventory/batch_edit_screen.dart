import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/batch_history_service.dart';
import '../../config/theme.dart';

class BatchEditScreen extends StatefulWidget {
  final Map<String, dynamic> batch;
  const BatchEditScreen({Key? key, required this.batch}) : super(key: key);

  @override
  State<BatchEditScreen> createState() => _BatchEditScreenState();
}

class _BatchEditScreenState extends State<BatchEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _batchNumberCtrl;
  late TextEditingController _initialCtrl;
  late TextEditingController _remainingCtrl;
  late TextEditingController _costCtrl;
  late TextEditingController _notesCtrl;

  DateTime? _received;
  DateTime? _mfg;
  DateTime? _exp;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.batch;
    _batchNumberCtrl = TextEditingController(text: (b['batchNumber'] ?? '').toString());
    _initialCtrl = TextEditingController(text: (b['initialQuantity'] ?? 0).toString());
    _remainingCtrl = TextEditingController(text: (b['remainingQuantity'] ?? 0).toString());
    _costCtrl = TextEditingController(text: (b['costPrice'] ?? '').toString());
    _notesCtrl = TextEditingController(text: (b['notes'] ?? '').toString());
    _received = b['receivedDate'] != null ? DateTime.tryParse(b['receivedDate'].toString()) : null;
    _mfg = b['manufacturingDate'] != null ? DateTime.tryParse(b['manufacturingDate'].toString()) : null;
    _exp = b['expiryDate'] != null ? DateTime.tryParse(b['expiryDate'].toString()) : null;
  }

  @override
  void dispose() {
    _batchNumberCtrl.dispose();
    _initialCtrl.dispose();
    _remainingCtrl.dispose();
    _costCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // Validate dates according to warehouse rules
    final today = DateTime.now();
    // manufacturedDate (NSX) must be <= today
    if (_mfg != null && _mfg!.isAfter(DateTime(today.year, today.month, today.day))) {
      await _showError('Ngày sản xuất phải nhỏ hơn hoặc bằng ngày hiện tại.\nKhông được phép chọn ngày trong tương lai.\nNếu người dùng chọn sai thì hiển thị message lỗi.');
      return;
    }
    // expiry must be greater than manufacturing date
    if (_exp != null && _mfg != null && !_exp!.isAfter(_mfg!)) {
      await _showError('Hạn sử dụng phải lớn hơn ngày sản xuất.\nKhông cho phép ngày nhỏ hơn hoặc bằng ngày sản xuất.\nNếu chọn sai thì báo lỗi ngay.');
      return;
    }
    // stockIn (received) must not be > today
    if (_received != null && _received!.isAfter(DateTime(today.year, today.month, today.day))) {
      await _showError('Ngày nhập kho không được lớn hơn ngày hiện tại.\nCho phép chọn trong quá khứ.\nNếu chọn ngày tương lai thì cảnh báo lỗi.');
      return;
    }
    // stockIn must be >= manufacturingDate if both present
    if (_received != null && _mfg != null && _received!.isBefore(_mfg!)) {
      await _showError('Ngày nhập kho phải lớn hơn hoặc bằng ngày sản xuất.\nNếu chọn sai thì hiển thị cảnh báo.');
      return;
    }
    final batchId = widget.batch['_id'] ?? widget.batch['id'];
    if (batchId == null) return;

    final prevPayload = Map<String, dynamic>.from(widget.batch);

    final payload = {
      // batchNumber is intentionally not editable server-side in some setups, but we include if changed
      'batchNumber': _batchNumberCtrl.text.trim(),
      'initialQuantity': int.tryParse(_initialCtrl.text) ?? 0,
      'remainingQuantity': int.tryParse(_remainingCtrl.text) ?? 0,
      'costPrice': double.tryParse(_costCtrl.text) ?? 0.0,
      'notes': _notesCtrl.text.trim(),
    };
    if (_received != null) payload['receivedDate'] = _received!.toIso8601String();
    if (_mfg != null) payload['manufacturingDate'] = _mfg!.toIso8601String();
    if (_exp != null) payload['expiryDate'] = _exp!.toIso8601String();

    try {
      setState(() => _saving = true);
      // Preflight: ensure token is valid by fetching current user. If invalid, prompt login.
      try {
        await ApiService.instance.getCurrentUser();
      } catch (_) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Chưa đăng nhập'),
            content: const Text('Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Hủy')),
              ElevatedButton(onPressed: () async {
                Navigator.of(d).pop();
                await ApiService.instance.clearToken();
                if (!mounted) return;
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }, child: const Text('Đăng nhập')),
            ],
          ),
        );
        return;
      }

      await ApiService.instance.updateBatchLot(batchId.toString(), payload);
      // record history for undo
      BatchHistoryService.add(batchId.toString(), prevPayload);

      // show snack with undo
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Đã lưu lô'),
        action: SnackBarAction(label: 'Hoàn tác', onPressed: () async {
        // rollback
        try {
          // preflight current user
          try {
            await ApiService.instance.getCurrentUser();
          } catch (_) {
            if (!mounted) return;
            await showDialog<void>(
              context: context,
              builder: (d) => AlertDialog(
                title: const Text('Chưa đăng nhập'),
                content: const Text('Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.'),
                actions: [
                  TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Hủy')),
                  ElevatedButton(onPressed: () async {
                    Navigator.of(d).pop();
                    await ApiService.instance.clearToken();
                    if (!mounted) return;
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                  }, child: const Text('Đăng nhập')),
                ],
              ),
            );
            return;
          }

          await ApiService.instance.updateBatchLot(batchId.toString(), {
            'remainingQuantity': prevPayload['remainingQuantity'] ?? 0,
            'initialQuantity': prevPayload['initialQuantity'] ?? 0,
            'costPrice': prevPayload['costPrice'] ?? 0.0,
            'receivedDate': prevPayload['receivedDate'],
            'manufacturingDate': prevPayload['manufacturingDate'],
            'expiryDate': prevPayload['expiryDate'],
            'notes': prevPayload['notes'] ?? '',
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hoàn tác')));
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hoàn tác thất bại: ${e.toString()}')));
        }
      }),
      ));

      // return updated payload to caller (we don't fetch updated from server to keep simple)
      final updated = {...widget.batch, ...payload};
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        // If unauthorized, guide user to login
        if (msg.contains('Vui lòng đăng nhập') || msg.contains('401') || msg.toLowerCase().contains('unauthorized')) {
          await showDialog<void>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Chưa đăng nhập'),
              content: const Text('Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('Hủy')),
                ElevatedButton(onPressed: () async {
                  Navigator.of(d).pop();
                  await ApiService.instance.clearToken();
                  if (!mounted) return;
                  Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                }, child: const Text('Đăng nhập')),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lưu thất bại: ${msg}')));
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa Lô hàng'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _batchNumberCtrl,
                  readOnly: true, // lock batchNumber as requested
                  decoration: const InputDecoration(labelText: 'Số lô (khóa)'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _initialCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số lượng nhập'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '0') ?? 0;
                    if (n < 0) return 'Phải >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _remainingCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số lượng còn'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '0') ?? 0;
                    if (n < 0) return 'Phải >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _costCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Giá vốn'),
                  validator: (v) {
                    final d = double.tryParse(v ?? '0') ?? 0.0;
                    if (d < 0) return 'Phải >= 0';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final today = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _received ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(today.year, today.month, today.day),
                        );
                        if (picked != null) {
                          // validate immediate: stockIn must not be in future
                          if (picked.isAfter(DateTime(today.year, today.month, today.day))) {
                            await _showError('Ngày nhập kho không được lớn hơn ngày hiện tại.\nCho phép chọn trong quá khứ.\nNếu chọn ngày tương lai thì cảnh báo lỗi.');
                          } else if (_mfg != null && picked.isBefore(_mfg!)) {
                            await _showError('Ngày nhập kho phải lớn hơn hoặc bằng ngày sản xuất.\nNếu chọn sai thì hiển thị cảnh báo.');
                          } else {
                            setState(() => _received = picked);
                          }
                        }
                      },
                      child: Text(_received != null ? 'Ngày nhận: ${_received!.toLocal().toString().split(' ')[0]}' : 'Chọn ngày nhận'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final today = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _mfg ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(today.year, today.month, today.day),
                        );
                        if (picked != null) {
                          if (picked.isAfter(DateTime(today.year, today.month, today.day))) {
                            await _showError('Ngày sản xuất phải nhỏ hơn hoặc bằng ngày hiện tại.\nKhông được phép chọn ngày trong tương lai.\nNếu người dùng chọn sai thì hiển thị message lỗi.');
                          } else {
                            setState(() => _mfg = picked);
                            // if expiry is set and now invalid, clear expiry and notify
                            if (_exp != null && !_exp!.isAfter(picked)) {
                              await _showError('Hạn sử dụng phải lớn hơn ngày sản xuất.\nKhông cho phép ngày nhỏ hơn hoặc bằng ngày sản xuất.\nNếu chọn sai thì báo lỗi ngay.');
                              setState(() => _exp = null);
                            }
                          }
                        }
                      },
                      child: Text(_mfg != null ? 'NSX: ${_mfg!.toLocal().toString().split(' ')[0]}' : 'Chọn NSX'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _exp ?? DateTime.now(),
                      firstDate: _mfg != null ? _mfg!.add(const Duration(days: 1)) : DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      // If manufacturing date present, expiry must be > mfg
                      if (_mfg != null && !picked.isAfter(_mfg!)) {
                        await _showError('Hạn sử dụng phải lớn hơn ngày sản xuất.\nKhông cho phép ngày nhỏ hơn hoặc bằng ngày sản xuất.\nNếu chọn sai thì báo lỗi ngay.');
                      } else {
                        setState(() => _exp = picked);
                      }
                    }
                  },
                  child: Text(_exp != null ? 'HSD: ${_exp!.toLocal().toString().split(' ')[0]}' : 'Chọn HSD'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Ghi chú'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Lưu thay đổi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Lỗi ngày'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Đóng')),
        ],
      ),
    );
  }
}
