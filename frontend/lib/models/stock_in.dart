class StockInModel {
  final String id;
  final String code;
  final String supplierId;
  final String supplierName;
  final double totalAmount;
  final String status;
  final List<dynamic> items;
  final DateTime createdAt;
  final DateTime? importDate;
  final String createdByName;
  final String? approvedByName;
  final DateTime? approvedAt;

  StockInModel({
    required this.id,
    required this.code,
    required this.supplierId,
    required this.supplierName,
    required this.totalAmount,
    required this.status,
    required this.items,
    required this.createdAt,
    this.importDate,
    required this.createdByName,
    this.approvedByName,
    this.approvedAt,
  });

  factory StockInModel.fromJson(Map<String, dynamic> json) {
    return StockInModel(
      id: json['_id']?.toString() ?? '',
      code: json['code'] ?? json['reference'] ?? '',
      supplierId: json['supplier']?['_id']?.toString() ?? json['supplier']?.toString() ?? '',
      supplierName: json['supplier']?['name'] ?? '',
      totalAmount: (json['totalAmount'] ?? json['total'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      items: json['items'] as List? ?? [],
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      importDate: json['importDate'] != null ? DateTime.parse(json['importDate']) : null,
      createdByName: json['createdBy']?['fullName'] ?? json['createdBy']?['name'] ?? json['createdBy']?['username'] ?? 'N/A',
      approvedByName: json['approvedBy']?['fullName'] ?? json['approvedBy']?['name'] ?? json['approvedBy']?['username'],
      approvedAt: json['approvedAt'] != null ? DateTime.parse(json['approvedAt']) : null,
    );
  }
}
