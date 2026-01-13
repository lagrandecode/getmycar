import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/revenuecat_service.dart';

/// Helper functions for subscription/feature gating
class SubscriptionHelper {
  /// Check if user has pro access
  static Future<bool> isPro() async {
    return await RevenueCatService.instance.isProActiveAsync();
  }

  /// Check if user has pro access (synchronous, uses cached state)
  static bool isProSync() {
    return RevenueCatService.instance.isProActive();
  }

  /// Require pro access - shows dialog if user doesn't have pro
  /// Returns true if user has pro, false otherwise
  static Future<bool> requirePro(BuildContext context) async {
    final hasPro = await isPro();
    
    if (!hasPro) {
      _showProRequiredDialog(context);
      return false;
    }
    
    return true;
  }

  /// Show dialog that pro is required
  static void _showProRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Get My Car Pro Required'),
        content: const Text(
          'This feature requires Get My Car Pro subscription. '
          'Subscribe to unlock premium features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to paywall (you can change this route if needed)
              context.go('/onboarding-paywall');
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }
}
