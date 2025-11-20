import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

// Model ItemLine
class ItemLine {
  String? productId;
  String productName;
  int quantity;
  double unitPrice;
  String? batchNumber;
  int? batchRemaining;
  DateTime? manufacturingDate;
  DateTime? expiryDate;

  ItemLine({
    this.productId,
    this.productName = '',
    this.quantity = 1,
    this.unitPrice = 0.0,
    this.batchNumber,
    this.manufacturingDate,
    this.expiryDate,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toJson() => {
        'product': productId,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'batchNumber': batchNumber,
        'manufacturingDate': manufacturingDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
      };
}

typedef OnItemChanged = void Function(ItemLine line);

String _removeDiacritics(String input) {
  final withDia =
      'àáảãạâầấẩẫậăằắẳẵặèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
  final withoutDia =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

  return input.split('').map((char) {
    final index = withDia.indexOf(char);
    return index >= 0 ? withoutDia[index] : char;
  }).join();
}

class ItemLineWidget extends StatefulWidget {
  final ItemLine line;
  final List<Map<String, dynamic>> products;
  final VoidCallback onRemove;
  final OnItemChanged onChanged;

  const ItemLineWidget({
    Key? key,
    required this.line,
    required this.products,
    required this.onRemove,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<ItemLineWidget> createState() => _ItemLineWidgetState();
}

class _ItemLineWidgetState extends State<ItemLineWidget> {
  late TextEditingController _qtyCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _batchCtrl;
  late TextEditingController _mfgCtrl;
  late TextEditingController _expCtrl;

  final _focusPrice = FocusNode();

  final formatter = NumberFormat('#,##0.00');

  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _batches = [];
  final GlobalKey _autoKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    _qtyCtrl = TextEditingController(text: widget.line.quantity.toString());
    _priceCtrl = TextEditingController(
        text: widget.line.unitPrice == 0.0
            ? '0.00'
            : formatter.format(widget.line.unitPrice));
    _batchCtrl = TextEditingController(text: widget.line.batchNumber ?? '');
    _mfgCtrl = TextEditingController(
        text: widget.line.manufacturingDate != null
            ? DateFormat('dd/MM/yyyy').format(widget.line.manufacturingDate!)
            : '');
    _expCtrl = TextEditingController(
        text: widget.line.expiryDate != null
            ? DateFormat('dd/MM/yyyy').format(widget.line.expiryDate!)
            : '');

    _suggestions = List<Map<String, dynamic>>.from(widget.products);

    _focusPrice.addListener(_handlePriceFocus);
  }

  void _handlePriceFocus() {
    if (_focusPrice.hasFocus) {
      if (_priceCtrl.text.isNotEmpty) {
        final raw = _priceCtrl.text.replaceAll(',', '');
        _priceCtrl.text = raw == '0.00' ? '' : raw;
      }
    } else {
      final value = double.tryParse(_priceCtrl.text) ?? 0.0;
      setState(() {
        widget.line.unitPrice = value;
        _priceCtrl.text = formatter.format(value);
        widget.onChanged(widget.line);
      });
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _focusPrice.dispose();
    _batchCtrl.dispose();
    _mfgCtrl.dispose();
    _expCtrl.dispose();
    super.dispose();
  }

  Future<void> _showDateError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Lỗi ngày'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Đóng'))],
      ),
    );
  }

  void _filterLocal(String text) {
    final query = _removeDiacritics(text.toLowerCase());
    final words = query.split(' ').where((w) => w.isNotEmpty).toList();

    setState(() {
      if (query.isEmpty) {
        _suggestions = widget.products;
        return;
      }

      _suggestions = widget.products.where((p) {
        final name =
            _removeDiacritics((p['name'] ?? '').toString().toLowerCase());
        return words.every((kw) => name.contains(kw));
      }).toList();
    });
  }

  Future<void> _showAllProducts(
      TextEditingController controller, FocusNode focusNode) async {
    focusNode.requestFocus();
    setState(() => _suggestions = widget.products);

    try {
      (_autoKey.currentState as dynamic)?.showOptions();
    } catch (_) {}
  }

  void _onQtyChanged(String v) {
    final q = int.tryParse(v) ?? 0;
    setState(() {
      widget.line.quantity = q;
      widget.onChanged(widget.line);
    });
  }

  // **Đúng cách: _fetchAndSetCost là method trong State**
  Future<void> _fetchAndSetCost({String? productId, String? batchNumber}) async {
    double? cost;
    try {
      if (batchNumber != null && batchNumber.isNotEmpty) {
        final batchRes = await ApiService.instance.get('/batch-lots/cost', queryParameters: {
          'product': productId,
          'batchNumber': batchNumber,
        });
        final data = batchRes.data as Map<String, dynamic>?;
        cost = data?['costPrice']?.toDouble();
      } else if (productId != null) {
        final prodRes = await ApiService.instance.get('/products/cost', queryParameters: {
          'product': productId,
        });
        final data = prodRes.data as Map<String, dynamic>?;
        cost = data?['costPrice']?.toDouble();
      }
    } catch (e) {
      // Handle error, optionally show warning
    }
    if (cost != null && cost > 0) {
      setState(() {
        widget.line.unitPrice = cost!;
        _priceCtrl.text = formatter.format(cost);
        widget.onChanged(widget.line);
      });
    }
  }

  Future<void> _fetchBatches(String productId) async {
    try {
      // Request batch-lots for this product, only remaining & active
      final resp = await ApiService.instance.getBatchLotsPaginated(query: {
        'productId': productId,
        'onlyRemaining': 'true',
        'status': 'active',
        'page': 1,
        'limit': 1000,
      });
      final list = resp['items'] as List<dynamic>? ?? [];
      final mapped = List<Map<String, dynamic>>.from(list.map((e) => e as Map<String, dynamic>));
      setState(() => _batches = mapped);
      if (_batches.isEmpty) {
        // notify user no batches available
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không có lô còn tồn')));
      } else {
        // If user hasn't explicitly selected a batch, pick one automatically by FIFO
        if (widget.line.batchNumber == null || widget.line.batchNumber!.isEmpty) {
          final Map<String, dynamic> chosen = _chooseFifoBatch(_batches);
          if (chosen.isNotEmpty) {
            // apply same logic as onSelected
            _applySelectedBatch(chosen, showToast: true);
          }
        }
      }
    } catch (e) {
      setState(() => _batches = []);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không thể tải lô hàng')));
    }
  }

  /// Choose a batch by FIFO: prefer earliest receivedDate, then manufacturingDate, then expiryDate
  Map<String, dynamic> _chooseFifoBatch(List<Map<String, dynamic>> batches) {
    Map<String, dynamic>? best;
    DateTime? bestDate;
    for (final b in batches) {
      DateTime? d;
      // try receivedDate
      try {
        if (b['receivedDate'] != null) d = DateTime.tryParse(b['receivedDate'].toString());
      } catch (_) {}
      // fallback to manufacturingDate
      if (d == null) {
        try {
          if (b['manufacturingDate'] != null) d = DateTime.tryParse(b['manufacturingDate'].toString());
        } catch (_) {}
      }
      // fallback to expiryDate (choose earlier expiry as tie-breaker)
      if (d == null) {
        try {
          if (b['expiryDate'] != null) d = DateTime.tryParse(b['expiryDate'].toString());
        } catch (_) {}
      }

      if (d != null) {
        if (bestDate == null || d.isBefore(bestDate)) {
          best = b;
          bestDate = d;
        }
      } else {
        // if no dates, pick the first available as last resort
        if (best == null) best = b;
      }
    }
    return best ?? {};
  }

  void _applySelectedBatch(Map<String, dynamic> selected, {bool showToast = false}) {
    setState(() {
      widget.line.batchNumber = selected['batchNumber']?.toString();
      _batchCtrl.text = widget.line.batchNumber ?? '';
      final cp = (selected['costPrice'] ?? selected['cost'] ?? 0).toDouble();
      widget.line.unitPrice = cp;
      _priceCtrl.text = formatter.format(cp);
      try {
        final rem = selected['remainingQuantity'] ?? selected['remaining'] ?? selected['remainingQty'];
        widget.line.batchRemaining = rem is num ? rem.toInt() : int.tryParse(rem?.toString() ?? '');
      } catch (_) {
        widget.line.batchRemaining = null;
      }
      try {
        final mfg = selected['manufacturingDate'] ?? selected['manufacturedDate'];
        final exp = selected['expiryDate'] ?? selected['expireDate'];
        if (mfg != null) {
          widget.line.manufacturingDate = DateTime.parse(mfg.toString());
          _mfgCtrl.text = DateFormat('dd/MM/yyyy').format(widget.line.manufacturingDate!);
        }
        if (exp != null) {
          widget.line.expiryDate = DateTime.parse(exp.toString());
          _expCtrl.text = DateFormat('dd/MM/yyyy').format(widget.line.expiryDate!);
        }
      } catch (_) {}
      widget.onChanged(widget.line);
    });
    if (showToast && mounted) {
      final bn = widget.line.batchNumber ?? '';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tự chọn lô $bn (FIFO)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: RawAutocomplete<Map<String, dynamic>>(
                key: _autoKey,
                optionsBuilder: (value) {
                  if (_suggestions.isEmpty) return const Iterable.empty();
                  if (value.text.isEmpty) return _suggestions;

                  final query = _removeDiacritics(value.text.toLowerCase());
                  return _suggestions.where((p) {
                    final name = _removeDiacritics(
                        (p['name'] ?? '').toString().toLowerCase());
                    return name.contains(query);
                  });
                },
                displayStringForOption: (option) => option['name'] ?? '',
                fieldViewBuilder:
                    (context, controller, focusNode, onFieldSubmitted) {
                  if (controller.text.isEmpty && widget.line.productName.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (controller.text.isEmpty) controller.text = widget.line.productName;
                    });
                  }

                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Sản phẩm',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_drop_down),
                        onPressed: () =>
                            _showAllProducts(controller, focusNode),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        widget.line.productId = null;
                        widget.line.productName = v;
                        widget.onChanged(widget.line);
                        _filterLocal(v);
                      });
                    },
                    validator: (v) => (widget.line.productId == null)
                        ? 'Chọn sản phẩm'
                        : null,
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Material(
                    elevation: 4,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final item = options.elementAt(index);
                          return ListTile(
                                      leading: () {
                                        String? imgUrl;
                                        if (item['imageUrl'] is String && (item['imageUrl'] as String).isNotEmpty) {
                                          imgUrl = item['imageUrl'] as String;
                                        } else if (item['images'] is List && (item['images'] as List).isNotEmpty) {
                                          final imgs = item['images'] as List<dynamic>;
                                          final primary = imgs.firstWhere((x) => x is Map && (x['isPrimary'] == true), orElse: () => null);
                                          final chosen = primary ?? imgs.first;
                                          if (chosen is Map && chosen['url'] is String) imgUrl = chosen['url'] as String;
                                        } else if (item['image'] is String && (item['image'] as String).isNotEmpty) {
                                          imgUrl = item['image'] as String;
                                        }

                                        if (imgUrl != null) {
                                          return ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(imgUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width:40, height:40, color: Colors.grey.shade200)),
                                          );
                                        }
                                        return CircleAvatar(backgroundColor: Colors.grey.shade200, child: const Icon(Icons.inventory_2_outlined, size: 20));
                                      }(),
                                      title: Text(item['name'] ?? ''),
                              onTap: () async {
                              onSelected(item);
                              setState(() {
                                widget.line.productId = item['_id']?.toString();
                                widget.line.productName = item['name'] ?? '';
                                _batches = [];
                              });
                              widget.onChanged(widget.line);
                              await _fetchAndSetCost(productId: widget.line.productId);
                              await _fetchBatches(widget.line.productId!);
                            },
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Số lượng'),
                keyboardType: TextInputType.number,
                  onChanged: _onQtyChanged,
                  validator: (v) {
                    final val = int.tryParse(v ?? '') ?? 0;
                    if (val <= 0) return 'Nhập số lượng > 0';
                    final rem = widget.line.batchRemaining ?? 0;
                    if (widget.line.batchNumber != null && (rem > 0) && val > rem) return 'Không được lớn hơn số lượng còn trong lô ($rem)';
                    return null;
                  },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _priceCtrl,
                focusNode: _focusPrice,
                decoration: const InputDecoration(labelText: 'Giá đơn vị'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final raw = double.tryParse(v.replaceAll(',', '')) ?? 0.0;
                  setState(() {
                    widget.line.unitPrice = raw;
                    widget.onChanged(widget.line);
                  });
                },
                validator: (v) =>
                    (double.tryParse(v?.replaceAll(',', '') ?? '') ?? 0) <= 0
                        ? 'Nhập giá > 0'
                        : null,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          // Batch selector: autocomplete/dropdown like product selector
          RawAutocomplete<Map<String, dynamic>>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (_batches.isEmpty) return const Iterable.empty();
              if (textEditingValue.text.isEmpty) return _batches;
              final q = textEditingValue.text.toLowerCase();
              return _batches.where((b) => (b['batchNumber'] ?? '').toString().toLowerCase().contains(q));
            },
            displayStringForOption: (option) => option['batchNumber'] ?? '',
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // initialize controller text after build to avoid setState during build
              if (controller.text.isEmpty && widget.line.batchNumber?.isNotEmpty == true) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (controller.text.isEmpty) controller.text = widget.line.batchNumber!;
                });
              }
              // bind _batchCtrl to controller so other code can read (do after frame)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _batchCtrl.text = controller.text;
              });
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                readOnly: _batches.isEmpty ? false : false,
                decoration: const InputDecoration(labelText: 'Số lô (Batch)'),
                onChanged: (v) {
                  // if user manually types batch and product is selected, try to fetch cost
                  setState(() {
                    widget.line.batchNumber = v;
                    widget.onChanged(widget.line);
                  });
                },
              );
            },
            onSelected: (selected) async {
              // when a batch is selected, populate fields
              setState(() {
                widget.line.batchNumber = selected['batchNumber']?.toString();
                _batchCtrl.text = widget.line.batchNumber ?? '';
                final cp = (selected['costPrice'] ?? selected['cost'] ?? 0).toDouble();
                widget.line.unitPrice = cp;
                _priceCtrl.text = formatter.format(cp);
                // set remaining quantity if present
                try {
                  final rem = selected['remainingQuantity'] ?? selected['remaining'] ?? selected['remainingQty'];
                  widget.line.batchRemaining = rem is num ? rem.toInt() : int.tryParse(rem?.toString() ?? '') ;
                } catch (_) {
                  widget.line.batchRemaining = null;
                }
                // set dates
                try {
                  final mfg = selected['manufacturingDate'] ?? selected['manufacturedDate'];
                  final exp = selected['expiryDate'] ?? selected['expireDate'];
                  if (mfg != null) {
                    widget.line.manufacturingDate = DateTime.parse(mfg.toString());
                    _mfgCtrl.text = DateFormat('dd/MM/yyyy').format(widget.line.manufacturingDate!);
                  }
                  if (exp != null) {
                    widget.line.expiryDate = DateTime.parse(exp.toString());
                    _expCtrl.text = DateFormat('dd/MM/yyyy').format(widget.line.expiryDate!);
                  }
                } catch (_) {}
                widget.onChanged(widget.line);
              });

              // warn if quantity > remainingQuantity
              final rem = (selected['remainingQuantity'] ?? 0) as num;
              if (widget.line.quantity > rem) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng lớn hơn lô được chọn — hệ thống sẽ xuất nhiều lô (FIFO) và tính giá trung bình.')));
              }
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final b = options.elementAt(index);
                      return ListTile(
                        title: Text(b['batchNumber'] ?? ''),
                        subtitle: Text('Còn: ${b['remainingQuantity'] ?? 0} — Giá: ${b['costPrice'] ?? 0}'),
                        onTap: () => onSelected(b),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _mfgCtrl,
            decoration: const InputDecoration(labelText: 'Ngày sản xuất'),
            readOnly: true,
            onTap: () async {
                final today = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.line.manufacturingDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(today.year, today.month, today.day),
                );
                if (picked != null) {
                  if (picked.isAfter(DateTime(today.year, today.month, today.day))) {
                    await _showDateError('Ngày sản xuất phải nhỏ hơn hoặc bằng ngày hiện tại.\nKhông được phép chọn ngày trong tương lai.\nNếu người dùng chọn sai thì hiển thị message lỗi.');
                  } else {
                    setState(() {
                      widget.line.manufacturingDate = picked;
                      _mfgCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
                      widget.onChanged(widget.line);
                    });
                    // if expiry exists but now invalid, clear expiry and notify
                    if (widget.line.expiryDate != null && !widget.line.expiryDate!.isAfter(picked)) {
                      await _showDateError('Hạn sử dụng phải lớn hơn ngày sản xuất.\nKhông cho phép ngày nhỏ hơn hoặc bằng ngày sản xuất.\nNếu chọn sai thì báo lỗi ngay.');
                      setState(() {
                        widget.line.expiryDate = null;
                        _expCtrl.text = '';
                        widget.onChanged(widget.line);
                      });
                    }
                  }
                }
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _expCtrl,
            decoration: const InputDecoration(labelText: 'Hạn sử dụng'),
            readOnly: true,
            onTap: () async {
                final first = widget.line.manufacturingDate != null ? widget.line.manufacturingDate!.add(const Duration(days: 1)) : DateTime(2000);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: widget.line.expiryDate ?? (first.isAfter(DateTime.now()) ? first : DateTime.now()),
                  firstDate: first,
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  if (widget.line.manufacturingDate != null && !picked.isAfter(widget.line.manufacturingDate!)) {
                    await _showDateError('Hạn sử dụng phải lớn hơn ngày sản xuất.\nKhông cho phép ngày nhỏ hơn hoặc bằng ngày sản xuất.\nNếu chọn sai thì báo lỗi ngay.');
                  } else {
                    setState(() {
                      widget.line.expiryDate = picked;
                      _expCtrl.text = DateFormat('dd/MM/yyyy').format(picked);
                      widget.onChanged(widget.line);
                    });
                  }
                }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Thành tiền: ${formatter.format(widget.line.total)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}
