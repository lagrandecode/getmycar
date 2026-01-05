import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isSignUp = false;
  VideoPlayerController? _videoController;
  int _currentVideoIndex = 0;
  bool _isSwitchingVideo = false;
  final List<String> _videoPaths = [
    'assets/images/intro1.mp4',
    'assets/images/intro2.mp4',
  ];

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.asset(_videoPaths[_currentVideoIndex]);
    await _videoController!.initialize();
    _videoController!.setVolume(0); // Mute the video
    _videoController!.play();
    
    // Listen for video completion and switch to next video
    _videoController!.addListener(_onVideoStatusChanged);
    
    if (mounted) {
      setState(() {});
    }
  }

  void _onVideoStatusChanged() {
    if (_isSwitchingVideo || 
        _videoController == null || 
        !_videoController!.value.isInitialized ||
        _videoController!.value.duration == Duration.zero) {
      return;
    }
    
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    
    // Check if video has reached the end (within 200ms threshold)
    if (position + const Duration(milliseconds: 200) >= duration) {
      // Current video finished, switch to next
      _switchToNextVideo();
    }
  }

  Future<void> _switchToNextVideo() async {
    if (!mounted || _isSwitchingVideo) return;
    
    _isSwitchingVideo = true;
    
    try {
      // Remove listener before disposing
      _videoController?.removeListener(_onVideoStatusChanged);
      
      // Dispose current controller
      await _videoController?.dispose();
      
      // Move to next video (loop back to first after last)
      _currentVideoIndex = (_currentVideoIndex + 1) % _videoPaths.length;
      
      // Initialize next video
      _videoController = VideoPlayerController.asset(_videoPaths[_currentVideoIndex]);
      await _videoController!.initialize();
      _videoController!.setVolume(0); // Mute the video
      
      // Listen for completion again before playing
      _videoController!.addListener(_onVideoStatusChanged);
      
      _videoController!.play();
      
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isSwitchingVideo = false;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _videoController?.removeListener(_onVideoStatusChanged);
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      print('🔐 Attempting ${_isSignUp ? "sign up" : "sign in"} for: $email');
      
      if (_isSignUp) {
        await authService.signUpWithEmailAndPassword(email, password);
        print('✅ Sign up successful');
      } else {
        await authService.signInWithEmailAndPassword(email, password);
        print('✅ Sign in successful');
      }

      // Navigate after authentication - use SchedulerBinding to ensure safe timing
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            try {
              final router = GoRouter.maybeOf(context);
              if (router != null && !router.canPop()) {
                router.go('/home');
              }
            } catch (e) {
              print('⚠️ Navigation error: $e');
            }
          });
        });
      }
    } on FirebaseException catch (e) {
      print('❌ Firebase error: ${e.code} - ${e.message}');
      String errorMessage = 'Authentication failed';
      
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No user found with this email. Please sign up first.';
          break;
        case 'wrong-password':
          errorMessage = 'Wrong password. Please try again.';
          break;
        case 'email-already-in-use':
          errorMessage = 'This email is already registered. Please sign in instead.';
          break;
        case 'weak-password':
          errorMessage = 'Password is too weak. Please use a stronger password (at least 6 characters).';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email address. Please check your email.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/Password authentication is not enabled. Please contact support.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled. Please contact support.';
          break;
        case 'unavailable':
        case 'internal-error':
          errorMessage = 'Service temporarily unavailable. Please try again in a moment.';
          break;
        default:
          errorMessage = 'Error: ${e.message ?? e.code}\n\nCode: ${e.code}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ Unexpected error: $e');
      print('Stack trace: $stackTrace');
      
      String errorMessage = 'Authentication error';
      final errorStr = e.toString().toLowerCase();
      
      if (errorStr.contains('firebase') || errorStr.contains('firebase')) {
        errorMessage = 'Firebase not configured properly. Please check your configuration files.';
      } else if (errorStr.contains('network') || errorStr.contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Unexpected error: ${e.toString()}';
      }
        
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      await authService.signInWithGoogle();

      // Navigate after authentication - use SchedulerBinding to ensure safe timing
      if (mounted) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            try {
              final router = GoRouter.maybeOf(context);
              if (router != null && !router.canPop()) {
                router.go('/home');
              }
            } catch (e) {
              print('⚠️ Navigation error: $e');
            }
          });
        });
      }
    } on FirebaseException catch (e) {
      String errorMessage = 'Google Sign-In failed';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'An account already exists with this email. Please sign in with email/password.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = 'Network error. Please check your connection and try again.';
      } else {
        errorMessage = 'Error: ${e.message ?? e.code}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'Google Sign-In error';
      if (e.toString().contains('canceled')) {
        errorMessage = 'Sign-in was canceled';
      } else {
        errorMessage = 'Error: ${e.toString()}';
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full screen video background
          if (_videoController != null && _videoController!.value.isInitialized)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController!.value.size.width,
                  height: _videoController!.value.size.height,
                  child: VideoPlayer(_videoController!),
                ),
              ),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          // Dark overlay for better text readability
          Container(
            color: Colors.black.withValues(alpha: 0.5),
          ),
          // Login form content
          SafeArea(
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      const SizedBox(height: 32),
                      Text(
                        _isSignUp ? 'Create Account' : '',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  const SizedBox(height: 48),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.email, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          thickness: 1,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          thickness: 1,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    icon: const Icon(Icons.g_mobiledata, size: 20, color: Colors.white),
                    label: const Text('Continue with Google', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() => _isSignUp = !_isSignUp);
                          },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : 'Don\'t have an account? Sign Up',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

