class ItemGstResult {
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

  ItemGstResult({
    required this.quantity,
    required this.rate,
    required this.grossAmount,
    required this.discount,
    required this.discountType,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstRate,
    required this.cgstRate,
    required this.sgstRate,
    required this.igstRate,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.totalTax,
    required this.total,
  });
}

class InvoiceTotalsResult {
  final bool isInterState;
  final List<ItemGstResult> items;
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

  InvoiceTotalsResult({
    required this.isInterState,
    required this.items,
    required this.subtotal,
    required this.itemsDiscount,
    required this.extraDiscount,
    required this.totalDiscount,
    required this.taxableAmount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.totalTax,
    required this.otherCharges,
    required this.roundOff,
    required this.grandTotal,
  });
}

class GstCalculator {
  static ItemGstResult calculateItemGST({
    required double quantity,
    required double rate,
    double discount = 0,
    String discountType = 'FIXED',
    required double gstRate,
    required bool isInterState,
  }) {
    final qty = quantity > 0 ? quantity : 1.0;
    final unitRate = rate >= 0 ? rate : 0.0;
    final taxPercent = gstRate >= 0 ? gstRate : 0.0;

    final grossAmount = double.parse((qty * unitRate).toStringAsFixed(2));

    double discountAmount = 0.0;
    if (discountType == 'PERCENT') {
      discountAmount = double.parse(((grossAmount * discount) / 100).toStringAsFixed(2));
    } else {
      discountAmount = double.parse(discount.toStringAsFixed(2));
    }
    discountAmount = discountAmount.clamp(0.0, grossAmount);

    final taxableAmount = double.parse((grossAmount - discountAmount).toStringAsFixed(2));

    double cgstRate = 0;
    double sgstRate = 0;
    double igstRate = 0;
    double cgst = 0;
    double sgst = 0;
    double igst = 0;

    if (isInterState) {
      igstRate = taxPercent;
      igst = double.parse(((taxableAmount * igstRate) / 100).toStringAsFixed(2));
    } else {
      cgstRate = double.parse((taxPercent / 2).toStringAsFixed(2));
      sgstRate = double.parse((taxPercent / 2).toStringAsFixed(2));
      cgst = double.parse(((taxableAmount * cgstRate) / 100).toStringAsFixed(2));
      sgst = double.parse(((taxableAmount * sgstRate) / 100).toStringAsFixed(2));
    }

    final totalTax = double.parse((cgst + sgst + igst).toStringAsFixed(2));
    final total = double.parse((taxableAmount + totalTax).toStringAsFixed(2));

    return ItemGstResult(
      quantity: qty,
      rate: unitRate,
      grossAmount: grossAmount,
      discount: discount,
      discountType: discountType,
      discountAmount: discountAmount,
      taxableAmount: taxableAmount,
      gstRate: taxPercent,
      cgstRate: cgstRate,
      sgstRate: sgstRate,
      igstRate: igstRate,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      totalTax: totalTax,
      total: total,
    );
  }

  static InvoiceTotalsResult calculateInvoiceTotals({
    required List<Map<String, dynamic>> items,
    required String sellerState,
    required String buyerState,
    double invoiceDiscount = 0,
    String invoiceDiscountType = 'FIXED',
    double otherCharges = 0,
  }) {
    final cleanSeller = sellerState.trim().toLowerCase();
    final cleanBuyer = buyerState.trim().toLowerCase();

    final isInterState = cleanSeller.isNotEmpty && cleanBuyer.isNotEmpty && cleanSeller != cleanBuyer;

    final processedItems = <ItemGstResult>[];

    for (final it in items) {
      final res = calculateItemGST(
        quantity: (it['quantity'] as num?)?.toDouble() ?? 1.0,
        rate: (it['rate'] as num?)?.toDouble() ?? 0.0,
        discount: (it['discount'] as num?)?.toDouble() ?? 0.0,
        discountType: it['discountType']?.toString() ?? 'FIXED',
        gstRate: (it['gstRate'] as num?)?.toDouble() ?? 18.0,
        isInterState: isInterState,
      );
      processedItems.add(res);
    }

    final subtotal = double.parse(
      processedItems.fold<double>(0.0, (acc, it) => acc + it.grossAmount).toStringAsFixed(2),
    );

    final itemsDiscount = double.parse(
      processedItems.fold<double>(0.0, (acc, it) => acc + it.discountAmount).toStringAsFixed(2),
    );

    double extraDiscount = 0.0;
    if (invoiceDiscountType == 'PERCENT') {
      extraDiscount = double.parse(((subtotal * invoiceDiscount) / 100).toStringAsFixed(2));
    } else {
      extraDiscount = double.parse(invoiceDiscount.toStringAsFixed(2));
    }

    final totalDiscount = double.parse((itemsDiscount + extraDiscount).toStringAsFixed(2));

    final taxableAmount = double.parse(
      processedItems.fold<double>(0.0, (acc, it) => acc + it.taxableAmount).toStringAsFixed(2),
    );

    final cgst = double.parse(
      processedItems.fold<double>(0.0, (acc, it) => acc + it.cgst).toStringAsFixed(2),
    );
    final sgst = double.parse(
      processedItems.fold<double>(0.0, (acc, it) => acc + it.sgst).toStringAsFixed(2),
    );
    final igst = double.parse(
      processedItems.fold<double>(0.0, (acc, it) => acc + it.igst).toStringAsFixed(2),
    );

    final totalTax = double.parse((cgst + sgst + igst).toStringAsFixed(2));
    final charges = double.parse(otherCharges.toStringAsFixed(2));

    final rawTotal = double.parse((taxableAmount + totalTax + charges - extraDiscount).toStringAsFixed(2));
    final grandTotal = rawTotal.roundToDouble();
    final roundOff = double.parse((grandTotal - rawTotal).toStringAsFixed(2));

    return InvoiceTotalsResult(
      isInterState: isInterState,
      items: processedItems,
      subtotal: subtotal,
      itemsDiscount: itemsDiscount,
      extraDiscount: extraDiscount,
      totalDiscount: totalDiscount,
      taxableAmount: taxableAmount,
      cgst: cgst,
      sgst: sgst,
      igst: igst,
      totalTax: totalTax,
      otherCharges: charges,
      roundOff: roundOff,
      grandTotal: grandTotal,
    );
  }
}
