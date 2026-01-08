import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _radarController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _radarAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    _radarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
    _radarController.forward();

    // Navigate after animation completes
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        context.go('/onboarding-paywall');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final backgroundColor = brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    final radarColor = brightness == Brightness.dark
        ? Colors.red.withValues(alpha: 0.15)
        : Colors.red.withValues(alpha: 0.2);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Radar/signal circles behind logo
            AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer circle
                    _buildRadarCircle(
                      280,
                      radarColor,
                      _radarAnimation.value,
                      0.0,
                    ),
                    // Middle circle
                    _buildRadarCircle(
                      240,
                      radarColor,
                      _radarAnimation.value,
                      0.3,
                    ),
                    // Inner circle
                    _buildRadarCircle(
                      200,
                      radarColor,
                      _radarAnimation.value,
                      0.6,
                    ),
                  ],
                );
              },
            ),
            // Logo on top
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                );
              },
              child: Image.asset(
                'assets/icon/app_icon_splash.png',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarCircle(double size, Color color, double animationValue, double delay) {
    final adjustedValue = ((animationValue + delay) % 1.0);
    final opacity = (1.0 - adjustedValue) * 0.6;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 2.0,
        ),
      ),
    );
  }
}

