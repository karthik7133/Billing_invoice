class BankDetails {
  final String bankName;
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String branch;
  final String upiId;

  BankDetails({
    this.bankName = '',
    this.accountHolderName = '',
    this.accountNumber = '',
    this.ifscCode = '',
    this.branch = '',
    this.upiId = '',
  });

  factory BankDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return BankDetails();
    return BankDetails(
      bankName: json['bankName']?.toString() ?? '',
      accountHolderName: json['accountHolderName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      ifscCode: json['ifscCode']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      upiId: json['upiId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bankName': bankName,
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode,
      'branch': branch,
      'upiId': upiId,
    };
  }

  BankDetails copyWith({
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? branch,
    String? upiId,
  }) {
    return BankDetails(
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      branch: branch ?? this.branch,
      upiId: upiId ?? this.upiId,
    );
  }
}

class BusinessModel {
  final String id;
  final String businessName;
  final String logo;
  final String phone;
  final String email;
  final String address;
  final String city;
  final String state;
  final String stateCode;
  final String pincode;
  final String gstin;
  final String pan;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final BankDetails bankDetails;
  final String termsAndConditions;
  final String signatureUrl;

  BusinessModel({
    required this.id,
    required this.businessName,
    this.logo = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.city = '',
    this.state = 'Andhra Pradesh',
    this.stateCode = '37',
    this.pincode = '',
    this.gstin = '',
    this.pan = '',
    this.invoicePrefix = 'INV',
    this.nextInvoiceNumber = 1,
    BankDetails? bankDetails,
    this.termsAndConditions = '1. Goods once sold will not be taken back.\n2. Payment due within 15 days.',
    this.signatureUrl = '',
  }) : bankDetails = bankDetails ?? BankDetails();

  factory BusinessModel.fromJson(Map<String, dynamic> json) {
    return BusinessModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      businessName: json['businessName']?.toString() ?? 'My Business',
      logo: json['logo']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? 'Andhra Pradesh',
      stateCode: json['stateCode']?.toString() ?? '37',
      pincode: json['pincode']?.toString() ?? '',
      gstin: json['gstin']?.toString() ?? '',
      pan: json['pan']?.toString() ?? '',
      invoicePrefix: json['invoicePrefix']?.toString() ?? 'INV',
      nextInvoiceNumber: (json['nextInvoiceNumber'] as num?)?.toInt() ?? 1,
      bankDetails: BankDetails.fromJson(json['bankDetails'] as Map<String, dynamic>?),
      termsAndConditions: json['termsAndConditions']?.toString() ?? '',
      signatureUrl: json['signatureUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'logo': logo,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'stateCode': stateCode,
      'pincode': pincode,
      'gstin': gstin,
      'pan': pan,
      'invoicePrefix': invoicePrefix,
      'nextInvoiceNumber': nextInvoiceNumber,
      'bankDetails': bankDetails.toJson(),
      'termsAndConditions': termsAndConditions,
      'signatureUrl': signatureUrl,
    };
  }

  BusinessModel copyWith({
    String? id,
    String? businessName,
    String? logo,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? stateCode,
    String? pincode,
    String? gstin,
    String? pan,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    BankDetails? bankDetails,
    String? termsAndConditions,
    String? signatureUrl,
  }) {
    return BusinessModel(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      logo: logo ?? this.logo,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      pincode: pincode ?? this.pincode,
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      bankDetails: bankDetails ?? this.bankDetails,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      signatureUrl: signatureUrl ?? this.signatureUrl,
    );
  }
}
