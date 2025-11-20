import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Minimal ApiService using Dio. Stores JWT in SharedPreferences and attaches
/// it to Authorization header automatically.
class ApiService {
  ApiService._internal() {
    _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl, connectTimeout: const Duration(milliseconds: 10000)));
    _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
      if (_token != null && _token!.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $_token';
      }
      if (kDebugMode) {
        try {
          final auth = options.headers['Authorization'] ?? options.headers['authorization'];
          // ignore: avoid_print
          print('[ApiService] Request ${options.method} ${options.path} Authorization: $auth');
        } catch (_) {}
      }
      return handler.next(options);
    }, onError: (error, handler) {
      return handler.next(error);
    }));
  }

  static final ApiService instance = ApiService._internal();
  late final Dio _dio;
  String? _token;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    // Ensure Dio has the header if token exists
    if (_token != null && _token!.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    // Also ensure Dio default header is updated immediately
    if (_token != null && _token!.isNotEmpty) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _dio.options.headers.remove('Authorization');
  }

  // Generic helpers
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response?.data;
        if (body is Map && body['message'] != null) throw Exception(body['message']);
        throw Exception('Request failed: ${e.response?.statusCode}');
      }
      throw Exception(e.message);
    }
  }

  Future<Response> post(String path, dynamic data) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response?.data;
        if (body is Map && body['message'] != null) throw Exception(body['message']);
        throw Exception('Request failed: ${e.response?.statusCode}');
      }
      throw Exception(e.message);
    }
  }

  Future<Response> put(String path, dynamic data) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response?.data;
        if (body is Map && body['message'] != null) throw Exception(body['message']);
        throw Exception('Request failed: ${e.response?.statusCode}');
      }
      throw Exception(e.message);
    }
  }

  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response?.data;
        if (body is Map && body['message'] != null) throw Exception(body['message']);
        throw Exception('Request failed: ${e.response?.statusCode}');
      }
      throw Exception(e.message);
    }
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await post('/auth/login', {'email': email, 'password': password});
    if (resp.statusCode == 200 && resp.data != null) {
      // Backend typical response shape: { success: true, data: { token, user } }
      final body = resp.data as Map<String, dynamic>;
      if (body['success'] == true && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        final token = data['token'] as String? ?? '';
        if (token.isNotEmpty) await setToken(token);
        return data;
      }
      throw Exception(body['message'] ?? 'Login failed');
    }
    throw Exception('Login failed with status ${resp.statusCode}');
  }


  // Suppliers
  Future<List<dynamic>> getSuppliers({Map<String, dynamic>? query}) async {
    final resp = await get('/suppliers', queryParameters: query);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to fetch suppliers');
  }

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> payload) async {
    final resp = await post('/suppliers', payload);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create supplier');
  }

  Future<Map<String, dynamic>> updateSupplier(String id, Map<String, dynamic> payload) async {
    final resp = await put('/suppliers/$id', payload);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to update supplier');
  }

  Future<void> deleteSupplier(String id) async {
    final resp = await delete('/suppliers/$id');
    if (resp.statusCode != 200) throw Exception('Failed to delete supplier');
  }

  // Products
  Future<List<dynamic>> getProducts({Map<String, dynamic>? query}) async {
    final resp = await get('/products', queryParameters: query);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      // backward compatible: return list of products
      final list = body['data'] as List<dynamic>? ?? [];
      // normalize products to expose `imageUrl` for UI convenience
      return list.map((e) {
        try {
          final p = Map<String, dynamic>.from(e as Map<String, dynamic>);
          if (p['images'] is List && (p['images'] as List).isNotEmpty) {
            final imgs = p['images'] as List<dynamic>;
            final primary = imgs.firstWhere((x) => x is Map && (x['isPrimary'] == true), orElse: () => null);
            final chosen = primary ?? imgs.first;
            if (chosen is Map && chosen['url'] != null) p['imageUrl'] = chosen['url'];
          }
          return p;
        } catch (_) {
          return e;
        }
      }).toList();
    }
    throw Exception('Failed to fetch products');
  }

  /// Get products with pagination metadata. Returns a map { items: List, pagination: Map }
  Future<Map<String, dynamic>> getProductsPaginated({Map<String, dynamic>? query}) async {
    final resp = await get('/products', queryParameters: query);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      final items = body['data'] as List<dynamic>? ?? [];
      final pagination = body['pagination'] as Map<String, dynamic>? ?? {};
      // normalize product items
      final norm = items.map((e) {
        try {
          final p = Map<String, dynamic>.from(e as Map<String, dynamic>);
          if (p['images'] is List && (p['images'] as List).isNotEmpty) {
            final imgs = p['images'] as List<dynamic>;
            final primary = imgs.firstWhere((x) => x is Map && (x['isPrimary'] == true), orElse: () => null);
            final chosen = primary ?? imgs.first;
            if (chosen is Map && chosen['url'] != null) p['imageUrl'] = chosen['url'];
          }
          return p;
        } catch (_) {
          return e;
        }
      }).toList();
      return {'items': norm, 'pagination': pagination};
    }
    throw Exception('Failed to fetch products');
  }

  Future<Map<String, dynamic>> getProductById(String id) async {
    final resp = await get('/products/$id');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      // Backend may return { data: { product: { ... } } }
      final data = body['data'] as Map<String, dynamic>?;
      if (data != null && data['product'] is Map<String, dynamic>) {
        final prod = Map<String, dynamic>.from(data['product'] as Map<String, dynamic>);
        if (prod['images'] is List && (prod['images'] as List).isNotEmpty) {
          final imgs = prod['images'] as List<dynamic>;
          final primary = imgs.firstWhere((x) => x is Map && (x['isPrimary'] == true), orElse: () => null);
          final chosen = primary ?? imgs.first;
          if (chosen is Map && chosen['url'] != null) prod['imageUrl'] = chosen['url'];
        }
        return prod;
      }
      // fallback: return data map as-is
      return data ?? <String, dynamic>{};
    }
    throw Exception('Failed to fetch product');
  }

  /// Get batch-lots with pagination and filters
  /// Returns { items: List, pagination: Map }
  Future<Map<String, dynamic>> getBatchLotsPaginated({Map<String, dynamic>? query}) async {
    final resp = await get('/batch-lots', queryParameters: query);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      final items = body['data'] != null && body['data']['items'] != null
          ? body['data']['items'] as List<dynamic>
          : (body['items'] as List<dynamic>? ?? []);
      final pagination = body['data'] != null && body['data']['pagination'] != null
          ? body['data']['pagination'] as Map<String, dynamic>
          : (body['pagination'] as Map<String, dynamic>? ?? {});
      return {'items': items, 'pagination': pagination};
    }
    throw Exception('Failed to fetch batch lots');
  }

  /// Recompute product stock on the server from BatchLot totals.
  /// Calls PUT /products/:id/recompute-stock and expects 200 on success.
  Future<void> recomputeProduct(String productId) async {
    final resp = await put('/products/$productId/recompute-stock', {});
    if (resp.statusCode == 200) {
      return;
    }
    throw Exception('Failed to recompute product stock');
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> payload) async {
    final resp = await post('/products', payload);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create product');
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> payload) async {
    final resp = await put('/products/$id', payload);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to update product');
  }

  Future<void> deleteProduct(String id) async {
    final resp = await delete('/products/$id');
    if (resp.statusCode != 200) throw Exception('Failed to delete product');
  }

  /// Upload multiple images for a product using multipart/form-data.
  /// files: list of local file paths to upload
  Future<List<dynamic>> uploadProductImages(String productId, List<String> filePaths) async {
    final formData = FormData();
    for (final p in filePaths) {
      formData.files.add(MapEntry('images', MultipartFile.fromFileSync(p, filename: p.split('/').last)));
    }

    try {
      final resp = await _dio.post('/products/$productId/images', data: formData, options: Options(headers: { 'Content-Type': 'multipart/form-data' }));
      if (resp.statusCode == 200) {
        final body = resp.data as Map<String, dynamic>;
        return body['data'] != null ? (body['data']['images'] as List<dynamic>? ?? body['data'] as List<dynamic>) : (body['images'] as List<dynamic>? ?? []);
      }
      throw Exception('Failed to upload images');
    } on DioException catch (e) {
      if (e.response != null) {
        final body = e.response?.data;
        if (body is Map && body['message'] != null) throw Exception(body['message']);
        throw Exception('Upload failed: ${e.response?.statusCode}');
      }
      throw Exception(e.message);
    }
  }

  /// Delete a product image by its server-side image id.
  Future<void> deleteProductImage(String productId, String imageId) async {
    final resp = await delete('/products/$productId/images/$imageId');
    if (resp.statusCode != 200) {
      throw Exception('Failed to delete image');
    }
  }

  // Categories
  Future<List<dynamic>> getCategories({Map<String, dynamic>? query}) async {
    final resp = await get('/categories', queryParameters: query);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to fetch categories');
  }

  Future<List<dynamic>> getAllCategories() async {
    final resp = await get('/categories/all');
    if (resp.statusCode == 200) {
      final body = resp.data;
      // backend may return different shapes: a List directly, or { data: [...] },
      // or { data: { categories: [...] } }. Be defensive.
  if (body is List) return List<dynamic>.from(body);
      if (body is Map<String, dynamic>) {
        if (body['data'] is List) return body['data'] as List<dynamic>;
        if (body['categories'] is List) return body['categories'] as List<dynamic>;
        // nested data object
        if (body['data'] is Map) {
          final inner = body['data'] as Map<String, dynamic>;
          for (final v in inner.values) {
            if (v is List) return List<dynamic>.from(v);
          }
        }
      }
      // fallback: return empty list to avoid casting error
      return [];
    }
    throw Exception('Failed to fetch all categories');
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> payload) async {
    final resp = await post('/categories', payload);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create category');
  }

  Future<Map<String, dynamic>> updateCategory(String id, Map<String, dynamic> payload) async {
    final resp = await put('/categories/$id', payload);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to update category');
  }

  Future<void> deleteCategory(String id) async {
    final resp = await delete('/categories/$id');
    if (resp.statusCode != 200) throw Exception('Failed to delete category');
  }

  // Supplier details & stats
  Future<Map<String, dynamic>> getSupplierById(String id) async {
    final resp = await get('/suppliers/$id');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      return data['supplier'] as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch supplier');
  }

  Future<Map<String, dynamic>> getSupplierStatistics(String id) async {
    final resp = await get('/suppliers/$id/statistics');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch supplier statistics');
  }

  // Stock Ins
  Future<List<dynamic>> getStockIns({Map<String, dynamic>? query}) async {
    // By default request a large limit so the list screens receive all items
    // (backend defaults to limit=10). For production consider implementing
    // proper pagination in the UI.
    final qp = Map<String, dynamic>.from(query ?? {});
    qp.putIfAbsent('page', () => 1);
    qp.putIfAbsent('limit', () => 1000);
    final resp = await get('/stock-ins', queryParameters: qp);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to fetch stock-ins');
  }

  Future<Map<String, dynamic>> getStockInById(String id) async {
    final resp = await get('/stock-ins/$id');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>;
      return data['stockIn'] as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch stock-in');
  }

  Future<Map<String, dynamic>> createStockIn(Map<String, dynamic> payload) async {
    final resp = await post('/stock-ins', payload);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create stock-in');
  }

  Future<Map<String, dynamic>> updateStockIn(String id, Map<String, dynamic> payload) async {
    final resp = await put('/stock-ins/$id', payload);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to update stock-in');
  }

  Future<void> approveStockIn(String id) async {
    final resp = await put('/stock-ins/$id/approve', {});
    if (resp.statusCode != 200) throw Exception('Failed to approve stock-in');
  }

  Future<void> cancelStockIn(String id) async {
    final resp = await put('/stock-ins/$id/cancel', {});
    if (resp.statusCode != 200) throw Exception('Failed to cancel stock-in');
  }

  Future<void> deleteStockIn(String id) async {
    final resp = await delete('/stock-ins/$id');
    if (resp.statusCode != 200) throw Exception('Failed to delete stock-in');
  }

  // Stock Outs
  Future<List<dynamic>> getStockOuts({Map<String, dynamic>? query}) async {
    final qp = Map<String, dynamic>.from(query ?? {});
    qp.putIfAbsent('page', () => 1);
    qp.putIfAbsent('limit', () => 1000);
    final resp = await get('/stock-outs', queryParameters: qp);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to fetch stock-outs');
  }

  Future<Map<String, dynamic>> getStockOutById(String id) async {
    final resp = await get('/stock-outs/$id');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch stock-out');
  }

  Future<Map<String, dynamic>> createStockOut(Map<String, dynamic> payload) async {
    final resp = await post('/stock-outs', payload);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create stock-out');
  }

  Future<Map<String, dynamic>> updateStockOut(String id, Map<String, dynamic> payload) async {
    final resp = await put('/stock-outs/$id', payload);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to update stock-out');
  }

  Future<void> approveStockOut(String id) async {
    final resp = await put('/stock-outs/$id/approve', {});
    if (resp.statusCode != 200) throw Exception('Failed to approve stock-out');
  }

  Future<void> cancelStockOut(String id) async {
    final resp = await put('/stock-outs/$id/cancel', {});
    if (resp.statusCode != 200) throw Exception('Failed to cancel stock-out');
  }

  Future<void> deleteStockOut(String id) async {
    final resp = await delete('/stock-outs/$id');
    if (resp.statusCode != 200) throw Exception('Failed to delete stock-out');
  }

  // Inventory Checks
  Future<List<dynamic>> getInventoryChecks({Map<String, dynamic>? query}) async {
    final resp = await get('/inventory-checks', queryParameters: query);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to fetch inventory checks');
  }

  // Inventory report (server-side JSON)
  Future<Map<String, dynamic>> getInventoryReport({Map<String, dynamic>? queryParameters}) async {
    final resp = await get('/dashboard/inventory-report', queryParameters: queryParameters);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? body;
    }
    throw Exception('Failed to fetch inventory report');
  }

  Future<Map<String, dynamic>> getInventoryCheckById(String id) async {
    final resp = await get('/inventory-checks/$id');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch inventory check');
  }

  Future<Map<String, dynamic>> createInventoryCheck(Map<String, dynamic> payload) async {
    final resp = await post('/inventory-checks', payload);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create inventory check');
  }

  Future<Map<String, dynamic>> updateInventoryCheckItems(String id, Map<String, dynamic> payload) async {
    final resp = await put('/inventory-checks/$id/items', payload);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to update inventory check items');
  }

  Future<void> completeInventoryCheck(String id) async {
    final resp = await put('/inventory-checks/$id/complete', {});
    if (resp.statusCode != 200) throw Exception('Failed to complete inventory check');
  }

  Future<void> approveInventoryCheck(String id) async {
    final resp = await put('/inventory-checks/$id/approve', {});
    if (resp.statusCode != 200) throw Exception('Failed to approve inventory check');
  }

  Future<void> cancelInventoryCheck(String id) async {
    final resp = await put('/inventory-checks/$id/cancel', {});
    if (resp.statusCode != 200) throw Exception('Failed to cancel inventory check');
  }

  Future<void> deleteInventoryCheck(String id) async {
    final resp = await delete('/inventory-checks/$id');
    if (resp.statusCode != 200) throw Exception('Failed to delete inventory check');
  }

  // Users
  Future<Map<String, dynamic>> getUsers({Map<String, dynamic>? query}) async {
    final resp = await get('/users', queryParameters: query);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch users');
  }

  /// Get activity logs (admin/manager)
  /// Returns { items: List, pagination: Map }
  Future<Map<String, dynamic>> getActivityLogs({Map<String, dynamic>? query}) async {
    final qp = Map<String, dynamic>.from(query ?? {});
    qp.putIfAbsent('page', () => 1);
    qp.putIfAbsent('limit', () => 50);
    final resp = await get('/activity-logs', queryParameters: qp);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      // body may be { data: [...], pagination: {...} } or { data: [...], ... }
      final items = body['data'] is List ? body['data'] as List<dynamic> : (body['data'] is Map && body['data']['items'] is List ? body['data']['items'] as List<dynamic> : (body['items'] as List<dynamic>? ?? []));
      final pagination = body['pagination'] ?? (body['data'] is Map ? body['data']['pagination'] : null) ?? {};
      return {'items': items, 'pagination': pagination};
    }
    throw Exception('Failed to fetch activity logs');
  }

  Future<Map<String, dynamic>> getUserById(String id) async {
    final resp = await get('/users/$id');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch user');
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) async {
    final resp = await post('/users', payload);
    if (resp.statusCode == 201 || resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to create user');
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> payload) async {
    final resp = await put('/users/$id', payload);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to update user');
  }

  Future<void> deleteUser(String id) async {
    final resp = await delete('/users/$id');
    if (resp.statusCode != 200) throw Exception('Failed to delete user');
  }

  Future<Map<String, dynamic>> activateUser(String id) async {
    final resp = await put('/users/$id/activate', {});
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception('Failed to activate user');
  }

  Future<void> resetUserPassword(String id, String newPassword) async {
    final resp = await put('/users/$id/reset-password', {'newPassword': newPassword});
    if (resp.statusCode != 200) throw Exception('Failed to reset password');
  }

  // Dashboard
  Future<Map<String, dynamic>> getDashboardOverview() async {
    final resp = await get('/dashboard/overview');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? body;
    }
    throw Exception('Failed to fetch dashboard overview');
  }

  /// Get list of low-stock products (dashboard endpoint)
  Future<List<dynamic>> getLowStockProducts({Map<String, dynamic>? query}) async {
    final qp = Map<String, dynamic>.from(query ?? {});
    qp.putIfAbsent('limit', () => 50);
    qp.putIfAbsent('skip', () => 0);
    final resp = await get('/dashboard/low-stock', queryParameters: qp);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as List<dynamic>? ?? [];
    }
    throw Exception('Failed to fetch low-stock products');
  }

  /// Get batches for a product
  Future<List<dynamic>> getProductBatches(String productId, {bool onlyActive = true}) async {
    final qp = { 'onlyActive': onlyActive ? 'true' : 'false' };
    final resp = await get('/products/$productId/batches', queryParameters: qp);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      // backend returns { batches: [...] }
      if (body['data'] != null && body['data']['batches'] != null) {
        return body['data']['batches'] as List<dynamic>;
      }
      if (body['batches'] != null) return body['batches'] as List<dynamic>;
      // fallback: try to extract any array
      for (final v in body.values) {
        if (v is List) return v;
      }
      return [];
    }
    throw Exception('Failed to fetch product batches');
  }

  /// Update a batch lot (admin)
  Future<Map<String, dynamic>> updateBatchLot(String batchLotId, Map<String, dynamic> payload) async {
    final resp = await put('/batch-lots/$batchLotId', payload);
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>? ?? body;
    }
    throw Exception('Failed to update batch lot');
  }

  // Auth - current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    final resp = await get('/auth/me');
    if (resp.statusCode == 200) {
      final body = resp.data as Map<String, dynamic>;
      // backend returns { success: true, data: { user } }
      return body['data'] as Map<String, dynamic>? ?? body;
    }
    throw Exception('Failed to fetch current user');
  }
}
