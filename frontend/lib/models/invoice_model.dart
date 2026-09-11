import 'customer_model.dart';
import 'business_model.dart';

class InvoiceItemModel {
  final String? productId;
  final String name;
  final String description;
  final String hsnSac;
  final String unit;
  final double quantity;
  final double rate;
  final double grossAmount;
  final double discount;
  final String discountType; // 'FIXED' or 'PERCENT'
  final double discountAmount;
  final double taxableAmount;
  final double gstRate;
  final double cgstRate;
  final double sgstRate;
  final double igstRate;
  final double cgst;
  final double sgst;
  final double igst;
  final double totalTax;
  final double total;

  InvoiceItemModel({
    this.productId,
    required this.name,
    this.description = '',
    this.hsnSac = '',
    this.unit = 'PCS',
    required this.quantity,
    required this.rate,
    required this.grossAmount,
    this.discount = 0,
    this.discountType = 'FIXED',
    this.discountAmount = 0,
    required this.taxableAmount,
    required this.gstRate,
    this.cgstRate = 0,
    this.sgstRate = 0,
    this.igstRate = 0,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.totalTax = 0,
    required this.total,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      productId: json['productId']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      hsnSac: json['hsnSac']?.toString() ?? '',
      unit: json['unit']?.toString() ?? 'PCS',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      grossAmount: (json['grossAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountType: json['discountType']?.toString() ?? 'FIXED',
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      gstRate: (json['gstRate'] as num?)?.toDouble() ?? 18.0,
      cgstRate: (json['cgstRate'] as num?)?.toDouble() ?? 0.0,
      sgstRate: (json['sgstRate'] as num?)?.toDouble() ?? 0.0,
      igstRate: (json['igstRate'] as num?)?.toDouble() ?? 0.0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'name': name,
      'description': description,
      'hsnSac': hsnSac,
      'unit': unit,
      'quantity': quantity,
      'rate': rate,
      'grossAmount': grossAmount,
      'discount': discount,
      'discountType': discountType,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'gstRate': gstRate,
      'cgstRate': cgstRate,
      'sgstRate': sgstRate,
      'igstRate': igstRate,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'totalTax': totalTax,
      'total': total,
    };
  }
}

class PaymentRecord {
  final String? id;
  final double amount;
  final String type; // 'Cash', 'Bank Transfer', 'UPI', 'Cheque', 'IMPS', or custom
  final DateTime date;
  final String notes;

  PaymentRecord({
    this.id,
    required this.amount,
    this.type = 'Cash',
    required this.date,
    this.notes = '',
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type']?.toString() ?? 'Cash',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      notes: json['notes']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      if (id != null) 'id': id,
      'amount': amount,
      'type': type,
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  PaymentRecord copyWith({
    String? id,
    double? amount,
    String? type,
    DateTime? date,
    String? notes,
  }) {
    return PaymentRecord(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final CustomerModel customerSnapshot;
  final BusinessModel businessSnapshot;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final String origin; // e.g. 'AP', 'ORRISA', 'GUJARAT', 'KARNATAKA'
  final List<String> attachments; // Cloudinary URLs
  final List<InvoiceItemModel> items;
  final List<PaymentRecord> payments;
  final bool isDeleted;
  final DateTime? deletedAt;
  final bool isInterState;
  final double subtotal;
  final double itemsDiscount;
  final double extraDiscount;
  final double totalDiscount;
  final double taxableAmount;
  final double cgst;
  final double sgst;
  final double igst;
  final double totalTax;
  final double otherCharges;
  final double roundOff;
  final double grandTotal;
  final double amountPaid;
  final double balanceDue;
  final double excessAmount;
  final String paymentType; // 'Cash', 'Bank Transfer', 'UPI', 'Cheque'
  final String description;
  final String status; // 'DRAFT', 'ISSUED', 'PAID', 'PARTIALLY_PAID', 'CANCELLED'
  final String notes;
  final String termsAndConditions;
  final String amountInWords;
  final String pdfUrl;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.customerSnapshot,
    required this.businessSnapshot,
    required this.invoiceDate,
    required this.dueDate,
    this.origin = 'AP',
    this.attachments = const [],
    required this.items,
    this.payments = const [],
    this.isDeleted = false,
    this.deletedAt,
    this.isInterState = false,
    required this.subtotal,
    this.itemsDiscount = 0,
    this.extraDiscount = 0,
    this.totalDiscount = 0,
    required this.taxableAmount,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.totalTax = 0,
    this.otherCharges = 0,
    this.roundOff = 0,
    required this.grandTotal,
    this.amountPaid = 0,
    this.balanceDue = 0,
    this.excessAmount = 0,
    this.paymentType = 'Cash',
    this.description = '',
    this.status = 'ISSUED',
    this.notes = '',
    this.termsAndConditions = '',
    this.amountInWords = '',
    this.pdfUrl = '',
  });

  double get totalReceived => payments.isNotEmpty
      ? payments.fold(0.0, (sum, p) => sum + p.amount)
      : amountPaid;

  bool get isPaid => status == 'PAID' || balanceDue <= 0 || (grandTotal > 0 && totalReceived >= grandTotal);
  bool get hasOverMoney => excessAmount > 0 || (totalReceived > grandTotal && grandTotal > 0);
  double get overMoneyAmount => excessAmount > 0
      ? excessAmount
      : (totalReceived > grandTotal ? totalReceived - grandTotal : 0.0);

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    List<InvoiceItemModel> parsedItems = rawItems
        .map((it) => InvoiceItemModel.fromJson(it as Map<String, dynamic>))
        .toList();

    CustomerModel custSnap;
    if (json['customerSnapshot'] != null) {
      custSnap = CustomerModel.fromJson(json['customerSnapshot'] as Map<String, dynamic>);
    } else {
      custSnap = CustomerModel(id: '', name: 'Customer', state: 'Andhra Pradesh');
    }

    BusinessModel busSnap;
    if (json['businessSnapshot'] != null) {
      busSnap = BusinessModel.fromJson(json['businessSnapshot'] as Map<String, dynamic>);
    } else {
      busSnap = BusinessModel(id: '', businessName: 'My Business');
    }

    DateTime invDate = DateTime.tryParse(json['invoiceDate']?.toString() ?? '') ?? DateTime.now();
    DateTime due = DateTime.tryParse(json['dueDate']?.toString() ?? '') ??
        invDate.add(const Duration(days: 15));

    final gTotal = (json['grandTotal'] as num?)?.toDouble() ?? 0.0;
    final aPaid = (json['amountPaid'] as num?)?.toDouble() ?? 0.0;
    final bDue = (json['balanceDue'] as num?)?.toDouble() ?? 0.0;
    final exAmount = (json['excessAmount'] as num?)?.toDouble() ?? (aPaid > gTotal ? aPaid - gTotal : 0.0);

    var rawAttachments = json['attachments'] as List<dynamic>? ?? [];
    List<String> parsedAttachments = rawAttachments.map((a) => a.toString()).toList();

    var rawPayments = json['payments'] as List<dynamic>? ?? [];
    List<PaymentRecord> parsedPayments = rawPayments
        .map((p) => PaymentRecord.fromJson(p as Map<String, dynamic>))
        .toList();

    // Backward compatibility: If no payments array but amountPaid > 0, synthesize a payment record
    if (parsedPayments.isEmpty && aPaid > 0) {
      parsedPayments = [
        PaymentRecord(
          amount: aPaid,
          type: json['paymentType']?.toString() ?? 'Cash',
          date: invDate,
        )
      ];
    }

    final isDel = json['isDeleted'] == true;
    final delAt = DateTime.tryParse(json['deletedAt']?.toString() ?? '');

    return InvoiceModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString() ?? 'INV-0001',
      customerId: json['customerId']?.toString() ?? '',
      customerSnapshot: custSnap,
      businessSnapshot: busSnap,
      invoiceDate: invDate,
      dueDate: due,
      origin: json['origin']?.toString() ?? 'AP',
      attachments: parsedAttachments,
      items: parsedItems,
      payments: parsedPayments,
      isDeleted: isDel,
      deletedAt: delAt,
      isInterState: json['isInterState'] == true,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      itemsDiscount: (json['itemsDiscount'] as num?)?.toDouble() ?? 0.0,
      extraDiscount: (json['extraDiscount'] as num?)?.toDouble() ?? 0.0,
      totalDiscount: (json['totalDiscount'] as num?)?.toDouble() ?? 0.0,
      taxableAmount: (json['taxableAmount'] as num?)?.toDouble() ?? 0.0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (json['igst'] as num?)?.toDouble() ?? 0.0,
      totalTax: (json['totalTax'] as num?)?.toDouble() ?? 0.0,
      otherCharges: (json['otherCharges'] as num?)?.toDouble() ?? 0.0,
      roundOff: (json['roundOff'] as num?)?.toDouble() ?? 0.0,
      grandTotal: gTotal,
      amountPaid: aPaid,
      balanceDue: bDue,
      excessAmount: exAmount,
      paymentType: json['paymentType']?.toString() ?? (parsedPayments.isNotEmpty ? parsedPayments.first.type : 'Cash'),
      description: json['description']?.toString() ?? json['notes']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ISSUED',
      notes: json['notes']?.toString() ?? '',
      termsAndConditions: json['termsAndConditions']?.toString() ?? '',
      amountInWords: json['amountInWords']?.toString() ?? '',
      pdfUrl: json['pdfUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      '_id': id,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'customerSnapshot': customerSnapshot.toJson(),
      'businessSnapshot': businessSnapshot.toJson(),
      'invoiceDate': invoiceDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'origin': origin,
      'attachments': attachments,
      'items': items.map((i) => i.toJson()).toList(),
      'payments': payments.map((p) => p.toJson()).toList(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'isInterState': isInterState,
      'subtotal': subtotal,
      'itemsDiscount': itemsDiscount,
      'extraDiscount': extraDiscount,
      'totalDiscount': totalDiscount,
      'taxableAmount': taxableAmount,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'totalTax': totalTax,
      'otherCharges': otherCharges,
      'roundOff': roundOff,
      'grandTotal': grandTotal,
      'amountPaid': amountPaid,
      'balanceDue': balanceDue,
      'excessAmount': excessAmount,
      'paymentType': paymentType,
      'description': description,
      'status': status,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
      'amountInWords': amountInWords,
      'pdfUrl': pdfUrl,
    };
  }

  InvoiceModel copyWith({
    String? id,
    String? invoiceNumber,
    String? customerId,
    CustomerModel? customerSnapshot,
    BusinessModel? businessSnapshot,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? origin,
    List<String>? attachments,
    List<InvoiceItemModel>? items,
    List<PaymentRecord>? payments,
    bool? isDeleted,
    DateTime? deletedAt,
    bool? isInterState,
    double? subtotal,
    double? itemsDiscount,
    double? extraDiscount,
    double? totalDiscount,
    double? taxableAmount,
    double? cgst,
    double? sgst,
    double? igst,
    double? totalTax,
    double? otherCharges,
    double? roundOff,
    double? grandTotal,
    double? amountPaid,
    double? balanceDue,
    double? excessAmount,
    String? paymentType,
    String? description,
    String? status,
    String? notes,
    String? termsAndConditions,
    String? amountInWords,
    String? pdfUrl,
  }) {
    return InvoiceModel(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      customerId: customerId ?? this.customerId,
      customerSnapshot: customerSnapshot ?? this.customerSnapshot,
      businessSnapshot: businessSnapshot ?? this.businessSnapshot,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      dueDate: dueDate ?? this.dueDate,
      origin: origin ?? this.origin,
      attachments: attachments ?? this.attachments,
      items: items ?? this.items,
      payments: payments ?? this.payments,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      isInterState: isInterState ?? this.isInterState,
      subtotal: subtotal ?? this.subtotal,
      itemsDiscount: itemsDiscount ?? this.itemsDiscount,
      extraDiscount: extraDiscount ?? this.extraDiscount,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
      totalTax: totalTax ?? this.totalTax,
      otherCharges: otherCharges ?? this.otherCharges,
      roundOff: roundOff ?? this.roundOff,
      grandTotal: grandTotal ?? this.grandTotal,
      amountPaid: amountPaid ?? this.amountPaid,
      balanceDue: balanceDue ?? this.balanceDue,
      excessAmount: excessAmount ?? this.excessAmount,
      paymentType: paymentType ?? this.paymentType,
      description: description ?? this.description,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      amountInWords: amountInWords ?? this.amountInWords,
      pdfUrl: pdfUrl ?? this.pdfUrl,
    );
  }
}
