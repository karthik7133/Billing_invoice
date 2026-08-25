import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../services/backend_sync_service.dart';
import '../providers/business_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';

class CloudServerStatusPill extends StatelessWidget {
  final bool compact;

  const CloudServerStatusPill({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: BackendSyncService.instance,
      builder: (context, _) {
        final sync = BackendSyncService.instance;
        final status = sync.status;
        final isSyncing = sync.isSyncing;

        Color bg;
        Color fg;
        Color borderColor;
        IconData icon;
        String text;

        if (isSyncing) {
          bg = AppColors.infoBg;
          fg = AppColors.electricBlue;
          borderColor = AppColors.electricBlue.withValues(alpha: 0.3);
          icon = Icons.sync_rounded;
          text = compact ? 'Syncing...' : 'Syncing data with cloud...';
        } else {
          switch (status) {
            case ServerStatus.online:
              bg = AppColors.cloudOnlineBg;
              fg = AppColors.cloudOnline;
              borderColor = AppColors.cloudOnline.withValues(alpha: 0.3);
              icon = Icons.check_circle_rounded;
              text = compact ? 'Online' : 'Cloud Server Connected';
              break;
            case ServerStatus.wakingUp:
              bg = AppColors.cloudWakingBg;
              fg = AppColors.cloudWaking;
              borderColor = AppColors.cloudWaking.withValues(alpha: 0.3);
              icon = Icons.hourglass_top_rounded;
              text = compact ? 'Waking...' : 'Waking up cloud server...';
              break;
            case ServerStatus.connecting:
              bg = AppColors.cloudWakingBg;
              fg = AppColors.cloudWaking;
              borderColor = AppColors.cloudWaking.withValues(alpha: 0.3);
              icon = Icons.cloud_sync_outlined;
              text = compact ? 'Connecting...' : 'Connecting to cloud backend...';
              break;
            case ServerStatus.offline:
              bg = AppColors.cloudOfflineBg;
              fg = AppColors.cloudOffline;
              borderColor = AppColors.cloudOffline.withValues(alpha: 0.3);
              icon = Icons.cloud_off_rounded;
              text = compact ? 'Offline' : 'Server Sleeping (Tap to wake)';
              break;
          }
        }

        return GestureDetector(
          onTap: () {
            final authP = Provider.of<AuthProvider>(context, listen: false);
            final busP = Provider.of<BusinessProvider>(context, listen: false);
            final custP = Provider.of<CustomerProvider>(context, listen: false);
            final prodP = Provider.of<ProductProvider>(context, listen: false);
            final invP = Provider.of<InvoiceProvider>(context, listen: false);

            BackendSyncService.instance.forceSync(
              authProvider: authP,
              businessProvider: busP,
              customerProvider: custP,
              productProvider: prodP,
              invoiceProvider: invP,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 5),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing || status == ServerStatus.wakingUp || status == ServerStatus.connecting)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation<Color>(fg),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(icon, size: 13, color: fg),
                  ),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
