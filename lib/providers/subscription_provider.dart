import 'package:flutter/foundation.dart';
import '../services/revenuecat_service.dart';

/// Provider for subscription state management
class SubscriptionProvider extends ChangeNotifier {
  bool _isPro = false;
  bool _isLoading = false;

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;

  SubscriptionProvider() {
    _initialize();
  }

  /// Initialize subscription status
  Future<void> _initialize() async {
    _setLoading(true);
    try {
      _isPro = await RevenueCatService.instance.isProActiveAsync();
      _setLoading(false);
    } catch (e) {
      debugPrint('⚠️ Error initializing subscription: $e');
      _setLoading(false);
    }
  }

  /// Refresh subscription status
  Future<void> refresh() async {
    _setLoading(true);
    try {
      _isPro = await RevenueCatService.instance.isProActiveAsync();
      _setLoading(false);
    } catch (e) {
      debugPrint('⚠️ Error refreshing subscription: $e');
      _setLoading(false);
    }
  }

  /// Set pro status
  void setPro(bool value) {
    if (_isPro != value) {
      _isPro = value;
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    if (_isLoading != value) {
      _isLoading = value;
      notifyListeners();
    }
  }

}
