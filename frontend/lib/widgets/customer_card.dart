import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../core/constants/app_colors.dart';

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
    final badgeColor = customer.isRegistered ? AppColors.infoBg : AppColors.warningBg;
    final badgeTextColor = customer.isRegistered ? AppColors.info : AppColors.warning;
    final avatarBg = customer.isRegistered
        ? AppColors.primary.withValues(alpha: 0.12)
        : AppColors.secondary.withValues(alpha: 0.12);
    final avatarFg = customer.isRegistered ? AppColors.primary : AppColors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: avatarBg,
                foregroundColor: avatarFg,
                child: Text(
                  customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),

              // Content (flexible so it never overflows)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + Badge in a Wrap so badge drops below if needed
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            customer.isRegistered ? 'B2B' : 'B2C',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Phone + State row
                    Row(
                      children: [
                        if (customer.phone.isNotEmpty) ...[
                          const Icon(Icons.phone_outlined, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 3),
                          Text(
                            customer.phone,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 8),
                          const Text('·', style: TextStyle(color: AppColors.textMuted)),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            customer.state,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (customer.gstin.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'GSTIN: ${customer.gstin}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Actions menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
                onSelected: (val) {
                  if (val == 'edit' && onEdit != null) onEdit!();
                  if (val == 'delete' && onDelete != null) onDelete!();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: AppColors.error)),
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
