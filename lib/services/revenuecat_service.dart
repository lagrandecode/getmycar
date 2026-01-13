import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat service for managing subscriptions and purchases
class RevenueCatService {
  // Singleton instance
  static final RevenueCatService instance = RevenueCatService._internal();
  factory RevenueCatService() => instance;
  RevenueCatService._internal();

  // Configuration constants
  static const String rcApiKey = 'appl_lUlEngvhNUyLxVfiSPfpksSqxLo';
  static const String entitlementId = 'Get My Car Pro';
  static const String monthlyProductId = 'com.lagrangecode.getmycar.premium.monthly';
  static const String yearlyProductId = 'com.lagrangecode.getmycar.premium.yearly';
  static const String offeringId = 'default';

  bool _isInitialized = false;
  CustomerInfo? _latestCustomerInfo;
  
  // Stream controller for entitlement state changes
  final _entitlementController = StreamController<bool>.broadcast();
  Stream<bool> get entitlementStream => _entitlementController.stream;

  /// Initialize RevenueCat SDK
  Future<void> init() async {
    if (_isInitialized) {
      debugPrint('⚠️ RevenueCat already initialized');
      return;
    }

    try {
      // Configure RevenueCat
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
      
      // Initialize with API key
      PurchasesConfiguration configuration = PurchasesConfiguration(rcApiKey);
      await Purchases.configure(configuration);

      _isInitialized = true;
      debugPrint('✅ RevenueCat initialized successfully');

      // Load initial customer info
      await _refreshCustomerInfo();
    } catch (e) {
      debugPrint('❌ RevenueCat initialization failed: $e');
      _isInitialized = false;
      // Don't throw - app should still work without RevenueCat
    }
  }

  /// Refresh customer info from RevenueCat
  Future<void> _refreshCustomerInfo() async {
    try {
      _latestCustomerInfo = await Purchases.getCustomerInfo();
      final isPro = isProActive();
      _entitlementController.add(isPro);
      debugPrint('✅ Customer info refreshed. Pro status: $isPro');
    } catch (e) {
      debugPrint('⚠️ Error refreshing customer info: $e');
    }
  }

  /// Check if user has active premium entitlement
  bool isProActive() {
    if (_latestCustomerInfo == null) {
      return false;
    }
    return _latestCustomerInfo!.entitlements.active.containsKey(entitlementId);
  }

  /// Get current customer info (async)
  Future<bool> isProActiveAsync() async {
    try {
      await _refreshCustomerInfo();
      return isProActive();
    } catch (e) {
      debugPrint('⚠️ Error checking pro status: $e');
      return false;
    }
  }

  /// Purchase subscription (monthly or yearly)
  /// Returns CustomerInfo if successful, throws exception on failure
  Future<CustomerInfo> purchaseMonthlyOrYearly({required String productId}) async {
    if (!_isInitialized) {
      throw Exception('RevenueCat not initialized. Call init() first.');
    }

    try {
      debugPrint('🛒 Starting purchase for product: $productId');

      // Try to get offerings first
      Offerings? offerings;
      try {
        offerings = await Purchases.getOfferings();
      } catch (e) {
        debugPrint('⚠️ Could not fetch offerings: $e');
      }

      // Try to find package in offerings
      Package? packageToPurchase;
      if (offerings?.current != null) {
        packageToPurchase = offerings!.current!.availablePackages.firstWhere(
          (package) => package.storeProduct.identifier == productId,
          orElse: () => throw Exception('Package not found'),
        );
      }

      CustomerInfo customerInfo;
      
      if (packageToPurchase != null) {
        // Purchase via package
        debugPrint('📦 Purchasing package: ${packageToPurchase.identifier}');
        final result = await Purchases.purchasePackage(packageToPurchase);
        customerInfo = result.customerInfo;
      } else {
        // Fallback: Purchase by product ID directly
        debugPrint('📦 Package not found in offerings, purchasing by product ID');
        final products = await Purchases.getProducts([productId]);
        if (products.isEmpty) {
          throw Exception('Product not found: $productId');
        }
        final result = await Purchases.purchaseStoreProduct(products.first);
        customerInfo = result.customerInfo;
      }

      // Update local customer info
      _latestCustomerInfo = customerInfo;
      final isPro = isProActive();
      _entitlementController.add(isPro);

      debugPrint('✅ Purchase successful. Pro status: $isPro');
      return customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      // Check if user cancelled
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('⚠️ Purchase cancelled by user');
        throw Exception('Purchase cancelled');
      }
      
      // Check for other errors
      debugPrint('❌ Purchase failed: ${e.message} (Code: $errorCode)');
      throw Exception('Purchase failed: ${e.message ?? errorCode.toString()}');
    } catch (e) {
      debugPrint('❌ Unexpected purchase error: $e');
      rethrow;
    }
  }

  /// Restore purchases
  /// Returns CustomerInfo after restore
  Future<CustomerInfo> restore() async {
    if (!_isInitialized) {
      throw Exception('RevenueCat not initialized. Call init() first.');
    }

    try {
      debugPrint('♻️ Restoring purchases...');
      final customerInfo = await Purchases.restorePurchases();
      
      // Update local customer info
      _latestCustomerInfo = customerInfo;
      final isPro = isProActive();
      _entitlementController.add(isPro);

      debugPrint('✅ Restore completed. Pro status: $isPro');
      return customerInfo;
    } catch (e) {
      debugPrint('❌ Restore failed: $e');
      rethrow;
    }
  }

  /// Get current customer info
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      await _refreshCustomerInfo();
      return _latestCustomerInfo;
    } catch (e) {
      debugPrint('⚠️ Error getting customer info: $e');
      return null;
    }
  }

  /// Debug helper: Print current RevenueCat state
  Future<void> debugPrintRevenueCatState() async {
    if (!_isInitialized) {
      debugPrint('❌ RevenueCat not initialized');
      return;
    }

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      debugPrint('📊 RevenueCat Debug Info:');
      debugPrint('   App User ID: ${customerInfo.originalAppUserId}');
      debugPrint('   Active Entitlements: ${customerInfo.entitlements.active.keys}');
      debugPrint('   All Entitlements: ${customerInfo.entitlements.all.keys}');
      debugPrint('   Pro Active: ${customerInfo.entitlements.active.containsKey(entitlementId)}');
      
      final offerings = await Purchases.getOfferings();
      if (offerings.current != null) {
        debugPrint('   Current Offering: ${offerings.current!.identifier}');
        debugPrint('   Available Packages: ${offerings.current!.availablePackages.map((p) => p.identifier).toList()}');
      } else {
        debugPrint('   No current offering available');
      }
    } catch (e) {
      debugPrint('❌ Error getting debug info: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _entitlementController.close();
  }
}
