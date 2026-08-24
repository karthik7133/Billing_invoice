import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/invoice_model.dart';
import '../../providers/invoice_provider.dart';
import '../../services/share_service.dart';
import '../../widgets/status_badge.dart';
import 'invoice_pdf_preview_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final InvoiceModel invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late InvoiceModel _invoice;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
  }

  void _recordPaymentDialog() {
    final controller = TextEditingController(text: _invoice.balanceDue.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grand Total: ${CurrencyFormatter.format(_invoice.grandTotal)}'),
            Text('Already Paid: ${CurrencyFormatter.format(_invoice.amountPaid)}'),
            Text('Current Due: ${CurrencyFormatter.format(_invoice.balanceDue)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Payment Received (₹)',
                hintText: 'Enter amount',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final paid = double.tryParse(controller.text.trim()) ?? 0.0;
              final invoiceProvider = Provider.of<InvoiceProvider>(context, listen: false);
              final totalPaid = _invoice.amountPaid + paid;
              invoiceProvider.updatePayment(_invoice.id, totalPaid);

              setState(() {
                final balance = (_invoice.grandTotal - totalPaid).clamp(0.0, _invoice.grandTotal);
                String status = 'PARTIALLY_PAID';
                if (totalPaid >= _invoice.grandTotal) status = 'PAID';
                _invoice = _invoice.copyWith(
                  amountPaid: totalPaid,
                  balanceDue: balance,
                  status: status,
                );
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment recorded successfully!'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Record Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = _invoice.customerSnapshot;

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.invoiceNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.primary),
            tooltip: 'Share PDF',
            onPressed: () => ShareService.shareInvoicePdf(_invoice),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined, color: AppColors.primary),
            tooltip: 'Print Invoice',
            onPressed: () => ShareService.printInvoice(_invoice),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'delete') {
                Provider.of<InvoiceProvider>(context, listen: false).deleteInvoice(_invoice.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invoice ${_invoice.invoiceNumber} deleted')),
                );
              }
            },
            itemBuilder: (c) => [
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
      body: SingleChildScrollView(
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

            const SizedBox(height: 20),

            // 5. Payment Actions
            if (!_invoice.isPaid) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _recordPaymentDialog,
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Record Payment'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      onPressed: () {
                        final provider = Provider.of<InvoiceProvider>(context, listen: false);
                        provider.markInvoiceAsPaid(_invoice.id);
                        setState(() {
                          _invoice = _invoice.copyWith(
                            amountPaid: _invoice.grandTotal,
                            balanceDue: 0,
                            status: 'PAID',
                          );
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Marked as fully PAID!'), backgroundColor: AppColors.success),
                        );
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Mark Full Paid'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 6. PDF Preview & Print Action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => InvoicePdfPreviewScreen(invoice: _invoice),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('VIEW TAX INVOICE PDF'),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
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
