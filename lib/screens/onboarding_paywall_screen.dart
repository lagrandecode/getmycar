import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../services/revenuecat_service.dart';

/// Onboarding/Paywall screen with video slideshow and subscription options
class OnboardingPaywallScreen extends StatefulWidget {
  const OnboardingPaywallScreen({super.key});

  @override
  State<OnboardingPaywallScreen> createState() => _OnboardingPaywallScreenState();
}

class _OnboardingPaywallScreenState extends State<OnboardingPaywallScreen> {
  VideoPlayerController? _videoController1;
  VideoPlayerController? _videoController2;
  bool _videosInitialized = false;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  static const int videosPerSlide = 4;

  @override
  void initState() {
    super.initState();
    _initializeVideos();
  }

  Future<void> _initializeVideos() async {
    try {
      // Initialize first video
      _videoController1 = VideoPlayerController.asset('assets/images/intro1.mp4');
      await _videoController1!.initialize();
      _videoController1!.setVolume(0);
      _videoController1!.setLooping(true);
      _videoController1!.play();
      
      // Initialize second video
      _videoController2 = VideoPlayerController.asset('assets/images/intro2.mp4');
      await _videoController2!.initialize();
      _videoController2!.setVolume(0);
      _videoController2!.setLooping(true);
      _videoController2!.play();
      
      if (mounted) {
        setState(() {
          _videosInitialized = true;
        });
      }
    } catch (e) {
      print('❌ Error initializing videos: $e');
      if (mounted) {
        setState(() {
          _videosInitialized = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController1?.dispose();
    _videoController2?.dispose();
    super.dispose();
  }
  
  VideoPlayerController? _getVideoController(int gridIndex) {
    final videoIndex = gridIndex % 2;
    return videoIndex == 0 ? _videoController1 : _videoController2;
  }

  Future<void> _handleTryForFree() async {
    if (_isPurchasing || _isRestoring) return;
    
    setState(() => _isPurchasing = true);
    
    try {
      // Purchase monthly subscription
      await RevenueCatService.instance.purchaseMonthlyOrYearly(
        productId: RevenueCatService.monthlyProductId,
      );
      
      // Check if purchase was successful
      final isPro = RevenueCatService.instance.isProActive();
      
      if (mounted) {
        if (isPro) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Subscription activated! Enjoy your 3-day free trial.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Navigate to login screen (replace so user can't go back)
          if (mounted) {
            context.go('/login');
          }
        } else {
          // Purchase completed but entitlement not active (shouldn't happen, but handle it)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase completed. Please wait a moment...'),
              backgroundColor: Colors.orange,
            ),
          );
          // Still navigate to login
          if (mounted) {
            context.go('/login');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().contains('cancelled') 
            ? 'Purchase was cancelled'
            : 'Purchase failed: ${e.toString().replaceAll('Exception: ', '')}';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    if (_isPurchasing || _isRestoring) return;
    
    setState(() => _isRestoring = true);
    
    try {
      await RevenueCatService.instance.restore();
      
      // Check if restore was successful
      final isPro = RevenueCatService.instance.isProActive();
      
      if (mounted) {
        if (isPro) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Restored successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          // Navigate to login screen
          if (mounted) {
            context.go('/login');
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active subscription found.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }
  final String policy = "https://drive.google.com/file/d/1rBy54sZjFmPrHDUoZxh4WOmR6Mu34tpw/view?usp=drive_link";
  Uri get _url => Uri.parse(policy);

  Future<void> _handleTerms() async {
    // TODO: Navigate to terms screen or open URL
    if(!await launchUrl(_url,mode: LaunchMode.externalApplication)){
      throw Exception("Could not Launch $_url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate responsive sizes
    final isSmallScreen = screenHeight < 700;
    final horizontalPadding = screenWidth * 0.06; // 6% of screen width
    final verticalPadding = screenHeight * 0.02; // 2% of screen height
    
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top content: Title and Subtitle
                  Flexible(
                    flex: isSmallScreen ? 2 : 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Never Lose Your Car Again',
                          style: textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen 
                                ? textTheme.headlineMedium?.fontSize 
                                : textTheme.headlineLarge?.fontSize,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 12),
                        Text(
                          'Save your parking spot and navigate back easily',
                          style: textTheme.bodyLarge?.copyWith(
                            color: theme.brightness == Brightness.light
                                ? Colors.black
                                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: theme.brightness == Brightness.light
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: isSmallScreen 
                                ? textTheme.bodyMedium?.fontSize 
                                : textTheme.bodyLarge?.fontSize,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  
                  // Media section: Video grid
                  Flexible(
                    flex: isSmallScreen ? 5 : 6,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return _buildVideoCarousel(theme, constraints.maxHeight);
                      },
                    ),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  
                  // Paywall area
                  Flexible(
                    flex: isSmallScreen ? 3 : 4,
                    child: _buildPaywallSection(theme, textTheme, isSmallScreen),
                  ),
                  
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  
                  // Footer links
                  _buildFooterLinks(theme, textTheme),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoCarousel(ThemeData theme, double availableHeight) {
    // Calculate responsive height based on available space
    // Use availableHeight directly from the Flexible widget
    final carouselHeight = availableHeight.clamp(200.0, 450.0);
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: carouselHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _buildVideoGrid(theme),
      ),
    );
  }

  Widget _buildVideoGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate the available space for the grid
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final padding = 16.0; // Total padding (8.0 * 2 on each side)
        final spacing = 8.0; // Spacing between grid items
        
        // Calculate item dimensions
        final itemWidth = (availableWidth - padding - spacing) / 2;
        final itemHeight = (availableHeight - padding - spacing) / 2;
        final aspectRatio = itemWidth / itemHeight;
        
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: aspectRatio,
            ),
            itemCount: videosPerSlide,
            itemBuilder: (context, gridIndex) {
              if (!_videosInitialized) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              
              final controller = _getVideoController(gridIndex);
              if (controller == null || !controller.value.isInitialized) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              }
              
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(controller),
                    // Subtle gradient overlay for better visual appeal
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }


  Widget _buildPaywallSection(ThemeData theme, TextTheme textTheme, bool isSmallScreen) {
    // Calculate pricing text font size safely
    final baseFontSize = textTheme.bodySmall?.fontSize;
    final pricingFontSize = baseFontSize != null && isSmallScreen 
        ? baseFontSize * 0.9 
        : baseFontSize;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // "No payment due now" row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: isSmallScreen ? 18 : 20,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Flexible(
              child: Text(
                'No payment due now',
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.brightness == Brightness.light
                      ? Colors.black
                      : theme.colorScheme.primary,
                  fontWeight: theme.brightness == Brightness.light
                      ? FontWeight.bold
                      : FontWeight.w500,
                  fontSize: isSmallScreen 
                      ? textTheme.bodySmall?.fontSize 
                      : textTheme.bodyMedium?.fontSize,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        
        // Primary CTA button
        ElevatedButton(
          onPressed: (_isPurchasing || _isRestoring) ? null : _handleTryForFree,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB62730),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              vertical: isSmallScreen ? 12 : 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: _isPurchasing
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Try for free 🙌',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen 
                        ? textTheme.bodyLarge?.fontSize 
                        : textTheme.titleMedium?.fontSize,
                  ),
                ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        
        // Pricing
        Text(
          '3 days free, then \$9.99/mo',
          style: textTheme.bodySmall?.copyWith(
            color: theme.brightness == Brightness.light
                ? Colors.black
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: theme.brightness == Brightness.light
                ? FontWeight.bold
                : FontWeight.normal,
            fontSize: pricingFontSize,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFooterLinks(ThemeData theme, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        TextButton(
          onPressed: (_isPurchasing || _isRestoring) ? null : _handleRestore,
          child: _isRestoring
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.brightness == Brightness.light
                          ? Colors.black
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                )
              : Text(
                  'Restore',
                  style: textTheme.bodySmall?.copyWith(
                    color: theme.brightness == Brightness.light
                        ? Colors.black
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: theme.brightness == Brightness.light
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
        ),
        TextButton(
          onPressed: _handleTerms,
          child: Text(
            'Terms',
            style: textTheme.bodySmall?.copyWith(
              color: theme.brightness == Brightness.light
                  ? Colors.black
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: theme.brightness == Brightness.light
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

