import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Platform-aware Google Sign-In configuration
  // For Android: don't specify clientId - it will auto-detect from google-services.json
  // For iOS: specify the client ID from GoogleService-Info.plist
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Only specify clientId for iOS, Android will auto-detect from google-services.json
    clientId: Platform.isIOS 
        ? '959667247262-622056adms0um9u38b53e26nlahooeal.apps.googleusercontent.com'
        : null,
  );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> getCurrentUserModel() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return UserModel.fromFirestore(doc);
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return _retryAuthOperation(() async {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Ensure user document exists
      await _ensureUserDocument(credential.user!);

      return credential;
    });
  }

  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return _retryAuthOperation(() async {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document
      await _ensureUserDocument(credential.user!);

      return credential;
    });
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In...');
      
      // First, sign out any existing Google account to ensure fresh sign-in
      await _googleSignIn.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        print('❌ Google sign-in was canceled by user');
        throw Exception('Google sign-in was canceled');
      }

      print('✅ Google account selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null) {
        print('❌ Failed to get ID token from Google');
        throw Exception('Failed to get ID token from Google');
      }

      print('✅ Got Google authentication tokens');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔐 Signing in to Firebase with Google credential...');

      // Sign in to Firebase with the Google credential (with retry)
      final userCredential = await _retryAuthOperation(() async {
        return await _auth.signInWithCredential(credential);
      });

      print('✅ Firebase authentication successful');

      // Ensure user document exists
      await _ensureUserDocument(userCredential.user!);

      return userCredential;
    } catch (e, stackTrace) {
      print('❌ Google Sign-In error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Generate a random nonce for Apple Sign-In security
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Returns the sha256 hash of [input] in hex notation.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Sign in with Apple (meets Guideline 4.8 requirements)
  Future<UserCredential> signInWithApple() async {
    try {
      if (!Platform.isIOS) {
        throw Exception('Sign in with Apple is only available on iOS');
      }

      print('🍎 Starting Sign in with Apple...');

      // Generate a secure random nonce
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      print('   Generated nonce for security');

      // Request Apple ID credential with nonce
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      print('✅ Apple ID credential received');
      print('   Identity Token: ${appleCredential.identityToken != null ? "Present" : "Missing"}');
      print('   Authorization Code: ${appleCredential.authorizationCode != null ? "Present" : "Missing"}');

      // Validate that we have the identity token
      if (appleCredential.identityToken == null) {
        throw Exception('Failed to get identity token from Apple');
      }

      // Create OAuth credential from Apple ID token
      // Firebase requires idToken, rawNonce, and accessToken (authorizationCode) for Apple Sign-In
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken!,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode, // Required for newer Firebase Auth versions
      );

      print('🔐 Signing in to Firebase with Apple credential...');

      // Sign in to Firebase with the Apple credential (with retry)
      final userCredential = await _retryAuthOperation(() async {
        return await _auth.signInWithCredential(oauthCredential);
      });

      print('✅ Firebase authentication successful');

      // Update user display name if provided (only on first sign-in)
      if (appleCredential.givenName != null || appleCredential.familyName != null) {
        final displayName = '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'.trim();
        if (displayName.isNotEmpty && userCredential.user?.displayName == null) {
          await userCredential.user?.updateDisplayName(displayName);
        }
      }

      // Ensure user document exists
      await _ensureUserDocument(userCredential.user!);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error during Sign in with Apple:');
      print('   Code: ${e.code}');
      print('   Message: ${e.message}');
      print('   Email: ${e.email}');
      print('   Credential: ${e.credential}');
      rethrow;
    } catch (e, stackTrace) {
      print('❌ Sign in with Apple error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Delete user account and all associated data (meets Guideline 5.1.1(v) requirements)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in');
    }

    try {
      final userId = user.uid;
      print('🗑️ Starting account deletion for user: $userId');

      // Delete user's Firestore data
      try {
        // Delete user document
        await _firestore.collection('users').doc(userId).delete();
        print('✅ User document deleted');

        // Delete user's parking sessions
        final parkingSessions = await _firestore
            .collection('parking_sessions')
            .where('userId', isEqualTo: userId)
            .get();

        final batch = _firestore.batch();
        for (var doc in parkingSessions.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print('✅ Parking sessions deleted (${parkingSessions.docs.length} sessions)');

        // Delete user's FCM tokens
        final fcmTokens = await _firestore
            .collection('fcm_tokens')
            .where('userId', isEqualTo: userId)
            .get();

        final tokenBatch = _firestore.batch();
        for (var doc in fcmTokens.docs) {
          tokenBatch.delete(doc.reference);
        }
        await tokenBatch.commit();
        print('✅ FCM tokens deleted');
      } catch (e) {
        print('⚠️ Warning: Failed to delete some Firestore data: $e');
        // Continue with account deletion even if Firestore deletion fails
      }

      // Delete Firebase Auth account
      await user.delete();
      print('✅ Firebase Auth account deleted');

      // Sign out to clear local state
      await _auth.signOut();
      print('✅ Account deletion completed');
    } catch (e, stackTrace) {
      print('❌ Account deletion error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Retry logic for transient Firebase errors
  Future<T> _retryAuthOperation<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        return await operation();
      } on FirebaseException catch (e) {
        // Check if it's a transient error that should be retried
        final isTransientError = e.code == 'unavailable' ||
            e.code == 'internal-error' ||
            e.code == 'deadline-exceeded' ||
            e.code == 'resource-exhausted' ||
            e.message?.toLowerCase().contains('transient') == true ||
            e.message?.toLowerCase().contains('unavailable') == true;

        if (isTransientError && attempt < maxRetries - 1) {
          attempt++;
          print('⚠️ Transient error (${e.code}), retrying in ${delay.inSeconds}s (attempt $attempt/$maxRetries)...');
          await Future.delayed(delay);
          delay = Duration(seconds: delay.inSeconds * 2); // Exponential backoff
          continue;
        }
        // If not transient or max retries reached, rethrow
        rethrow;
      } catch (e) {
        // For non-Firebase exceptions, check if it's a network error
        final isNetworkError = e.toString().toLowerCase().contains('network') ||
            e.toString().toLowerCase().contains('connection') ||
            e.toString().toLowerCase().contains('unavailable');

        if (isNetworkError && attempt < maxRetries - 1) {
          attempt++;
          print('⚠️ Network error, retrying in ${delay.inSeconds}s (attempt $attempt/$maxRetries)...');
          await Future.delayed(delay);
          delay = Duration(seconds: delay.inSeconds * 2);
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Max retries reached');
  }

  Future<void> _ensureUserDocument(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();

      if (!doc.exists) {
        print('📝 Creating user document for: ${user.email}');
        await userRef.set({
          'email': user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'plan': 'free',
        });
        print('✅ User document created');
      } else {
        print('✅ User document already exists');
      }
    } catch (e) {
      print('⚠️ Warning: Failed to create/update user document: $e');
      // Don't throw - authentication succeeded even if document creation fails
      // The document can be created later
    }
  }
}

