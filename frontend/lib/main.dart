import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/theme.dart';
import 'screens/auth/login_screen.dart';
// Dashboard removed - navigating to product list after login
import 'screens/product/product_list_screen.dart';
import 'screens/product/product_detail_screen.dart';
import 'screens/product/product_form_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/user/user_list_screen.dart';
import 'screens/user/activity_logs_screen.dart';
import 'screens/user/user_form_screen.dart';
import 'screens/user/user_detail_screen.dart';
import 'screens/stock_in/stock_in_list_screen.dart';
import 'screens/stock_in/stock_in_form_screen.dart';
import 'screens/stock_in/stock_in_detail_screen.dart';
import 'screens/supplier/supplier_list_screen.dart';
import 'screens/supplier/supplier_form_screen.dart';
import 'screens/supplier/supplier_detail_screen.dart';
import 'services/api_service.dart';
import 'models/product.dart';
import 'screens/category/category_list_screen.dart';
import 'screens/category/category_form_screen.dart';
import 'screens/stock_out/stock_out_list_screen.dart';
import 'screens/stock_out/stock_out_form_screen.dart';
import 'screens/stock_out/stock_out_detail_screen.dart';
import 'screens/inventory/inventory_check_list_screen.dart';
import 'screens/inventory/inventory_check_screen.dart';
import 'screens/inventory/inventory_screen.dart';
import 'screens/inventory/product_batches_screen.dart';
import 'screens/inventory/batch_detail_screen.dart';
import 'screens/inventory/inventory_batches_screen.dart';
import 'screens/report/report_screen.dart';

String _initialRoute = '/';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi_VN', null);
    // Initialize ApiService (loads token from storage)
    await ApiService.instance.init();
    
    // Check if stored token is valid by fetching current user. If valid,
    // start app at /home; otherwise start at login '/'.
    String initialRoute = '/';
    try {
      await ApiService.instance.getCurrentUser();
      initialRoute = '/home';
    } catch (_) {
      initialRoute = '/';
    }

    _initialRoute = initialRoute;
    runApp(const GreenMartApp());
}

  class GreenMartApp extends StatelessWidget {
    const GreenMartApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenMart - Quản lý kho',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
  initialRoute: _initialRoute,
  routes: {
    '/': (context) => const LoginScreen(),
    '/home': (context) => const HomeScreen(),
  '/profile': (context) => const ProfileScreen(),
  '/products': (context) => const ProductListScreen(),
  '/products/create': (context) => const ProductFormScreen(),
  // Pass the selected ProductModel as the route argument when editing.
  '/products/edit': (context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    return ProductFormScreen(product: args is ProductModel ? args : null);
  },
  '/products/detail': (context) => const ProductDetailScreen(),
        '/categories': (context) => const CategoryListScreen(),
        '/categories/new': (context) => const CategoryFormScreen(),
  '/stock-ins': (context) => const StockInListScreen(),
  '/stock-ins/create': (context) => const StockInFormScreen(),
  '/stock-ins/detail': (context) => const StockInDetailScreen(),
  '/stock-outs': (context) => const StockOutListScreen(),
  '/stock-outs/create': (context) => const StockOutFormScreen(),
  '/stock-outs/detail': (context) => const StockOutDetailScreen(),
  '/inventory-checks': (context) => const InventoryCheckListScreen(),
  '/inventory-checks/create': (context) => const InventoryCheckScreen(),
  '/inventory-checks/detail': (context) => const InventoryCheckScreen(),
  '/inventory': (context) => const InventoryScreen(),
  '/inventory/batches': (context) => const ProductBatchesScreen(),
  '/inventory/batch-lots': (context) => const InventoryBatchesScreen(),
  '/inventory/batch': (context) => const BatchDetailScreen(),
  '/report': (context) => const ReportScreen(),
  '/suppliers/detail': (context) => const SupplierDetailScreen(),
          '/suppliers': (context) => const SupplierListScreen(),
          '/suppliers/new': (context) => const SupplierFormScreen(),
          // User management (admin / warehouse_manager)
          '/users': (context) => const UserListScreen(),
          '/users/create': (context) => const UserFormScreen(),
          '/users/edit': (context) => const UserFormScreen(),
          '/users/detail': (context) => const UserDetailScreen(),
          '/activity-logs': (context) => const ActivityLogsScreen(),
        // TODO: Add more routes
        // '/categories': (context) => const CategoryListScreen(),
        // '/suppliers': (context) => const SupplierListScreen(),
        // '/stock-outs': (context) => const StockOutListScreen(),
        // '/inventory-checks': (context) => const InventoryCheckListScreen(),
      },
    );
  }
}