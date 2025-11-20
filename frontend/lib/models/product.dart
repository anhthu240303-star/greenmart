class ProductModel {
  final String id;
  final String name;
  final String? barcode;
  final String? categoryId;
  final String categoryName;
  final int currentStock;
  final double costPrice;
  final double sellingPrice;
  final String unit;
  final String status;
  final List<dynamic>? images;

  ProductModel({
    required this.id,
    required this.name,
    this.barcode,
    this.categoryId,
    required this.categoryName,
    required this.currentStock,
    required this.costPrice,
    required this.sellingPrice,
    required this.unit,
    required this.status,
    this.images,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      barcode: json['barcode'] as String?,
      categoryId: json['category']?['_id']?.toString() ?? json['category']?['id']?.toString(),
      categoryName: json['category']?['name'] ?? json['categoryName'] ?? '',
      currentStock: (json['currentStock'] ?? 0) as int,
      costPrice: (json['costPrice'] ?? 0).toDouble(),
      sellingPrice: (json['sellingPrice'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      status: json['status'] ?? 'active',
      images: json['images'] != null ? List<dynamic>.from(json['images'] as List) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (barcode != null) 'barcode': barcode,
      if (categoryId != null) 'category': categoryId,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'unit': unit,
      'status': status,
    };
  }

  /// Helper: returns the best image url (primary -> first -> empty string)
  String get imageUrl {
    try {
      if (images == null || images!.isEmpty) return '';
      // images items can be Map or have 'url' key
      // try find isPrimary
      final primary = images!.firstWhere((e) {
        if (e == null) return false;
        if (e is Map && e['isPrimary'] == true) return true;
        return false;
      }, orElse: () => null);
      if (primary != null && primary is Map && (primary['url'] is String) && (primary['url'] as String).isNotEmpty) {
        return primary['url'] as String;
      }
      // fallback to first image with url
      for (final e in images!) {
        if (e is Map && e['url'] is String && (e['url'] as String).isNotEmpty) return e['url'] as String;
      }
      return '';
    } catch (_) {
      return '';
    }
  }
}
