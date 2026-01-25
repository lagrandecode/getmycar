import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Prominent disclosure dialog for location permission (required by Google Play)
/// This must be shown before requesting background location permission
class LocationDisclosureDialog extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback? onCancel;

  const LocationDisclosureDialog({
    super.key,
    required this.onContinue,
    this.onCancel,
  });

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must explicitly accept or decline
      builder: (context) => LocationDisclosureDialog(
        onContinue: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon
            Icon(
              Icons.location_on,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),

            // Title - MUST be prominent
            Text(
              'Location Access Required',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Prominent disclosure text - Following Google Play's required format
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Required format: "[This app] collects [type of data] to enable ["feature"], [in what scenario]."
                  Text(
                    Platform.isAndroid
                        ? 'Get My Car collects location data to enable parking spot saving and navigation to your parked car, even when the app is closed or not in use, including when your car\'s Bluetooth disconnects.'
                        : 'Get My Car collects location data to enable parking spot saving and navigation to your parked car.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Additional details in bullet format
                  Text(
                    'This allows the app to:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildBulletPoint(
                    theme,
                    'Save your car\'s parking location when you park',
                  ),
                  const SizedBox(height: 6),
                  _buildBulletPoint(
                    theme,
                    'Navigate you back to your parked car',
                  ),
                  if (Platform.isAndroid) ...[
                    const SizedBox(height: 6),
                    _buildBulletPoint(
                      theme,
                      'Automatically save your parking spot when your car\'s Bluetooth disconnects',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Additional info about data usage
            Text(
              Platform.isAndroid
                  ? 'Location data is used only for parking spot saving and navigation features. You can revoke this permission at any time in your device settings.'
                  : 'Location data is used only for parking spot saving and navigation features. You can revoke this permission at any time in your device settings.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                if (onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Not Now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulletPoint(ThemeData theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            fontSize: 18,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
