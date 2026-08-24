class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String billingAddress;
  final String shippingAddress;
  final String city;
  final String state;
  final String stateCode;
  final String pincode;
  final String gstin;
  final String pan;
  final String customerType; // 'REGISTERED_B2B' or 'UNREGISTERED_B2C'

  CustomerModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.billingAddress = '',
    this.shippingAddress = '',
    this.city = '',
    required this.state,
    this.stateCode = '',
    this.pincode = '',
    this.gstin = '',
    this.pan = '',
    this.customerType = 'UNREGISTERED_B2C',
  });

  bool get isRegistered => customerType == 'REGISTERED_B2B' || gstin.trim().isNotEmpty;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      billingAddress: json['billingAddress']?.toString() ?? '',
      shippingAddress: json['shippingAddress']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? 'Andhra Pradesh',
      stateCode: json['stateCode']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? '',
      pan: json['pan']?.toString() ?? '',
      customerType: json['customerType']?.toString() ?? 'UNREGISTERED_B2C',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'billingAddress': billingAddress,
      'shippingAddress': shippingAddress,
      'city': city,
      'state': state,
      'stateCode': stateCode,
      'pincode': pincode,
      'gstin': gstin,
      'pan': pan,
      'customerType': customerType,
    };
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? billingAddress,
    String? shippingAddress,
    String? city,
    String? state,
    String? stateCode,
    String? pincode,
    String? gstin,
    String? pan,
    String? customerType,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      pincode: pincode ?? this.pincode,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      customerType: customerType ?? this.customerType,
    );
  }
}
