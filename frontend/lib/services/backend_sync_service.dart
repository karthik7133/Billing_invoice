import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/api/endpoints.dart';
import '../core/api/api_client.dart';
import '../providers/business_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/auth_provider.dart';

enum ServerStatus {
  connecting,
  wakingUp,
  online,
  offline,
}

/// Service that manages Render backend cold-start wakeups, keep-alive heartbeats,
/// and instant automatic data sync across all providers.
class BackendSyncService with ChangeNotifier {
  static final BackendSyncService instance = BackendSyncService._internal();
  factory BackendSyncService() => instance;
  BackendSyncService._internal();

  ServerStatus _status = ServerStatus.connecting;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _heartbeatTimer;
  Timer? _retryTimer;
  int _warmupAttemptCount = 0;
  final List<VoidCallback> _onAwakeCallbacks = [];

  ServerStatus get status => _status;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isOnline => _status == ServerStatus.online;
  bool get isWakingUp => _status == ServerStatus.wakingUp || _status == ServerStatus.connecting;

  /// Registers a one-time or recurring callback when server transitions to online
  void addOnAwakeCallback(VoidCallback callback) {
    _onAwakeCallbacks.add(callback);
  }

  void removeOnAwakeCallback(VoidCallback callback) {
    _onAwakeCallbacks.remove(callback);
  }

  /// Start background warm-up as early as possible (at app launch)
  void startEarlyWarmup() {
    debugPrint('[BackendSync] Starting early warm-up for Render backend...');
    _warmupAttemptCount = 0;
    _checkHealth();
    _startHeartbeat();
  }

  /// Keep-alive heartbeat every 10 minutes to prevent Render free-tier cool down
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      debugPrint('[BackendSync] Heartbeat pinging server to prevent sleep...');
      _checkHealth(isSilentHeartbeat: true);
    });
  }

  /// Pings /api/health with automatic retry loop for Render cold starts
  Future<bool> _checkHealth({bool isSilentHeartbeat = false}) async {
    if (!isSilentHeartbeat && _status != ServerStatus.online) {
      _status = _warmupAttemptCount > 0 ? ServerStatus.wakingUp : ServerStatus.connecting;
      notifyListeners();
    }

    try {
      final response = await http
          .get(Uri.parse(Endpoints.health))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('[BackendSync] Render backend is ONLINE! (Attempt ${_warmupAttemptCount + 1})');
        final wasNotOnline = _status != ServerStatus.online;
        _status = ServerStatus.online;
        _warmupAttemptCount = 0;
        _retryTimer?.cancel();
        notifyListeners();

        if (wasNotOnline) {
          _triggerOnAwake();
        }
        return true;
      } else {
        throw Exception('Health check returned status ${response.statusCode}');
      }
    } catch (e) {
      _warmupAttemptCount++;
      debugPrint('[BackendSync] Health check attempt $_warmupAttemptCount failed: $e');

      if (!isSilentHeartbeat) {
        _status = _warmupAttemptCount > 1 ? ServerStatus.wakingUp : ServerStatus.connecting;
        notifyListeners();
      }

      // Schedule next retry with rapid frequency (every 3 seconds up to 15 attempts, then 10s)
      _retryTimer?.cancel();
      final retryDelay = _warmupAttemptCount < 15 ? const Duration(seconds: 3) : const Duration(seconds: 10);
      _retryTimer = Timer(retryDelay, () => _checkHealth());
      return false;
    }
  }

  void _triggerOnAwake() {
    for (final callback in List<VoidCallback>.from(_onAwakeCallbacks)) {
      try {
        callback();
      } catch (e) {
        debugPrint('[BackendSync] Error in onAwake callback: $e');
      }
    }
  }

  /// Manually force a reconnection test & multi-provider sync
  Future<void> forceSync({
    BusinessProvider? businessProvider,
    CustomerProvider? customerProvider,
    ProductProvider? productProvider,
    InvoiceProvider? invoiceProvider,
    AuthProvider? authProvider,
  }) async {
    _isSyncing = true;
    notifyListeners();

    debugPrint('[BackendSync] forceSync requested...');
    final online = await _checkHealth();
    if (online) {
      await _executeProvidersFetch(
        businessProvider: businessProvider,
        customerProvider: customerProvider,
        productProvider: productProvider,
        invoiceProvider: invoiceProvider,
        authProvider: authProvider,
      );
      _lastSyncTime = DateTime.now();
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Syncs all providers concurrently once the backend is ready
  Future<void> _executeProvidersFetch({
    BusinessProvider? businessProvider,
    CustomerProvider? customerProvider,
    ProductProvider? productProvider,
    InvoiceProvider? invoiceProvider,
    AuthProvider? authProvider,
  }) async {
    try {
      // ── Step 1: Fetch business profile FIRST ─────────────────────────────────
      if (businessProvider != null) {
        await businessProvider.fetchBusinessProfile();
        // Guarantee customer & invoice providers are scoped to current active company
        final activeId = businessProvider.activeCompanyId;
        if (activeId.isNotEmpty) {
          customerProvider?.setActiveCompany(activeId);
          invoiceProvider?.setActiveCompany(activeId);
        }
      }
      // ─────────────────────────────────────────────────────────────────────────

      // ── Step 2: Fetch everything else in parallel ────────────────────────────
      final futures = <Future<dynamic>>[];
      if (authProvider != null && ApiClient().token != null) {
        futures.add(authProvider.fetchMe());
      }
      if (customerProvider != null) {
        futures.add(customerProvider.fetchCustomers());
      }
      if (productProvider != null) {
        futures.add(productProvider.fetchProducts());
      }
      if (invoiceProvider != null) {
        futures.add(invoiceProvider.fetchInvoices());
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
        debugPrint('[BackendSync] All providers fetched & synchronized successfully!');
      }
    } catch (e) {
      debugPrint('[BackendSync] Error executing providers fetch: $e');
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
