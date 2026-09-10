import 'dart:async';
import 'package:flutter/material.dart';

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
    _autoDismissTimer = Timer(const Duration(seconds: 6), () {
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
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  const SizedBox(height: 4),
                  const Text(
                    'Please wait a moment',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
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
