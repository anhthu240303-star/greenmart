class User {
  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? phone;
  final String role;
  final String? avatar;
  final bool isActive;
  final DateTime? lastLogin;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
    this.avatar,
    required this.isActive,
    this.lastLogin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String? resolveAvatar(dynamic a) {
      if (a == null) return null;
      if (a is String) return a;
      if (a is Map) {
        if (a['url'] is String && (a['url'] as String).isNotEmpty) return a['url'] as String;
        if (a['secure_url'] is String && (a['secure_url'] as String).isNotEmpty) return a['secure_url'] as String;
        return a.toString();
      }
      return a.toString();
    }

    return User(
      id: json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'],
      role: json['role'] ?? 'warehouse_staff',
      avatar: resolveAvatar(json['avatar']),
      isActive: json['isActive'] ?? true,
      lastLogin: json['lastLogin'] != null 
          ? DateTime.parse(json['lastLogin']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'username': username,
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'role': role,
      'avatar': avatar,
      'isActive': isActive,
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  String get roleDisplayName {
    switch (role) {
      case 'admin':
        return 'Quản trị viên';
      case 'warehouse_manager':
        return 'Quản lý kho';
      case 'warehouse_staff':
        return 'Nhân viên kho';
      default:
        return role;
    }
  }
}

class DashboardStats {
  final int totalProducts;
  final int totalCategories;
  final int totalSuppliers;
  final int lowStockProducts;
  final double totalStockValue;
  final int todayStockIns;
  final int todayStockOuts;
  final int pendingStockIns;
  final int pendingStockOuts;

  DashboardStats({
    required this.totalProducts,
    required this.totalCategories,
    required this.totalSuppliers,
    required this.lowStockProducts,
    required this.totalStockValue,
    required this.todayStockIns,
    required this.todayStockOuts,
    required this.pendingStockIns,
    required this.pendingStockOuts,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final inventory = json['inventory'] ?? {};
    final today = json['today'] ?? {};
    final pending = json['pending'] ?? {};

    return DashboardStats(
      totalProducts: inventory['totalProducts'] ?? 0,
      totalCategories: inventory['totalCategories'] ?? 0,
      totalSuppliers: inventory['totalSuppliers'] ?? 0,
      lowStockProducts: inventory['lowStockProducts'] ?? 0,
      totalStockValue: (inventory['totalStockValue'] ?? 0).toDouble(),
      todayStockIns: today['stockIns'] ?? 0,
      todayStockOuts: today['stockOuts'] ?? 0,
      pendingStockIns: pending['stockIns'] ?? 0,
      pendingStockOuts: pending['stockOuts'] ?? 0,
    );
  }
}