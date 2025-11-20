class Category {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    // normalize image field: API may return a string url or an object { url, publicId, ... }
    String? resolveImage(dynamic img) {
      if (img == null) return null;
      if (img is String) return img;
      if (img is Map) {
        // common keys
        if (img['url'] is String && (img['url'] as String).isNotEmpty) return img['url'] as String;
        if (img['secure_url'] is String && (img['secure_url'] as String).isNotEmpty) return img['secure_url'] as String;
        if (img['path'] is String && (img['path'] as String).isNotEmpty) return img['path'] as String;
        // fallback to toString()
        return img.toString();
      }
      return img.toString();
    }

    final dynamic imageRaw = json['image'] ?? json['imageUrl'];
    final String? imageResolved = resolveImage(imageRaw);
    final dynamic desc = json['description'];
    final String? descriptionResolved = desc is String ? desc : (desc != null ? desc.toString() : null);

    return Category(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      description: descriptionResolved,
      imageUrl: imageResolved,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null) 'description': description,
    };
  }
}
