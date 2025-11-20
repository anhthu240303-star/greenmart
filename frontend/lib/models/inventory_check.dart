class InventoryCheckModel {
  final String id;
  final String code;
  final String status;
  final List<dynamic> items;
  final DateTime createdAt;

  InventoryCheckModel({
    required this.id,
    required this.code,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory InventoryCheckModel.fromJson(Map<String, dynamic> json) {
    return InventoryCheckModel(
      id: json['_id']?.toString() ?? '',
      code: json['code'] ?? '',
      status: json['status'] ?? 'pending',
      items: json['items'] as List? ?? [],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
