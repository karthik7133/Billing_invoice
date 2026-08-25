class ProductModel {
  final String id;
  final String name;
  final String description;
  final String hsnSac;
  final String itemType; // 'PRODUCT' or 'SERVICE'
  final String unit;
  final double price;
  final double gstRate;
  final String imageUrl;

  ProductModel({
    required this.id,
    required this.name,
    this.description = '',
    this.hsnSac = '',
    this.itemType = 'PRODUCT',
    this.unit = 'PCS',
    required this.price,
    required this.gstRate,
    this.imageUrl = '',
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      hsnSac: json['hsnSac']?.toString() ?? '',
      itemType: json['itemType']?.toString() ?? 'PRODUCT',
      unit: json['unit']?.toString() ?? 'PCS',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'name': name,
      'description': description,
      'hsnSac': hsnSac,
      'itemType': itemType,
      'unit': unit,
      'price': price,
      'gstRate': gstRate,
      'imageUrl': imageUrl,
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? hsnSac,
    String? itemType,
    String? unit,
    double? price,
    double? gstRate,
    String? imageUrl,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      hsnSac: hsnSac ?? this.hsnSac,
      itemType: itemType ?? this.itemType,
      unit: unit ?? this.unit,
      price: price ?? this.price,
      gstRate: gstRate ?? this.gstRate,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
