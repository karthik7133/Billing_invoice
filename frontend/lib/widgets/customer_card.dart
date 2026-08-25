import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';

class CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CustomerCard({
    super.key,
    required this.customer,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isRegistered = customer.isRegistered;
    final balance = customer.balance;
    final isReceivable = balance >= 0;
    final balanceAbs = balance.abs();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with Initials
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isRegistered ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: isRegistered ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            customer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: isRegistered ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isRegistered ? 'B2B' : 'B2C',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: isRegistered ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (customer.phone.isNotEmpty) ...[
                          const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 3),
                          Text(
                            customer.phone,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 6),
                          const Text('·', style: TextStyle(color: Color(0xFFCBD5E1))),
                          const SizedBox(width: 6),
                        ],
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            customer.state.isNotEmpty ? customer.state : 'State not set',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (customer.gstin.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'GSTIN: ${customer.gstin}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Balance & Actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(balanceAbs),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isReceivable
                        ? (balanceAbs > 0 ? "You'll Get" : 'Settled')
                        : "You'll Give",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isReceivable
                          ? (balanceAbs > 0 ? AppColors.receivableGreen : const Color(0xFF94A3B8))
                          : AppColors.payableRed,
                    ),
                  ),
                ],
              ),

              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 19),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'edit' && onEdit != null) onEdit!();
                  if (val == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 17, color: Color(0xFF475569)),
                        SizedBox(width: 8),
                        Text('Edit Customer'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 17, color: AppColors.payableRed),
                        SizedBox(width: 8),
                        Text('Delete Customer', style: TextStyle(color: AppColors.payableRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
