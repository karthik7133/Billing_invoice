import 'package:flutter/material.dart';
import '../core/utils/platform_helper.dart';

/// A wrapper widget that constrains width and centers content on desktop screens
/// to prevent forms, buttons, and content cards from stretching across a 1920px+ monitor.
///
/// On Android and mobile devices, this widget returns the [child] directly with zero overhead.
class DesktopContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? desktopPadding;
  final AlignmentGeometry alignment;

  const DesktopContainer({
    super.key,
    required this.child,
    this.maxWidth = 1000,
    this.desktopPadding,
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformHelper.isDesktop) {
      return child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        );

        if (desktopPadding != null) {
          content = Padding(
            padding: desktopPadding!,
            child: content,
          );
        }

        return Align(
          alignment: alignment,
          child: content,
        );
      },
    );
  }
}

/// A desktop-adaptive bottom action bar.
///
/// On Windows desktop: Aligns action buttons neatly (e.g. [Cancel] [Save]) with comfortable,
/// professional desktop button widths instead of stretching 1800+ pixels across a wide monitor.
///
/// On Android: Renders the standard full-width mobile action row.
class DesktopActionBar extends StatelessWidget {
  final Widget primaryButton;
  final Widget? secondaryButton;
  final Widget? leading;
  final double maxDesktopWidth;
  final EdgeInsetsGeometry padding;

  const DesktopActionBar({
    super.key,
    required this.primaryButton,
    this.secondaryButton,
    this.leading,
    this.maxDesktopWidth = 900,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = PlatformHelper.isDesktop;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: isDesktop
            ? const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDesktop ? 0.04 : 0.08),
            blurRadius: isDesktop ? 8 : 16,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? maxDesktopWidth : double.infinity,
            ),
            child: Padding(
              padding: padding,
              child: isDesktop ? _buildDesktopRow() : _buildMobileRow(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (leading != null) leading! else const SizedBox.shrink(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (secondaryButton != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, minHeight: 40),
                child: secondaryButton!,
              ),
              const SizedBox(width: 14),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, minHeight: 40),
              child: primaryButton,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMobileRow() {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 10),
        ],
        if (secondaryButton != null) ...[
          secondaryButton!,
          const SizedBox(width: 10),
        ],
        Expanded(child: primaryButton),
      ],
    );
  }
}
