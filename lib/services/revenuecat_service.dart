import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat service for managing subscriptions and purchases
class RevenueCatService {
  // Singleton instance
  static final RevenueCatService instance = RevenueCatService._internal();
  factory RevenueCatService() => instance;
  RevenueCatService._internal();

  // Configuration constants - Platform-specific API keys
  // iOS API key (starts with 'appl_')
  static const String rcApiKeyIOS = 'appl_lUlEngvhNUyLxVfiSPfpksSqxLo';
  // Android API key (starts with 'goog_')
  static const String rcApiKeyAndroid = 'goog_rgtwHfnntJYJClPFpGHitgBNmSI';
  
  /// Get the appropriate API key for the current platform
  static String get rcApiKey {
    if (Platform.isIOS) {
      return rcApiKeyIOS;
    } else if (Platform.isAndroid) {
      return rcApiKeyAndroid;
    } else {
      // Fallback to iOS for other platforms
      return rcApiKeyIOS;
    }
  }

  static const String entitlementId = 'getmycar';
  static const String monthlyProductId = 'monthly_sub';
  static const String yearlyProductId = 'Yearly_sub';
  static const String offeringId = 'default';

  bool _isInitialized = false;
  CustomerInfo? _latestCustomerInfo;
  
  // Stream controller for entitlement state changes
  final _entitlementController = StreamController<bool>.broadcast();
  Stream<bool> get entitlementStream => _entitlementController.stream;

