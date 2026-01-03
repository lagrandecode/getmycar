import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // iOS client ID from GoogleService-Info.plist
    clientId: '959667247262-622056adms0um9u38b53e26nlahooeal.apps.googleusercontent.com',
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

