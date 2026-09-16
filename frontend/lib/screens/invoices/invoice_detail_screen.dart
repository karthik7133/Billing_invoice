import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../services/share_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/desktop_container.dart';
import '../../core/utils/platform_helper.dart';
import 'package:intl/intl.dart';
import 'invoice_pdf_preview_screen.dart';
import 'create_invoice_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  /// Live copy of the invoice — always kept in sync with the provider.
  /// Falls back to widget.invoice if the provider doesn't have it yet.
  late InvoiceModel _invoice;
  late String _invoiceId;

  /// Guards to prevent duplicate API calls from rapid button taps
  bool _isMarkingPaid = false;
  bool _isRecordingPayment = false;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _invoiceId = widget.invoice.id;
  }

  /// Always return the freshest copy: provider list first, local state as fallback.
  InvoiceModel _liveinvoice(InvoiceProvider provider) {
    try {
      // Match by id OR by invoiceNumber (handles UUID→MongoDB id transitions)
      return provider.allInvoices.firstWhere(
        (inv) => inv.id == _invoiceId || inv.invoiceNumber == _invoice.invoiceNumber,
      );
    } catch (_) {
      return _invoice;
    }
  }

  void _editInvoiceNumberDialog() {
    final provider = Provider.of<InvoiceProvider>(context, listen: false);
    _invoice = _liveinvoice(provider);
    _invoiceId = _invoice.id;
    final controller = TextEditingController(text: _invoice.invoiceNumber);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Change Invoice Number', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter new invoice number:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Invoice Number',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              final newNum = controller.text.trim();
              if (newNum.isNotEmpty) {
                // Optimistically update local state immediately
                setState(() {
                  _invoice = _invoice.copyWith(invoiceNumber: newNum);
                });
                Navigator.pop(ctx);
                final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
                // Use _invoiceId (might be updated to MongoDB id already)
                final success = await invoiceProvider.updateInvoiceNumber(_invoiceId, newNum);
                // Sync local id with whatever the provider resolved to
                if (mounted) {
                  final live = _liveinvoice(invoiceProvider);
                  if (live.id != _invoiceId) {
                    setState(() { _invoiceId = live.id; });
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Invoice number updated to $newNum'
                          : 'Saved locally — will sync when online'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: success ? AppColors.success : AppColors.warning,
                    ),
                  );
                }
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showRecordOrEditPaymentDialog({PaymentRecord? existingPayment, int? editIndex}) {
    final isEditingPayment = existingPayment != null && editIndex != null;
    final controller = TextEditingController(
      text: isEditingPayment
          ? (existingPayment.amount == existingPayment.amount.roundToDouble()
              ? existingPayment.amount.toInt().toString()
              : existingPayment.amount.toStringAsFixed(2))
          : (_invoice.balanceDue > 0
              ? (_invoice.balanceDue == _invoice.balanceDue.roundToDouble()
                  ? _invoice.balanceDue.toInt().toString()
                  : _invoice.balanceDue.toStringAsFixed(2))
              : ''),
    );
    final notesController = TextEditingController(text: isEditingPayment ? existingPayment.notes : '');
    DateTime pickedDate = isEditingPayment ? existingPayment.date : DateTime.now();
    String pickedType = isEditingPayment ? existingPayment.type : (_invoice.paymentType.isNotEmpty ? _invoice.paymentType : 'Cash');

    final paymentTypes = ['Cash', 'Bank Transfer', 'UPI', 'Cheque', 'IMPS', 'Card'];
    if (!paymentTypes.contains(pickedType)) {
      paymentTypes.add(pickedType);
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isEditingPayment ? Icons.edit_calendar_outlined : Icons.add_card_outlined,
                color: const Color(0xFF1E88E5),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                isEditingPayment ? 'Edit Payment Installment' : 'Record Payment',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Financial Info Header
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text(CurrencyFormatter.format(_invoice.grandTotal), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Already Paid:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text(CurrencyFormatter.format(_invoice.amountPaid), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Current Due:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          Text(CurrencyFormatter.format(_invoice.balanceDue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFEF4444))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Amount
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount (₹) *',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                // Date Picker
                const Text('Payment Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: pickedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDialogState(() => pickedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFF8FAFC),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF1E88E5)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(pickedDate),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const Spacer(),
                        const Text('Change', style: TextStyle(fontSize: 12, color: Color(0xFF1E88E5), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Mode Dropdown
                const Text('Payment Mode', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: paymentTypes.contains(pickedType) ? pickedType : paymentTypes.first,
                      isExpanded: true,
                      items: paymentTypes.map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type == 'Cash' ? '💵 Cash' :
                          type == 'UPI' ? '📱 UPI' :
                          type == 'Bank Transfer' ? '🏦 Bank Transfer' :
                          type == 'Cheque' ? '📝 Cheque' :
                          type == 'IMPS' ? '⚡ IMPS' : '💳 $type',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      )).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => pickedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Notes / Reference
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(
                    labelText: 'Notes / Reference (Optional)',
                    hintText: 'e.g. UPI txn ID, Cheque #, 2nd installment',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isRecordingPayment
                  ? null
                  : () async {
                      final amt = double.tryParse(controller.text.trim()) ?? 0.0;
                      if (amt <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: AppColors.error),
                        );
                        return;
                      }

                      setDialogState(() => _isRecordingPayment = true);
                      final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
                      final record = PaymentRecord(
                        id: existingPayment?.id,
                        amount: amt,
                        type: pickedType,
                        date: pickedDate,
                        notes: notesController.text.trim(),
                      );

                      if (isEditingPayment) {
                        await invProvider.editPaymentInInvoice(_invoice.id, editIndex, record);
                      } else {
                        await invProvider.addPaymentToInvoice(_invoice.id, record);
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {
                          _isRecordingPayment = false;
                          _invoice = _liveinvoice(invProvider);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isEditingPayment
                                ? 'Payment installment updated successfully'
                                : 'Payment of ${CurrencyFormatter.format(amt)} recorded on ${DateFormat("dd MMM yyyy").format(pickedDate)}'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
              child: _isRecordingPayment
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(isEditingPayment ? 'Update Payment' : 'Record Payment'),
            ),
          ],
        ),
      ),
    );
  }

  void _recordPaymentDialog() {
    _showRecordOrEditPaymentDialog();
  }

  void _navigateToEditSale() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CreateInvoiceScreen(existingInvoice: _invoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Always sync with the live provider data
    final invoiceProvider = Provider.of<InvoiceProvider>(context);
    _invoice = _liveinvoice(invoiceProvider);
    final customer = _invoice.customerSnapshot;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
              tooltip: 'Edit Invoice Number',
              onPressed: _editInvoiceNumberDialog,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: Color(0xFF2563EB)),
            tooltip: 'Edit Sale / Adjust Payments',
            onPressed: _navigateToEditSale,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primary),
            tooltip: 'Share PDF',
            onPressed: () => ShareService.shareInvoicePdf(_invoice, context: context),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, color: AppColors.primary),
            tooltip: 'Print Invoice',
            onPressed: () => ShareService.printInvoice(_invoice, context: context),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'edit_sale') {
                _navigateToEditSale();
              } else if (val == 'edit_num') {
                _editInvoiceNumberDialog();
              } else if (val == 'delete') {
                final invId = _invoice.id;
                final invNo = _invoice.invoiceNumber;
                final invProvider = Provider.of<InvoiceProvider>(context, listen: false);
                invProvider.deleteInvoice(invId);
                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                messenger.hideCurrentSnackBar();
                final snackBarController = messenger.showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: Colors.amberAccent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Sale #$invNo moved to Recycle Bin'),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    duration: const Duration(milliseconds: 2500),
                    dismissDirection: DismissDirection.down,
                    action: SnackBarAction(
                      label: 'Undo',
                      textColor: Colors.amberAccent,
                      onPressed: () => invProvider.restoreInvoice(invId),
                    ),
                  ),
                );
                Future.delayed(const Duration(milliseconds: 2600), () {
                  try {
                    snackBarController.close();
                  } catch (_) {}
                });
              }
            },
            itemBuilder: (c) => [
              const PopupMenuItem(
                value: 'edit_sale',
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Text('Edit Sale & Items'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit_num',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Text('Change Invoice Number'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Text('Delete Invoice', style: TextStyle(color: AppColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: DesktopContainer(
        maxWidth: 820,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Status Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        CurrencyFormatter.format(_invoice.grandTotal),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${CurrencyFormatter.formatDate(_invoice.invoiceDate)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Origin: ${_invoice.origin.toUpperCase()}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: _invoice.status),
                      if (_invoice.balanceDue > 0 && !_invoice.isPaid) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Due: ${CurrencyFormatter.format(_invoice.balanceDue)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Customer & Bill To Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bill To / Customer',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _invoice.isInterState ? Colors.purple.withValues(alpha: 0.1) : AppColors.infoBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _invoice.isInterState ? 'Inter-State (IGST)' : 'Intra-State (CGST+SGST)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _invoice.isInterState ? Colors.purple : AppColors.info,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    customer.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  if (customer.billingAddress.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(customer.billingAddress, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 3),
                  Text('State: ${customer.state} (${customer.stateCode})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (customer.gstin.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('GSTIN: ${customer.gstin}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3. Itemized Breakdown Table
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items & Products',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _invoice.items.length,
                    separatorBuilder: (ctx, i) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final it = _invoice.items[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    it.name,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.format(it.total),
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${it.quantity} ${it.unit} × ${CurrencyFormatter.format(it.rate)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  'GST ${it.gstRate.toStringAsFixed(0)}% (₹${it.totalTax.toStringAsFixed(2)})',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                            if (it.discountAmount > 0)
                              Text(
                                'Discount: - ₹${it.discountAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.error),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 4. Financial & GST Summary Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment & Tax Summary', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  _buildDetailRow('Subtotal', CurrencyFormatter.format(_invoice.subtotal)),
                  if (_invoice.totalDiscount > 0)
                    _buildDetailRow('Total Discount', '- ${CurrencyFormatter.format(_invoice.totalDiscount)}', isRed: true),
                  _buildDetailRow('Taxable Amount', CurrencyFormatter.format(_invoice.taxableAmount)),
                  if (!_invoice.isInterState) ...[
                    _buildDetailRow('CGST (Central Tax)', CurrencyFormatter.format(_invoice.cgst)),
                    _buildDetailRow('SGST (State Tax)', CurrencyFormatter.format(_invoice.sgst)),
                  ] else ...[
                    _buildDetailRow('IGST (Inter-State Tax)', CurrencyFormatter.format(_invoice.igst)),
                  ],
                  if (_invoice.otherCharges > 0)
                    _buildDetailRow('Other Charges', CurrencyFormatter.format(_invoice.otherCharges)),
                  if (_invoice.roundOff != 0)
                    _buildDetailRow('Round Off', CurrencyFormatter.format(_invoice.roundOff)),
                  const Divider(height: 14),
                  _buildDetailRow('Grand Total', CurrencyFormatter.format(_invoice.grandTotal), isBold: true),
                  if (_invoice.amountPaid > 0) ...[
                    _buildDetailRow('Received / Paid', CurrencyFormatter.format(_invoice.amountPaid), isGreen: true),
                    _buildDetailRow('Balance Due', CurrencyFormatter.format(_invoice.balanceDue), isRed: _invoice.balanceDue > 0, isGreen: _invoice.balanceDue <= 0, isBold: true),
                  ],
                  if (_invoice.hasOverMoney) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Over Due (Extra / Advance Paid):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
                          ),
                          Text(
                            CurrencyFormatter.format(_invoice.overMoneyAmount),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_invoice.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Description / Notes:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                          const SizedBox(height: 2),
                          Text(_invoice.description, style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'In Words: ${_invoice.amountInWords}',
                    style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // 4b. Attached Cloudinary Photos / Receipts Gallery
            if (_invoice.attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          'Attached Photos & Receipts (${_invoice.attachments.length})',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _invoice.attachments.length,
                        separatorBuilder: (ctx, i) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final url = _invoice.attachments[i];
                          return GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (c) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      InteractiveViewer(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(url, fit: BoxFit.contain),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                        onPressed: () => Navigator.pop(c),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 86,
                                height: 86,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, e, st) => const Center(
                                    child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                                  ),
                                  loadingBuilder: (ctx, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 5. Payment History & Installments Card (Split payments with dates & modes)
            _buildPaymentHistoryCard(invoiceProvider),

            const SizedBox(height: 16),

            // 6. Quick Payment Action Buttons
            if (!_invoice.isPaid) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isRecordingPayment ? null : _recordPaymentDialog,
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Record Payment'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: _isMarkingPaid
                          ? null
                          : () async {
                              setState(() => _isMarkingPaid = true);
                              final provider = Provider.of<InvoiceProvider>(context, listen: false);
                              await provider.markInvoiceAsPaid(_invoice.id);
                              if (!mounted) return;
                              setState(() {
                                _invoice = _invoice.copyWith(
                                  amountPaid: _invoice.grandTotal,
                                  balanceDue: 0,
                                  status: 'PAID',
                                );
                                _isMarkingPaid = false;
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Marked as fully PAID!'), backgroundColor: AppColors.success),
                                );
                              }
                            },
                      icon: _isMarkingPaid
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: _isMarkingPaid ? const Text('Processing...') : const Text('Mark Full Paid'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 7. Edit Sale & PDF Preview Action Row
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: PlatformHelper.isDesktop ? WrapAlignment.end : WrapAlignment.center,
              children: [
                SizedBox(
                  width: PlatformHelper.isDesktop ? 220 : double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _navigateToEditSale,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      foregroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text('EDIT SALE & ITEMS', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                SizedBox(
                  width: PlatformHelper.isDesktop ? 240 : double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => InvoicePdfPreviewScreen(invoice: _invoice),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('VIEW TAX INVOICE PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildPaymentHistoryCard(InvoiceProvider invoiceProvider) {
    final payments = _invoice.payments;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: Color(0xFF1E88E5)),
                  SizedBox(width: 8),
                  Text(
                    'Payment Installments & Dates',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
              if (payments.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    '${payments.length} ${payments.length == 1 ? "Payment" : "Payments"}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          if (payments.isNotEmpty) ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final p = payments[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      // Badge index
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(p.date),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.type,
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                            if (p.notes.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                p.notes,
                                style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Amount
                      Text(
                        CurrencyFormatter.format(p.amount),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 4),
                      // Actions: Edit and Delete
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                        tooltip: 'Edit Installment',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () => _showRecordOrEditPaymentDialog(existingPayment: p, editIndex: i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                        tooltip: 'Delete Installment',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              title: const Text('Delete Payment Installment?', style: TextStyle(fontWeight: FontWeight.w700)),
                              content: Text('Are you sure you want to remove the payment of ${CurrencyFormatter.format(p.amount)} recorded on ${DateFormat("dd MMM yyyy").format(p.date)}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () => Navigator.pop(c, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await invoiceProvider.deletePaymentFromInvoice(_invoice.id, i);
                            if (mounted) {
                              setState(() {
                                _invoice = _liveinvoice(invoiceProvider);
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Payment installment removed')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else if (_invoice.amountPaid > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Text('1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF2563EB))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(_invoice.invoiceDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _invoice.paymentType.isNotEmpty ? _invoice.paymentType : 'Cash',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text('Initial Payment', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(_invoice.amountPaid),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                  ),
                ],
              ),
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('No payments recorded yet for this sale', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
              ),
            ),
          ],

          const SizedBox(height: 8),
          // Action button inside payment history
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _recordPaymentDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Payment Installment'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: Color(0xFF1E88E5)),
                    foregroundColor: const Color(0xFF1E88E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isRed = false, bool isGreen = false, bool isBold = false}) {
    Color color = AppColors.textPrimary;
    if (isRed) color = AppColors.error;
    if (isGreen) color = AppColors.success;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
