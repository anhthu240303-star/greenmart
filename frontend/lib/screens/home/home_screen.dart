import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  DashboardStats? _stats;
  String? _error;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadOverview();
    _loadCurrentUser();
  }

  Future<void> _loadOverview() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.instance.getDashboardOverview();
      if (!mounted) return;
      _stats = DashboardStats.fromJson(data);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final data = await ApiService.instance.getCurrentUser();
      if (!mounted) return;
      _currentUser = User.fromJson(data['user'] ?? data);
      setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final today =
        DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'GreenMart',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined,
                size: 28, color: AppTheme.primary),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadOverview(), _loadCurrentUser()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header gradient nhẹ, sạch
                _HeaderCard(
                  title: 'Xin chào, ${_currentUser?.fullName ?? "GreenMart"} 👋',
                  subtitle: today,
                  leadingIcon: Icons.storefront_rounded,
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.paddingMedium,
                    vertical: AppTheme.paddingLarge,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionTitle('Tổng quan'),
                      const SizedBox(height: AppTheme.paddingMedium),
                      _buildOverviewSection(),
                      const SizedBox(height: AppTheme.paddingLarge),
                      const _SectionTitle('Thao tác nhanh'),
                      const SizedBox(height: AppTheme.paddingMedium),
                      _QuickActionsGrid(currentUser: _currentUser),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewSection() {
    if (_isLoading) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: _surfaceCardDecoration(),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text(
                'Đang tải thống kê...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _surfaceCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lỗi tải thống kê',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_error',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                onPressed: _loadOverview,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final s = _stats!;
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.7,
      children: [
        StatCard(title: 'Sản phẩm', value: '${s.totalProducts}', icon: Icons.inventory_2_outlined),
        StatCard(title: 'Danh mục', value: '${s.totalCategories}', icon: Icons.category_outlined),
        StatCard(title: 'Nhà cung cấp', value: '${s.totalSuppliers}', icon: Icons.local_shipping_outlined),
        StatCard(title: 'Sắp hết', value: '${s.lowStockProducts}', icon: Icons.warning_amber_rounded, color: AppTheme.warning),
        StatCard(title: 'Giá trị tồn', value: currency.format(s.totalStockValue), icon: Icons.attach_money_outlined),
        StatCard(title: 'Nhập hôm nay', value: '${s.todayStockIns}', icon: Icons.arrow_downward_rounded),
        StatCard(title: 'Xuất hôm nay', value: '${s.todayStockOuts}', icon: Icons.arrow_upward_rounded),
        StatCard(title: 'Chờ duyệt', value: '${s.pendingStockIns}/${s.pendingStockOuts}', icon: Icons.pending_outlined),
      ],
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    final titleStyle = const TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_tint(AppTheme.primary, .08), AppTheme.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                _BigAvatar(
                  url: _currentUser?.avatar,
                  fallbackLabel: _currentUser?.fullName,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DefaultTextStyle(
                    style: const TextStyle(color: Colors.white),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentUser?.fullName ?? 'User',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (_currentUser != null)
                          Text(
                            _currentUser!.roleDisplayName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(.9),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(leading: const Icon(Icons.inventory_2_outlined), title: Text('Sản phẩm', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/products')),
          ListTile(leading: const Icon(Icons.storage_outlined), title: Text('Tồn kho', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/inventory')),
          ListTile(leading: const Icon(Icons.category_outlined), title: Text('Danh mục', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/categories')),
          ListTile(leading: const Icon(Icons.local_shipping_outlined), title: Text('Nhà cung cấp', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/suppliers')),
          if (_currentUser != null && (_currentUser!.role == 'admin' || _currentUser!.role == 'warehouse_manager'))
            ListTile(leading: const Icon(Icons.analytics_outlined), title: Text('Báo cáo', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/report')),
          const Divider(),
          ListTile(leading: const Icon(Icons.arrow_downward_rounded), title: Text('Nhập kho', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/stock-ins')),
          ListTile(leading: const Icon(Icons.arrow_upward_rounded), title: Text('Xuất kho', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/stock-outs')),
          ListTile(leading: const Icon(Icons.fact_check_outlined), title: Text('Kiểm kê', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/inventory-checks')),
          const Divider(),
          if (_currentUser != null && (_currentUser!.role == 'admin' || _currentUser!.role == 'warehouse_manager'))
            ListTile(leading: const Icon(Icons.group_outlined), title: Text('Người dùng', style: titleStyle), onTap: () => Navigator.pushNamed(context, '/users')),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: Text('Đăng xuất', style: titleStyle),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
    );
  }

  BoxDecoration _surfaceCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  static Color _tint(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final lighter = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lighter.toColor();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 5, height: 22, decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12))),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.title, required this.subtitle, required this.leadingIcon});
  final String title;
  final String subtitle;
  final IconData leadingIcon;

  Color _tint(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    final lighter = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lighter.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color.from(alpha: 1, red: 0.298, green: 0.686, blue: 0.314);
    return Container(
      margin: const EdgeInsets.all(AppTheme.paddingMedium),
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_tint(primary, .15), primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xin chào!', style: TextStyle(color: Colors.white.withOpacity(.95), fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(.9), fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(16)),
            child: Icon(leadingIcon, size: 42, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BigAvatar extends StatelessWidget {
  const _BigAvatar({this.url, this.fallbackLabel});
  final String? url;
  final String? fallbackLabel;

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.take(1).toString().toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const double r = 40;
    final initials = _initials(fallbackLabel);
    return CircleAvatar(
      radius: r,
      backgroundColor: Colors.white,
      foregroundImage: url != null && url!.isNotEmpty ? NetworkImage(url!) : null,
      child: url == null || url!.isEmpty
          ? Text(
              initials,
              style: const TextStyle(color: AppTheme.primary, fontSize: 24, fontWeight: FontWeight.w800),
            )
          : null,
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.currentUser});
  final User? currentUser;

  bool get _canManageUsers => currentUser != null && (currentUser!.role == 'admin' || currentUser!.role == 'warehouse_manager');

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      child: IconTheme(
        data: const IconThemeData(size: 26),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            MenuCard(title: 'Sản phẩm', icon: Icons.inventory_2_outlined, onTap: () => Navigator.pushNamed(context, '/products')),
            MenuCard(title: 'Tồn kho', icon: Icons.storage_outlined, onTap: () => Navigator.pushNamed(context, '/inventory')),
            MenuCard(title: 'Danh mục', icon: Icons.category_outlined, onTap: () => Navigator.pushNamed(context, '/categories')),
            MenuCard(title: 'Nhà cung cấp', icon: Icons.local_shipping_outlined, onTap: () => Navigator.pushNamed(context, '/suppliers')),
            MenuCard(title: 'Nhập kho', icon: Icons.arrow_downward_rounded, onTap: () => Navigator.pushNamed(context, '/stock-ins')),
            MenuCard(title: 'Xuất kho', icon: Icons.arrow_upward_rounded, onTap: () => Navigator.pushNamed(context, '/stock-outs')),
            MenuCard(title: 'Kiểm kê', icon: Icons.fact_check_outlined, onTap: () => Navigator.pushNamed(context, '/inventory-checks')),
            if (_canManageUsers) MenuCard(title: 'Người dùng', icon: Icons.group_outlined, onTap: () => Navigator.pushNamed(context, '/users')),
          ],
        ),
      ),
    );
  }
}
