import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import 'category_form_screen.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({Key? key}) : super(key: key);

  @override
  State<CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  bool _isLoading = true;
  List<Category> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApiService.instance.getCategories();
      _items =
          (list).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<void> _onAdd() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryFormScreen()),
    );
    if (res == true) await _load();
  }

  Future<void> _onEdit(Category c) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CategoryFormScreen(category: c)),
    );
    if (res == true) await _load();
  }

  /// Chọn icon theo tên danh mục
  IconData _getCategoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('thịt') || lower.contains('hải sản')) {
      return Icons.set_meal_outlined;
    } else if (lower.contains('rau') || lower.contains('quả')) {
      return Icons.eco_outlined;
    } else if (lower.contains('bia') || lower.contains('rượu')) {
      return Icons.local_drink_outlined;
    } else if (lower.contains('bánh') || lower.contains('kẹo')) {
      return Icons.cookie_outlined;
    } else if (lower.contains('sữa') || lower.contains('trứng')) {
      return Icons.egg_outlined;
    } else if (lower.contains('gia vị')) {
      return Icons.restaurant_menu_outlined;
    } else if (lower.contains('thực phẩm khô')) {
      return Icons.inventory_2_outlined;
    } else if (lower.contains('đông lạnh')) {
      return Icons.ac_unit_outlined;
    } else if (lower.contains('chế biến sẵn')) {
      return Icons.fastfood_outlined;
    } else if (lower.contains('nước')) {
      return Icons.water_drop_outlined;
    }
    return Icons.category_outlined;
  }

  /// Màu chủ đạo cho từng danh mục
  Color _getCategoryColor(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('thịt') || lower.contains('hải sản')) {
      return Colors.redAccent;
    } else if (lower.contains('rau') || lower.contains('quả')) {
      return Colors.green;
    } else if (lower.contains('bia') || lower.contains('rượu')) {
      return Colors.amber;
    } else if (lower.contains('bánh') || lower.contains('kẹo')) {
      return Colors.orangeAccent;
    } else if (lower.contains('sữa') || lower.contains('trứng')) {
      return Colors.blueAccent;
    } else if (lower.contains('gia vị')) {
      return Colors.brown;
    } else if (lower.contains('thực phẩm khô')) {
      return Colors.deepPurple;
    } else if (lower.contains('đông lạnh')) {
      return Colors.cyan;
    } else if (lower.contains('chế biến sẵn')) {
      return Colors.teal;
    } else if (lower.contains('nước')) {
      return Colors.lightBlue;
    }
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Danh mục hàng hóa'),
        centerTitle: true,
        elevation: 1,
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.category_outlined,
                                  size: 80, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Chưa có danh mục nào',
                                style:
                                    TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.all(AppTheme.paddingMedium),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppTheme.paddingSmall),
                        itemBuilder: (context, index) {
                          final c = _items[index];
                          final color = _getCategoryColor(c.name);

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _onEdit(c),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 3,
                              shadowColor: color.withOpacity(0.2),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.grey.shade100,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          vertical: 10, horizontal: 16),
                                  leading: Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: c.imageUrl != null
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Image.network(
                                              c.imageUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(
                                            _getCategoryIcon(c.name),
                                            size: 28,
                                            color: color,
                                          ),
                                  ),
                                  title: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    c.description?.isNotEmpty == true
                                        ? c.description!
                                        : 'Không có mô tả',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.grey),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(Icons.edit_outlined,
                                        color: color),
                                    onPressed: () => _onEdit(c),
                                    tooltip: 'Chỉnh sửa',
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAdd,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm danh mục'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }
}
