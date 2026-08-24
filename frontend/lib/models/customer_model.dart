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
  final String billingName;
  final double openingBalance;
  final double balance; // Positive = Receivable ("You'll Get"), Negative = Payable ("You'll Give")
  final String partyType; // 'CUSTOMER' or 'SUPPLIER'
  final String customerType; // 'REGISTERED_B2B' or 'UNREGISTERED_B2C'
  final DateTime? lastTransactionDate;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone = '',
    this.email = '',
    this.billingAddress = '',
    this.shippingAddress = '',
    this.city = '',
    this.state = 'Andhra Pradesh',
    this.stateCode = '',
    this.pincode = '',
    this.gstin = '',
    this.pan = '',
    this.billingName = '',
    this.openingBalance = 0.0,
    this.balance = 0.0,
    this.partyType = 'CUSTOMER',
    this.customerType = 'UNREGISTERED_B2C',
    this.lastTransactionDate,
  });

  bool get isRegistered => customerType == 'REGISTERED_B2B' || gstin.trim().isNotEmpty;
  bool get isReceivable => balance > 0;
  bool get isPayable => balance < 0;
  bool get isSettled => balance == 0;

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    DateTime? lastTxDate;
    if (json['lastTransactionDate'] != null) {
      try {
        lastTxDate = DateTime.parse(json['lastTransactionDate'].toString());
      } catch (_) {}
    } else if (json['updatedAt'] != null) {
      try {
        lastTxDate = DateTime.parse(json['updatedAt'].toString());
      } catch (_) {}
    }

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
      billingName: json['billingName']?.toString() ?? json['name']?.toString() ?? '',
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble() ?? (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
      partyType: json['partyType']?.toString() ?? 'CUSTOMER',
      customerType: json['customerType']?.toString() ?? 'UNREGISTERED_B2C',
      lastTransactionDate: lastTxDate,
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
      'billingName': billingName.isNotEmpty ? billingName : name,
      'openingBalance': openingBalance,
      'partyType': partyType,
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
    String? billingName,
    double? openingBalance,
    double? balance,
    String? partyType,
    String? customerType,
    DateTime? lastTransactionDate,
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
      billingName: billingName ?? this.billingName,
      openingBalance: openingBalance ?? this.openingBalance,
      balance: balance ?? this.balance,
      partyType: partyType ?? this.partyType,
      customerType: customerType ?? this.customerType,
      lastTransactionDate: lastTransactionDate ?? this.lastTransactionDate,
    );
  }
}
