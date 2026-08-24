import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice_model.dart';
import '../models/customer_model.dart';
import '../models/business_model.dart';
import '../models/dashboard_stats_model.dart';
import '../core/utils/gst_calculator.dart';
import '../core/utils/number_to_words.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';

class InvoiceProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final _uuid = const Uuid();

  List<InvoiceModel> _invoices = [];
  bool _isLoading = false;
  String? _errorMessage;

  String _statusFilter = 'ALL';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  List<InvoiceModel> get invoices {

    return _invoices.where((inv) {
      // Status filter
      if (_statusFilter != 'ALL') {
        if (_statusFilter == 'UNPAID') {
          if (inv.status != 'ISSUED' && inv.status != 'PARTIALLY_PAID') return false;
        } else if (inv.status != _statusFilter) {
          return false;
        }
      }

      // Date filter
      if (_startDate != null) {
        if (inv.invoiceDate.isBefore(_startDate!)) return false;
      }
      if (_endDate != null) {
        final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        if (inv.invoiceDate.isAfter(endOfDay)) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final num = inv.invoiceNumber.toLowerCase();
        final cust = inv.customerSnapshot.name.toLowerCase();
        return num.contains(q) || cust.contains(q);
      }

      return true;
    }).toList();
  }

  String get statusFilter => _statusFilter;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setStatusFilter(String status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setSearchQuery(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    notifyListeners();
  }

  DashboardMetrics getDashboardMetrics() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfMonth = DateTime(now.year, now.month, 1);

    double todaySales = 0;
    double monthSales = 0;
    double totalSales = 0;
    double totalUnpaid = 0;
    int paidCount = 0;
    int unpaidCount = 0;
    int draftCount = 0;

    for (final inv in _invoices) {
      if (inv.status == 'CANCELLED') continue;

      if (inv.invoiceDate.isAfter(startOfToday.subtract(const Duration(seconds: 1)))) {
        todaySales += inv.grandTotal;
      }
      if (inv.invoiceDate.isAfter(startOfMonth.subtract(const Duration(seconds: 1)))) {
        monthSales += inv.grandTotal;
      }
      totalSales += inv.grandTotal;
      totalUnpaid += inv.balanceDue;

      if (inv.status == 'PAID') paidCount++;
      if (inv.status == 'ISSUED' || inv.status == 'PARTIALLY_PAID') unpaidCount++;
      if (inv.status == 'DRAFT') draftCount++;
    }

    return DashboardMetrics(
      todaySales: todaySales,
      monthSales: monthSales,
      totalSales: totalSales,
      totalUnpaid: totalUnpaid,
      totalInvoices: _invoices.length,
      paidCount: paidCount,
      unpaidCount: unpaidCount,
      draftCount: draftCount,
    );
  }

  Future<void> fetchInvoices() async {
    _isLoading = true;
    notifyListeners();

    final res = await _api.get(Endpoints.invoices);
    _isLoading = false;

    if (res.success && res.data != null && res.data['invoices'] != null) {
      final list = (res.data['invoices'] as List)
          .map((i) => InvoiceModel.fromJson(i as Map<String, dynamic>))
          .toList();
      _invoices = list;
    }
    notifyListeners();
  }

  Future<InvoiceModel> createInvoice({
    required CustomerModel customer,
    required BusinessModel business,
    required List<Map<String, dynamic>> rawItems,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    double invoiceDiscount = 0,
    String invoiceDiscountType = 'FIXED',
    double otherCharges = 0,
    String status = 'ISSUED',
    double amountPaid = 0,
    String notes = '',
    String termsAndConditions = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    final date = invoiceDate ?? DateTime.now();
    final due = dueDate ?? date.add(const Duration(days: 15));

    final calculated = GstCalculator.calculateInvoiceTotals(
      items: rawItems,
      sellerState: business.state,
      buyerState: customer.state,
      invoiceDiscount: invoiceDiscount,
      invoiceDiscountType: invoiceDiscountType,
      otherCharges: otherCharges,
    );

    final finalInvNum = invoiceNumber ??
        '${business.invoicePrefix}-${business.nextInvoiceNumber.toString().padLeft(4, '0')}';

    final paid = amountPaid;
    final balance = (calculated.grandTotal - paid).clamp(0.0, calculated.grandTotal);

    String finalStatus = status;
    if (paid >= calculated.grandTotal && calculated.grandTotal > 0) {
      finalStatus = 'PAID';
    } else if (paid > 0 && paid < calculated.grandTotal) {
      finalStatus = 'PARTIALLY_PAID';
    }

    final words = NumberToWords.convertToIndianWords(calculated.grandTotal);

    final parsedItems = <InvoiceItemModel>[];
    for (int i = 0; i < calculated.items.length; i++) {
      final it = calculated.items[i];
      final raw = rawItems[i];
      parsedItems.add(
        InvoiceItemModel(
          productId: raw['productId']?.toString(),
          name: raw['name']?.toString() ?? 'Item ${i + 1}',
          description: raw['description']?.toString() ?? '',
          hsnSac: raw['hsnSac']?.toString() ?? '',
          unit: raw['unit']?.toString() ?? 'PCS',
          quantity: it.quantity,
          rate: it.rate,
          grossAmount: it.grossAmount,
          discount: it.discount,
          discountType: it.discountType,
          discountAmount: it.discountAmount,
          taxableAmount: it.taxableAmount,
          gstRate: it.gstRate,
          cgstRate: it.cgstRate,
          sgstRate: it.sgstRate,
          igstRate: it.igstRate,
          cgst: it.cgst,
          sgst: it.sgst,
          igst: it.igst,
          totalTax: it.totalTax,
          total: it.total,
        ),
      );
    }

    final invoice = InvoiceModel(
      id: _uuid.v4(),
      invoiceNumber: finalInvNum,
      customerId: customer.id,
      customerSnapshot: customer,
      businessSnapshot: business,
      invoiceDate: date,
      dueDate: due,
      items: parsedItems,
      isInterState: calculated.isInterState,
      subtotal: calculated.subtotal,
      itemsDiscount: calculated.itemsDiscount,
      extraDiscount: calculated.extraDiscount,
      totalDiscount: calculated.totalDiscount,
      taxableAmount: calculated.taxableAmount,
      cgst: calculated.cgst,
      sgst: calculated.sgst,
      igst: calculated.igst,
      totalTax: calculated.totalTax,
      otherCharges: calculated.otherCharges,
      roundOff: calculated.roundOff,
      grandTotal: calculated.grandTotal,
      amountPaid: paid,
      balanceDue: balance,
      status: finalStatus,
      notes: notes.isNotEmpty ? notes : 'Thank you for your business!',
      termsAndConditions: termsAndConditions.isNotEmpty ? termsAndConditions : business.termsAndConditions,
      amountInWords: words,
    );

    // Save to API in background if possible
    _api.post(Endpoints.invoices, {
      'customerId': customer.id,
      'invoiceNumber': finalInvNum,
      'invoiceDate': date.toIso8601String(),
      'dueDate': due.toIso8601String(),
      'items': rawItems,
      'invoiceDiscount': invoiceDiscount,
      'invoiceDiscountType': invoiceDiscountType,
      'otherCharges': otherCharges,
      'status': finalStatus,
      'amountPaid': paid,
      'notes': notes,
      'termsAndConditions': termsAndConditions,
    });

    _invoices.insert(0, invoice);
    _isLoading = false;
    notifyListeners();
    return invoice;
  }

  Future<void> markInvoiceAsPaid(String invoiceId) async {
    final index = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (index != -1) {
      final old = _invoices[index];
      _invoices[index] = old.copyWith(
        amountPaid: old.grandTotal,
        balanceDue: 0,
        status: 'PAID',
      );
      _api.post('${Endpoints.invoices}/$invoiceId/mark-paid', {});
      notifyListeners();
    }
  }

  Future<void> updatePayment(String invoiceId, double paidAmount) async {
    final index = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (index != -1) {
      final old = _invoices[index];
      final newPaid = paidAmount;
      final newBalance = (old.grandTotal - newPaid).clamp(0.0, old.grandTotal);
      String newStatus = old.status;
      if (newPaid >= old.grandTotal) {
        newStatus = 'PAID';
      } else if (newPaid > 0) {
        newStatus = 'PARTIALLY_PAID';
      }

      _invoices[index] = old.copyWith(
        amountPaid: newPaid,
        balanceDue: newBalance,
        status: newStatus,
      );

      _api.put('${Endpoints.invoices}/$invoiceId/status', {
        'amountPaid': newPaid,
        'status': newStatus,
      });
      notifyListeners();
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    _invoices.removeWhere((inv) => inv.id == invoiceId);
    _api.delete('${Endpoints.invoices}/$invoiceId');
    notifyListeners();
  }
}

