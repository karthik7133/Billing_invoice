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
import '../services/local_cache_service.dart';

class InvoiceProvider with ChangeNotifier {
  final ApiClient _api = ApiClient();
  final LocalCacheService _cache = LocalCacheService();
  final _uuid = const Uuid();

  List<InvoiceModel> _invoices = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  String _statusFilter = 'ALL';
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  InvoiceProvider() {
    _initFromCache();
  }

  Future<void> _initFromCache() async {
    if (_isInitialized) return;
    final cached = await _cache.loadInvoices();
    if (cached.isNotEmpty && _invoices.isEmpty) {
      _invoices = cached;
      notifyListeners();
    }
    _isInitialized = true;
  }

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

  /// Unfiltered full list — use this when you need to find a specific invoice
  /// regardless of current search/filter state (e.g. in InvoiceDetailScreen).
  List<InvoiceModel> get allInvoices => List.unmodifiable(_invoices);

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
    await _initFromCache();
    _isLoading = true;
    notifyListeners();

    final res = await _api.get(Endpoints.invoices);
    _isLoading = false;

    if (res.success && res.data != null && res.data['invoices'] != null) {
      final list = (res.data['invoices'] as List)
          .map((i) => InvoiceModel.fromJson(i as Map<String, dynamic>))
          .toList();
      _invoices = list;
      await _cache.saveInvoices(_invoices);
    }
    notifyListeners();
  }

  List<InvoiceModel> getInvoicesForCustomer(String customerId) {
    return _invoices.where((i) => i.customerId == customerId || i.customerSnapshot.id == customerId).toList();
  }

  Future<InvoiceModel> createInvoice({
    required CustomerModel customer,
    required BusinessModel business,
    required List<Map<String, dynamic>> rawItems,
    String? invoiceNumber,
    DateTime? invoiceDate,
    DateTime? dueDate,
    String origin = 'AP',
    List<String> attachments = const [],
    double invoiceDiscount = 0,
    String invoiceDiscountType = 'FIXED',
    double otherCharges = 0,
    String status = 'ISSUED',
    double amountPaid = 0,
    String paymentType = 'Cash',
    String description = '',
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

    final finalInvNum = (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        ? invoiceNumber.trim()
        : '${business.invoicePrefix}-${business.nextInvoiceNumber.toString().padLeft(4, '0')}';

    final paid = amountPaid;
    final balance = (calculated.grandTotal - paid).clamp(0.0, calculated.grandTotal);
    final excess = paid > calculated.grandTotal ? paid - calculated.grandTotal : 0.0;

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
      origin: origin,
      attachments: attachments,
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
      excessAmount: excess,
      paymentType: paymentType,
      description: description.isNotEmpty ? description : notes,
      status: finalStatus,
      notes: notes.isNotEmpty ? notes : (description.isNotEmpty ? description : 'Thank you for your business!'),
      termsAndConditions: termsAndConditions.isNotEmpty ? termsAndConditions : business.termsAndConditions,
      amountInWords: words,
    );

    InvoiceModel finalInvoice = invoice;

    try {
      // Save to API
      final res = await _api.post(Endpoints.invoices, {
        'customerId': customer.id,
        'customerName': customer.name,
        'invoiceNumber': finalInvNum,
        'invoiceDate': date.toIso8601String(),
        'dueDate': due.toIso8601String(),
        'origin': origin,
        'attachments': attachments,
        'items': rawItems,
        'invoiceDiscount': invoiceDiscount,
        'invoiceDiscountType': invoiceDiscountType,
        'otherCharges': otherCharges,
        'status': finalStatus,
        'amountPaid': paid,
        'paymentType': paymentType,
        'description': description,
        'notes': notes,
        'termsAndConditions': termsAndConditions,
      });

      if (res.success && res.data != null && res.data['invoice'] != null) {
        finalInvoice = InvoiceModel.fromJson(res.data['invoice'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('[InvoiceProvider] createInvoice error: $e');
    }

    _invoices.insert(0, finalInvoice);
    await _cache.saveInvoices(_invoices);
    _isLoading = false;
    notifyListeners();
    return finalInvoice;
  }

  /// Upload photo/attachment to Cloudinary via backend /api/upload
  Future<String?> uploadAttachment(dynamic file) async {
    try {
      ApiResponse res;
      if (file.path != null && file.path.isNotEmpty) {
        res = await _api.uploadFile(Endpoints.upload, file.path);
      } else {
        final bytes = await file.readAsBytes();
        res = await _api.uploadBytes(Endpoints.upload, bytes, file.name);
      }

      if (res.success && res.data != null && res.data['url'] != null) {
        return res.data['url'].toString();
      }
    } catch (e) {
      debugPrint('[InvoiceProvider] uploadAttachment error: $e');
    }
    return null;
  }

  Future<bool> updateInvoiceNumber(String invoiceId, String newNumber) async {
    final cleanNum = newNumber.trim();
    if (cleanNum.isEmpty) return false;

    // Find by id first, then fallback to id contained in any invoice
    int index = _invoices.indexWhere((inv) => inv.id == invoiceId);
    if (index == -1) return false;

    final oldInvoiceNumber = _invoices[index].invoiceNumber;

    // Optimistically update locally first
    _invoices[index] = _invoices[index].copyWith(invoiceNumber: cleanNum);
    await _cache.saveInvoices(_invoices);
    notifyListeners();

    try {
      // Try PUT by id first (works when id is a real MongoDB _id)
      ApiResponse res = await _api.put('${Endpoints.invoices}/$invoiceId', {
        'invoiceNumber': cleanNum,
      });

      // If 404 (UUID not known to backend), retry using the old invoice number as identifier
      if (!res.success && (res.statusCode == 404 || res.statusCode == null)) {
        debugPrint('[InvoiceProvider] PUT by id failed ($invoiceId), retrying by invoiceNumber ($oldInvoiceNumber)...');
        res = await _api.put('${Endpoints.invoices}/$oldInvoiceNumber', {
          'invoiceNumber': cleanNum,
        });
      }

      if (res.success && res.data != null && res.data['invoice'] != null) {
        final updatedFromBackend = InvoiceModel.fromJson(res.data['invoice'] as Map<String, dynamic>);
        // The backend returns the real MongoDB _id — update local list to use it
        final idx = _invoices.indexWhere(
          (inv) => inv.id == invoiceId || inv.invoiceNumber == cleanNum || inv.id == updatedFromBackend.id,
        );
        if (idx != -1) {
          _invoices[idx] = updatedFromBackend;
          await _cache.saveInvoices(_invoices);
          notifyListeners();
          debugPrint('[InvoiceProvider] Invoice number updated in DB. MongoDB id: ${updatedFromBackend.id}');
        }
        return true;
      }

      debugPrint('[InvoiceProvider] updateInvoiceNumber failed: ${res.message}');
      return res.success;
    } catch (e) {
      debugPrint('[InvoiceProvider] updateInvoiceNumber error: $e');
      return false;
    }
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
      await _cache.saveInvoices(_invoices);
      notifyListeners();

      try {
        await _api.post('${Endpoints.invoices}/$invoiceId/mark-paid', {});
      } catch (e) {
        debugPrint('[InvoiceProvider] markInvoiceAsPaid error: $e');
      }
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

      await _cache.saveInvoices(_invoices);
      notifyListeners();

      try {
        await _api.put('${Endpoints.invoices}/$invoiceId/status', {
          'amountPaid': newPaid,
          'status': newStatus,
        });
      } catch (e) {
        debugPrint('[InvoiceProvider] updatePayment error: $e');
      }
    }
  }

  Future<void> deleteInvoice(String invoiceId) async {
    _invoices.removeWhere((inv) => inv.id == invoiceId);
    await _cache.saveInvoices(_invoices);
    notifyListeners();

    try {
      await _api.delete('${Endpoints.invoices}/$invoiceId');
    } catch (e) {
      debugPrint('[InvoiceProvider] deleteInvoice error: $e');
    }
  }
}
