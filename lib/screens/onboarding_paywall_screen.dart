import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';
import '../services/notification_service.dart';

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
  
  // Dynamic pricing
  String? _monthlyPrice;
  String? _yearlyPrice;
  bool _isLoadingPrice = false;

  @override
  void initState() {
    super.initState();
    _initializeVideos();
    _loadProductPrices();
  }
  
  /// Load product prices from RevenueCat in user's local currency
  Future<void> _loadProductPrices() async {
    setState(() => _isLoadingPrice = true);
    
    try {
      // Fetch products from RevenueCat
      final products = await Purchases.getProducts([
        RevenueCatService.monthlyProductId,
        RevenueCatService.yearlyProductId,
      ]);
      
      if (mounted) {
        // Find monthly product
        final monthlyProduct = products.firstWhere(
          (p) => p.identifier == RevenueCatService.monthlyProductId,
          orElse: () => products.isNotEmpty ? products.first : throw Exception('Product not found'),
        );
        
        // Find yearly product
        final yearlyProduct = products.firstWhere(
          (p) => p.identifier == RevenueCatService.yearlyProductId,
          orElse: () => products.length > 1 ? products[1] : throw Exception('Product not found'),
        );
        
        setState(() {
          // Format price with currency symbol (e.g., "$9.99" or "₦4,500")
          _monthlyPrice = monthlyProduct.priceString;
          _yearlyPrice = yearlyProduct.priceString;
          _isLoadingPrice = false;
        });
      }
    } catch (e) {
      // Fallback to default prices
      if (mounted) {
        setState(() {
          _monthlyPrice = '\$9.99';
          _yearlyPrice = null; // Will show monthly only if yearly fails
          _isLoadingPrice = false;
        });
      }
    }
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
          // Show success notification
          await NotificationService.showLocalNotification(
            title: '✅ Subscription Activated!',
            body: 'Enjoy your 3-day free trial.',
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
  // Terms of Use (EULA) URL - Required by Apple
  final String termsOfUseUrl = "https://sites.google.com/view/getmycarterms?usp=sharing";
  
  // Privacy Policy URL - Required by Apple
  final String privacyPolicyUrl = "https://sites.google.com/view/getmycarprivacypolicy?usp=sharing";

  Future<void> _handleTerms() async {
    try {
      final uri = Uri.parse(termsOfUseUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception("Could not launch Terms of Use URL");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Terms of Use: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handlePrivacyPolicy() async {
    try {
      final uri = Uri.parse(privacyPolicyUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception("Could not launch Privacy Policy URL");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Privacy Policy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            
            return SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Top content: Title and Subtitle
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
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
                  
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  
                  // Media section: Video grid
                  _buildVideoCarousel(theme, isSmallScreen ? 250.0 : 300.0),
                  
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  
                  // Paywall area
                  _buildPaywallSection(theme, textTheme, isSmallScreen),
                  
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  
                  // Footer links
                  _buildFooterLinks(theme, textTheme),
                  ],
                ),
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
    // Get the price to display (with fallback)
    final displayPrice = _monthlyPrice ?? '\$9.99';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Primary pricing - MUST be prominent (Apple requirement)
        _isLoadingPrice
            ? SizedBox(
                height: isSmallScreen ? 24 : 28,
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
              )
            : Text(
                '$displayPrice/month',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.light
                      ? Colors.black
                      : Colors.white,
                  fontSize: isSmallScreen 
                      ? textTheme.titleLarge?.fontSize 
                      : textTheme.headlineSmall?.fontSize,
                ),
                textAlign: TextAlign.center,
              ),
        SizedBox(height: isSmallScreen ? 4 : 6),
        
        // Free trial info - secondary (less prominent)
        _isLoadingPrice
            ? const SizedBox.shrink()
            : Text(
                '3-day free trial, then $displayPrice/month',
                style: textTheme.bodyMedium?.copyWith(
                  color: theme.brightness == Brightness.light
                      ? Colors.black87
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: isSmallScreen 
                      ? textTheme.bodySmall?.fontSize 
                      : textTheme.bodyMedium?.fontSize,
                ),
                textAlign: TextAlign.center,
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
                  'Start Free Trial',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen 
                        ? textTheme.bodyLarge?.fontSize 
                        : textTheme.titleMedium?.fontSize,
                  ),
                ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        
        // Subscription details
        Text(
          'Auto-renews monthly. Cancel anytime.',
          style: textTheme.bodySmall?.copyWith(
            color: theme.brightness == Brightness.light
                ? Colors.black54
                : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: isSmallScreen 
                ? textTheme.bodySmall?.fontSize 
                : textTheme.bodySmall?.fontSize,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFooterLinks(ThemeData theme, TextTheme textTheme) {
    return Column(
      children: [
        // Required links - Terms of Use and Privacy Policy (Apple requirement)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton(
              onPressed: _handleTerms,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Terms of Use',
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '•',
              style: textTheme.bodySmall?.copyWith(
                color: theme.brightness == Brightness.light
                    ? Colors.black54
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            TextButton(
              onPressed: _handlePrivacyPolicy,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Privacy Policy',
                style: textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        // Restore purchases button
        TextButton(
          onPressed: (_isPurchasing || _isRestoring) ? null : _handleRestore,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
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
                  'Restore Purchases',
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

