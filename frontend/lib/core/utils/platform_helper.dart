import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Centralized platform helper to safely distinguish desktop execution (Windows, macOS, Linux)
/// from mobile (Android, iOS) and Web.
///
/// On Android, [isDesktop] and [isWindows] are GUARANTEED to be `false`, ensuring zero
/// regressions or disruptions for the mobile app build.
class PlatformHelper {
  /// Whether the app is currently running on a desktop operating system (Windows, macOS, Linux).
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  /// True specifically on Windows desktop EXE.
  static bool get isWindows {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// True when running on Android.
  static bool get isAndroid {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// Whether the current context is running on desktop with a wide screen layout (>= 800px width).
  static bool isWideDesktop(BuildContext context) {
    return isDesktop && MediaQuery.sizeOf(context).width >= 800;
  }
}
