class Supplier {
  final String id;
  final String code;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? street;
  final String? district;
  final String? city;
  final String? country;
  final String? taxCode;
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdByName;

  Supplier({
    required this.id,
    required this.code,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.street,
    this.district,
    this.city,
    this.country,
    this.taxCode,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.isActive = true,
    this.createdAt,
    this.createdByName,
  });

  String get fullAddress {
    final parts = <String>[];
    if (street != null && street!.isNotEmpty) parts.add(street!);
    if (district != null && district!.isNotEmpty) parts.add(district!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.isNotEmpty ? parts.join(', ') : '-';
  }

  factory Supplier.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>?;
    final bankAccount = json['bankAccount'] as Map<String, dynamic>?;

    return Supplier(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      contactPerson: json['contactPerson'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      street: address?['street'] as String?,
      district: address?['district'] as String?,
      city: address?['city'] as String?,
      country: address?['country'] as String?,
      taxCode: json['taxCode'] as String?,
      bankName: bankAccount?['bankName'] as String?,
      accountNumber: bankAccount?['accountNumber'] as String?,
      accountName: bankAccount?['accountName'] as String?,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      // transactionCount removed — backend returns 0 now
      createdByName: json['createdBy']?['fullName'] ?? json['createdBy']?['name'] ?? json['createdBy']?['username'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      if (contactPerson != null && contactPerson!.isNotEmpty) 'contactPerson': contactPerson,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (email != null && email!.isNotEmpty) 'email': email,
      if (taxCode != null && taxCode!.isNotEmpty) 'taxCode': taxCode,
    };

    // Address object
    if (street != null || district != null || city != null || country != null) {
      data['address'] = {
        if (street != null && street!.isNotEmpty) 'street': street,
        if (district != null && district!.isNotEmpty) 'district': district,
        if (city != null && city!.isNotEmpty) 'city': city,
        if (country != null && country!.isNotEmpty) 'country': country,
      };
    }

    // Bank account object
    if (bankName != null || accountNumber != null || accountName != null) {
      data['bankAccount'] = {
        if (bankName != null && bankName!.isNotEmpty) 'bankName': bankName,
        if (accountNumber != null && accountNumber!.isNotEmpty) 'accountNumber': accountNumber,
        if (accountName != null && accountName!.isNotEmpty) 'accountName': accountName,
      };
    }

    return data;
  }
}
