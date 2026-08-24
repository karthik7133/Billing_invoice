import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isCompact;

  const StatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color textColor;
    String label;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'PAID':
        bg = AppColors.statusPaidBg;
        textColor = AppColors.statusPaidText;
        label = 'PAID';
        icon = Icons.check_circle_rounded;
        break;
      case 'PARTIALLY_PAID':
      case 'PARTIAL':
        bg = AppColors.statusPartialBg;
        textColor = AppColors.statusPartialText;
        label = 'PARTIAL';
        icon = Icons.timelapse_rounded;
        break;
      case 'ISSUED':
      case 'UNPAID':
        bg = AppColors.statusUnpaidBg;
        textColor = AppColors.statusUnpaidText;
        label = 'UNPAID';
        icon = Icons.error_outline_rounded;
        break;
      case 'DRAFT':
        bg = AppColors.statusDraftBg;
        textColor = AppColors.statusDraftText;
        label = 'DRAFT';
        icon = Icons.edit_note_rounded;
        break;
      case 'CANCELLED':
      default:
        bg = AppColors.statusCancelledBg;
        textColor = AppColors.statusCancelledText;
        label = status.toUpperCase();
        icon = Icons.cancel_outlined;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 7 : 10,
        vertical: isCompact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isCompact ? 12 : 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