  /// Initialize RevenueCat SDK
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    try {
      // Configure RevenueCat with detailed logging for debugging
      await Purchases.setLogLevel(kDebugMode ? LogLevel.verbose : LogLevel.warn);
      
      // Initialize with API key
      PurchasesConfiguration configuration = PurchasesConfiguration(rcApiKey);
      await Purchases.configure(configuration);

      _isInitialized = true;
      
      if (kDebugMode) {
        debugPrint('✅ RevenueCat initialized with API key: ${rcApiKey.substring(0, 10)}...');
        debugPrint('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');
      }

      // Load initial customer info
      await _refreshCustomerInfo();
      
      // Debug: Check offerings availability and product availability
      if (kDebugMode) {
        try {
          // Check offerings
          final offerings = await Purchases.getOfferings();
          debugPrint('📦 Offerings available: ${offerings.current != null}');
          if (offerings.current != null) {
            debugPrint('📦 Packages count: ${offerings.current!.availablePackages.length}');
            for (var package in offerings.current!.availablePackages) {
              debugPrint('  - Package: ${package.identifier}, Product: ${package.storeProduct.identifier}');
            }
          } else {
            debugPrint('⚠️ No offerings available - checking products directly...');
          }
          
          // Try to fetch products directly to check sandbox availability
          try {
            final products = await Purchases.getProducts([monthlyProductId, yearlyProductId]);
            debugPrint('🔍 Direct product fetch: ${products.length} products found');
            if (products.isEmpty) {
              debugPrint('❌ Products not available in sandbox yet.');
              debugPrint('   This is normal if app was just submitted.');
              debugPrint('   Wait 24-48 hours for Apple to sync products to sandbox.');
              debugPrint('   Products are "Waiting for Review" but sandbox may not be ready.');
            } else {
              debugPrint('✅ Products ARE available in sandbox!');
              for (var product in products) {
                debugPrint('   - ${product.identifier}: ${product.title}');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Error checking products: $e');
          }
        } catch (e) {
          debugPrint('⚠️ Could not fetch offerings: $e');
        }
      }
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
    } catch (e) {
      // Silent - will retry on next request
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
      // Try to get offerings first
      Offerings? offerings;
      try {
        offerings = await Purchases.getOfferings();
        if (kDebugMode) {
          debugPrint('📦 Fetched offerings: ${offerings.current != null}');
          if (offerings.current != null) {
            debugPrint('📦 Available packages: ${offerings.current!.availablePackages.length}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error fetching offerings: $e');
        }
        // Silent - will use fallback
      }

      // Try to find package in offerings
      Package? packageToPurchase;
      if (offerings?.current != null && offerings!.current!.availablePackages.isNotEmpty) {
        try {
          packageToPurchase = offerings.current!.availablePackages.firstWhere(
            (package) => package.storeProduct.identifier == productId,
          );
        } catch (e) {
          packageToPurchase = null;
        }
      }

      CustomerInfo customerInfo;
      
      if (packageToPurchase != null) {
        // Purchase via package
        final result = await Purchases.purchasePackage(packageToPurchase);
        customerInfo = result.customerInfo;
      } else {
        // Fallback: Purchase by product ID directly
        try {
          if (kDebugMode) {
            debugPrint('🔍 Attempting to fetch product: $productId');
          }
          final products = await Purchases.getProducts([productId]);
          
          if (kDebugMode) {
            debugPrint('📦 Products fetched: ${products.length}');
            if (products.isNotEmpty) {
              debugPrint('📦 Product details: ${products.first.identifier}, ${products.first.title}');
            }
          }
          
          if (products.isEmpty) {
            // Provide clear error message based on RevenueCat best practices
            if (kDebugMode) {
              debugPrint('❌ Product "$productId" not found. Checking common issues...');
              debugPrint('   - Is app in "Waiting for Review"?');
              debugPrint('   - Are products attached to app version?');
              debugPrint('   - ⏳ Products can take 24-48 hours to sync to sandbox even when "Waiting for Review"');
              debugPrint('   - Has RevenueCat synced (wait 30-60 min after submission)?');
              debugPrint('   - Are you signed in with sandbox tester account?');
            }
            // Throw user-friendly error (technical details logged in debug mode only)
            if (kDebugMode) {
              debugPrint('❌ Product "$productId" not available in sandbox yet.');
              debugPrint('   - This is normal for TestFlight builds!');
              debugPrint('   - Products can take 24-48 hours to sync to sandbox');
              debugPrint('   - Your setup is correct - this is just a timing issue');
            }
            throw Exception('Subscription temporarily unavailable. Please try again later.');
          }
          
          final product = products.first;
          final result = await Purchases.purchaseStoreProduct(product);
          customerInfo = result.customerInfo;
        } on PlatformException catch (e) {
          // Handle RevenueCat specific errors
          final errorCode = PurchasesErrorHelper.getErrorCode(e);
          
          // Check error details for readable error code
          final readableErrorCode = e.details is Map 
              ? (e.details as Map)['readableErrorCode'] as String? 
              : null;
          
          // Check for product not available errors
          if (readableErrorCode == 'PRODUCT_NOT_AVAILABLE_FOR_PURCHASE' || 
              e.message?.contains('not available') == true ||
              e.message?.contains('ITEM_UNAVAILABLE') == true ||
              e.message?.contains('PRODUCT_NOT_AVAILABLE') == true) {
            if (kDebugMode) {
              debugPrint('❌ Product "$productId" is not available for purchase.');
              debugPrint('   - Product may be in "Ready to Submit" status');
              debugPrint('   - Product may not be attached to app version');
            }
            throw Exception('Subscription temporarily unavailable. Please try again later.');
          }
          rethrow;
        } catch (e) {
          if (e.toString().contains('Product not found') || 
              e.toString().contains('not found in App Store Connect') ||
              e.toString().contains('temporarily unavailable')) {
            rethrow;
          }
          if (kDebugMode) {
            debugPrint('❌ Failed to fetch/purchase product: $e');
          }
          throw Exception('Unable to complete purchase. Please try again later.');
        }
      }

      // Update local customer info
      _latestCustomerInfo = customerInfo;
      final isPro = isProActive();
      _entitlementController.add(isPro);

      return customerInfo;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      
      // Check if user cancelled
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        throw Exception('Purchase cancelled');
      }
      
      // Log technical details for debugging
      if (kDebugMode) {
        debugPrint('❌ Purchase error: ${e.message ?? errorCode.toString()}');
      }
      
      // User-friendly error message
      throw Exception('Unable to complete purchase. Please try again later.');
    } catch (e) {
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
      final customerInfo = await Purchases.restorePurchases();
      
      // Update local customer info
      _latestCustomerInfo = customerInfo;
      final isPro = isProActive();
      _entitlementController.add(isPro);

      return customerInfo;
    } catch (e) {
      rethrow;
    }
  }

  /// Get current customer info
  Future<CustomerInfo?> getCustomerInfo() async {
    try {
      await _refreshCustomerInfo();
      return _latestCustomerInfo;
    } catch (e) {
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _entitlementController.close();
  }
}
