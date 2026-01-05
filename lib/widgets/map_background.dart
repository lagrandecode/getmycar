import 'package:flutter/material.dart';

/// A reusable background widget that displays map-inspired backgrounds
/// based on the current theme brightness (light/dark).
/// 
/// This widget provides a cohesive, immersive background experience
/// that adapts to light and dark themes using the provided background assets.
class MapBackground extends StatelessWidget {
  /// The child widget to display over the background
  final Widget child;

  /// Optional opacity for the background image (0.0 to 1.0)
  /// Default is 0.6 for subtle blending
  final double backgroundOpacity;

  /// Optional overlay opacity for additional blending
  /// Default is 0.4 for readability
  final double overlayOpacity;

  const MapBackground({
    super.key,
    required this.child,
    this.backgroundOpacity = 0.6,
    this.overlayOpacity = 0.4,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final backgroundAsset = isDark 
        ? 'assets/icon/dark.jpg' 
        : 'assets/icon/light.jpg';

    return Stack(
      children: [
        // Background image layer
        Positioned.fill(
          child: Image.asset(
            backgroundAsset,
            fit: BoxFit.cover,
            opacity: AlwaysStoppedAnimation(backgroundOpacity),
          ),
        ),
        // Subtle gradient overlay for better blending
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (isDark ? Colors.black : Colors.white).withValues(
                    alpha: overlayOpacity * 0.3,
                  ),
                  (isDark ? Colors.black : Colors.white).withValues(
                    alpha: overlayOpacity * 0.5,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Subtle vignette for depth
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  Colors.transparent,
                  (isDark ? Colors.black : Colors.black).withValues(
                    alpha: overlayOpacity * 0.2,
                  ),
                ],
              ),
            ),
          ),
        ),
        // Content layer
        child,
      ],
    );
  }
}

