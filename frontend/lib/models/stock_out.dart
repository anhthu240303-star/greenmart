class StockOutModel {
  final String id;
  final String code;
  final String destination;
  final double totalAmount;
  final String status;
  final List<dynamic> items;
  final DateTime createdAt;

  StockOutModel({
    required this.id,
    required this.code,
    required this.destination,
    required this.totalAmount,
    required this.status,
    required this.items,
    required this.createdAt,
  });

  factory StockOutModel.fromJson(Map<String, dynamic> json) {
    return StockOutModel(
      id: json['_id']?.toString() ?? '',
      code: json['code'] ?? json['reference'] ?? '',
      destination: json['destination'] ?? json['to'] ?? '',
      totalAmount: (json['totalAmount'] ?? json['total'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      items: json['items'] as List? ?? [],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}
