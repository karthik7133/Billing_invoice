import 'dart:async';
import 'package:flutter/material.dart';

/// Stateful dots-animation widget shown inside the progress dialog
class _PulsingDots extends StatefulWidget {
  const _PulsingDots();
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _dotCount = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '●' * _dotCount;
    return Text(
      dots,
      style: const TextStyle(
        fontSize: 18,
        color: Color(0xFF2563EB),
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
        decoration: TextDecoration.none,
      ),
    );
  }
}

class PdfProgressDialog {
  static BuildContext? _dialogContext;
  static bool _isShowing = false;
  static bool _isDismissed = false;
  static int _currentSessionId = 0;
  static Timer? _autoDismissTimer;

  static bool get isShowing => _isShowing;

  static void show(BuildContext context, {String message = 'Preparing PDF...'}) {
    // If already showing, update session and don't double show
    _currentSessionId++;
    final sessionId = _currentSessionId;
    _isShowing = true;
    _isDismissed = false;

    _autoDismissTimer?.cancel();
    // Extended to 30s — large ledger PDFs can take that long
    _autoDismissTimer = Timer(const Duration(seconds: 30), () {
      hide();
    });

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (dialogCtx) {
        _dialogContext = dialogCtx;

        // If hide() was called before this dialog finished building, pop immediately
        if (_isDismissed || _currentSessionId != sessionId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (dialogCtx.mounted) {
              try {
                Navigator.of(dialogCtx, rootNavigator: true).pop();
              } catch (_) {}
            }
          });
          return const SizedBox.shrink();
        }

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              _isShowing = false;
              _isDismissed = true;
              _dialogContext = null;
              _autoDismissTimer?.cancel();
              _autoDismissTimer = null;
            }
          },
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const _PulsingDots(),
                  const SizedBox(height: 4),
                  const Text(
                    'Please wait a moment',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF94A3B8),
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      if (_currentSessionId == sessionId) {
        _isShowing = false;
        _isDismissed = true;
        _dialogContext = null;
        _autoDismissTimer?.cancel();
        _autoDismissTimer = null;
      }
    });
  }

  static void hide() {
    _isShowing = false;
    _isDismissed = true;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;

    final ctx = _dialogContext;
    _dialogContext = null;
    if (ctx != null && ctx.mounted) {
      try {
        Navigator.of(ctx, rootNavigator: true).pop();
      } catch (_) {}
    }
  }
}
