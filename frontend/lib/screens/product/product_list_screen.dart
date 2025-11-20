import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import '../../models/category.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final _searchController = TextEditingController();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
  
  bool _isLoading = true;
  List<ProductModel> _products = [];
  List<ProductModel> _filteredProducts = [];
  String _selectedFilter = 'all';

  // Pagination
  int _page = 1;
  final int _limit = 20;
  
  int _totalPages = 1;

  // Category filter
  List<Category> _categories = [];
  String? _selectedCategoryId;

  // no scroll controller needed for Prev/Next pagination

  @override
  void initState() {
    super.initState();
  _loadCategories();
  _loadProductsPage(1);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await ApiService.instance.getAllCategories();
      setState(() {
        _categories = list.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (_) {}
  }

  /// Load a specific page (used by Prev/Next pagination)
  Future<void> _loadProductsPage(int page) async {
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> query = {'page': page.toString(), 'limit': _limit.toString()};
      if (_selectedCategoryId != null && _selectedCategoryId!.isNotEmpty) query['category'] = _selectedCategoryId;
      if (_searchController.text.isNotEmpty) query['search'] = _searchController.text.trim();

      final resp = await ApiService.instance.getProductsPaginated(query: query);
      final items = resp['items'] as List<dynamic>;
      final pagination = resp['pagination'] as Map<String, dynamic>?;

      final newProducts = items.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
      setState(() {
        _products = newProducts;
        _filteredProducts = List<ProductModel>.from(_products);
        _page = page;
        if (pagination != null) {
          _totalPages = (pagination['totalPages'] as int?) ?? 1;
        } else {
          _totalPages = 1;
        }
      });
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Legacy infinite loader removed; use _loadProductsPage(page)

  // local filtering removed in favor of server-side search/pagination

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      switch (filter) {
        case 'low_stock':
          _filteredProducts = _products.where((p) => p.currentStock <= 10).toList();
          break;
        case 'out_of_stock':
          _filteredProducts = _products.where((p) => p.currentStock == 0).toList();
          break;
        case 'active':
          _filteredProducts = _products.where((p) => p.status == 'active').toList();
          break;
        default:
          _filteredProducts = List<ProductModel>.from(_products);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Responsive scale based on screen width
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 360).clamp(0.8, 1.8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý sản phẩm'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            onSelected: _applyFilter,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'all',
                child: Row(
                  children: [
                    Icon(
                      Icons.list_rounded,
                      color: _selectedFilter == 'all' ? AppTheme.primary : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Tất cả'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'low_stock',
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: _selectedFilter == 'low_stock' ? AppTheme.warning : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Sắp hết hàng'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'out_of_stock',
                child: Row(
                  children: [
                    Icon(
                      Icons.remove_circle_outline,
                      color: _selectedFilter == 'out_of_stock' ? AppTheme.error : null,
                    ),
                    const SizedBox(width: 12),
                    const Text('Hết hàng'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/products/create');
        },
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          // Search & category filter
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingMedium),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadProductsPage(1),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên hoặc mã vạch...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _loadProductsPage(1);
                              },
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.paddingSmall),
                SizedBox(
                  width: 160 * scale,
                  child: DropdownButtonFormField<String?>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Tất cả'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Tất cả')),
                      ..._categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name)))
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedCategoryId = v;
                      });
                      _loadProductsPage(1);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Product list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 64 * scale,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Không có sản phẩm',
                              style: TextStyle(
                                fontSize: 16 * scale,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _loadProductsPage(1),
                        child: ListView(
                          padding: const EdgeInsets.all(AppTheme.paddingMedium),
                          children: (() {
                            // Group products by category name when no category filter selected
                            final Map<String, List<ProductModel>> grouped = {};
                            for (final p in _filteredProducts) {
                              final key = (p.categoryName.isNotEmpty) ? p.categoryName : 'Không phân loại';
                              grouped.putIfAbsent(key, () => []).add(p);
                            }

                            final List<Widget> children = [];
                            grouped.forEach((categoryName, items) {
                              children.add(Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  categoryName,
                                  style: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w700),
                                ),
                              ));

                              for (var i = 0; i < items.length; i++) {
                                children.add(_buildProductCard(items[i]));
                                if (i != items.length - 1) children.add(const SizedBox(height: AppTheme.paddingSmall));
                              }
                              // gap between groups
                              children.add(const SizedBox(height: AppTheme.paddingMedium));
                            });

                            return children;
                          })(),
                        ),
                      ),
          ),

          // Pagination controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.paddingMedium, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _page > 1 && !_isLoading ? () => _loadProductsPage(_page - 1) : null,
                  child: const Text('Trước'),
                ),
                const SizedBox(width: 12),
                Text('Trang $_page / $_totalPages'),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _page < _totalPages && !_isLoading ? () => _loadProductsPage(_page + 1) : null,
                  child: const Text('Tiếp'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final isLowStock = product.currentStock <= 10;
    final isOutOfStock = product.currentStock == 0;

    // responsive sizes inside card
    final width = MediaQuery.of(context).size.width;
    final scale = (width / 360).clamp(0.8, 1.8);
    final imageSize = 80.0 * scale;

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/products/detail',
            arguments: product.id,
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image (thumbnail) or placeholder — larger
                  Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: product.imageUrl.isNotEmpty
                          ? Image.network(
                              product.imageUrl,
                              width: imageSize,
                              height: imageSize,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(child: SizedBox(width: 20 * scale, height: 20 * scale, child: const CircularProgressIndicator(strokeWidth: 2)));
                              },
                              errorBuilder: (context, error, stackTrace) => Center(child: Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 36 * scale)),
                            )
                          : const Center(child: Icon(Icons.inventory_2_outlined, color: AppTheme.primary, size: 36)),
                    ),
                  ),
                  const SizedBox(width: AppTheme.paddingMedium),
                  
                  // Product info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 18 * scale,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.categoryName,
                          style: TextStyle(
                            fontSize: 14 * scale,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (product.barcode != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Mã: ${product.barcode}',
                            style: TextStyle(
                              fontSize: 12 * scale,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Stock status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? AppTheme.error.withOpacity(0.1)
                          : isLowStock
                              ? AppTheme.warning.withOpacity(0.1)
                              : AppTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isOutOfStock
                          ? 'Hết'
                          : isLowStock
                              ? 'Thấp'
                              : 'Còn',
                      style: TextStyle(
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w600,
                        color: isOutOfStock
                            ? AppTheme.error
                            : isLowStock
                                ? AppTheme.warning
                                : AppTheme.success,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.paddingMedium),
              
              // Stock and price info
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tồn kho',
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${product.currentStock} ${product.unit}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giá bán',
                          style: TextStyle(
                            fontSize: 12 * scale,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currencyFormat.format(product.sellingPrice),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                    IconButton(
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () {
                      _showProductOptions(product);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductOptions(ProductModel product) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Xem chi tiết'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/products/detail',
                  arguments: product.id,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Chỉnh sửa'),
              onTap: () {
                Navigator.pop(context);
                // Pass the full product model to the edit route so the form
                // can prefill values and edit in-place.
                Navigator.pushNamed(
                  context,
                  '/products/edit',
                  arguments: product,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outlined, color: AppTheme.error),
              title: const Text('Xóa', style: TextStyle(color: AppTheme.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(product);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa sản phẩm "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performDelete(product);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(ProductModel product) async {
    try {
      await ApiService.instance.deleteProduct(product.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa sản phẩm'),
          backgroundColor: AppTheme.success,
        ),
      );
  await _loadProductsPage(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Xóa thất bại: ${e.toString()}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }
}