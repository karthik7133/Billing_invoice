import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/platform_helper.dart';

class CustomerCard extends StatefulWidget {
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
  State<CustomerCard> createState() => _CustomerCardState();
}

class _CustomerCardState extends State<CustomerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isRegistered = widget.customer.isRegistered;
    final balance = widget.customer.balance;
    final isReceivable = balance >= 0;
    final balanceAbs = balance.abs();
    final isDesktop = PlatformHelper.isDesktop;

    return MouseRegion(
      onEnter: isDesktop ? (_) => setState(() => _isHovered = true) : null,
      onExit: isDesktop ? (_) => setState(() => _isHovered = false) : null,
      cursor: isDesktop ? SystemMouseCursors.click : MouseCursor.defer,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _isHovered ? const Color(0xFFF8FAFF) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isHovered ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.06 : 0.02),
              blurRadius: _isHovered ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 18 : 14,
              vertical: isDesktop ? 14 : 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with Initials
                Container(
                  width: isDesktop ? 48 : 44,
                  height: isDesktop ? 48 : 44,
                  decoration: BoxDecoration(
                    color: isRegistered ? const Color(0xFFEFF6FF) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.customer.name.isNotEmpty ? widget.customer.name[0].toUpperCase() : 'C',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isDesktop ? 18 : 17,
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
                              widget.customer.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isDesktop ? 15.5 : 15,
                                color: const Color(0xFF0F172A),
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
                          if (widget.customer.phone.isNotEmpty) ...[
                            const Icon(Icons.phone_outlined, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 3),
                            Text(
                              widget.customer.phone,
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
                              widget.customer.state.isNotEmpty ? widget.customer.state : 'State not set',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (widget.customer.gstin.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'GSTIN: ${widget.customer.gstin}',
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
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.format(balanceAbs),
                        style: TextStyle(
                          fontSize: isDesktop ? 15 : 14,
                          fontWeight: FontWeight.w800,
                          color: isReceivable ? AppColors.receivableGreen : AppColors.payableRed,
                        ),
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

                if (isDesktop) ...[
                  const SizedBox(width: 12),
                  // Desktop: show edit/delete as icon buttons on hover
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _isHovered ? 1.0 : 0.0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DesktopIconBtn(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit',
                          color: const Color(0xFF2563EB),
                          onTap: widget.onEdit,
                        ),
                        const SizedBox(width: 4),
                        _DesktopIconBtn(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete',
                          color: AppColors.payableRed,
                          onTap: widget.onDelete,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Color(0xFF94A3B8), size: 19),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (val) {
                      if (val == 'edit' && widget.onEdit != null) widget.onEdit!();
                      if (val == 'delete' && widget.onDelete != null) widget.onDelete!();
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small icon button shown on hover for desktop — compact, clean.
class _DesktopIconBtn extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  const _DesktopIconBtn({required this.icon, required this.tooltip, required this.color, this.onTap});

  @override
  State<_DesktopIconBtn> createState() => _DesktopIconBtnState();
}

class _DesktopIconBtnState extends State<_DesktopIconBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _hover ? widget.color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Tooltip(
            message: widget.tooltip,
            child: Icon(widget.icon, size: 16, color: widget.color),
          ),
        ),
      ),
    );
  }
}
