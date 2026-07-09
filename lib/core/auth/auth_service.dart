import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';

import '../constants/supabase_constants.dart';
import 'macos_oauth_callback.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(Supabase.instance.client.auth);
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  // Watch authStateProvider to trigger rebuilds when auth state changes
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? Supabase.instance.client.auth.currentUser;
});

class AuthService {
  final GoTrueClient _auth;

  AuthService(this._auth);

  User? get currentUser => _auth.currentUser;

  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  bool get isAuthenticated => _auth.currentSession != null;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signUp(email: email, password: password);
    } catch (e) {
      debugPrint('Sign Up Error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithPassword(email: email, password: password);
    } catch (e) {
      debugPrint('Sign In Error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Sign Out Error: $e');
      rethrow;
    }
  }

  /// Google Sign-In flow.
  /// macOS uses browser OAuth (avoids native keychain/provisioning requirements).
  /// iOS/Android use native Google Sign-In + Supabase ID token exchange.
  Future<AuthResponse> signInWithGoogle() async {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return _signInWithGoogleBrowser();
    }

    try {
      String clientId = SupabaseConstants.googleIosClientId;
      if (defaultTargetPlatform == TargetPlatform.android) {
        clientId = SupabaseConstants.googleAndroidClientId;
      }

      await GoogleSignIn.instance.initialize(
        clientId: clientId,
        serverClientId: SupabaseConstants.googleWebClientId,
      );

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Missing Google ID token');
      }

      return await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<AuthResponse> _signInWithGoogleBrowser() async {
    final redirectUri = Uri.parse(SupabaseConstants.oauthRedirectUrl);

    try {
      final callbackFuture = waitForMacOsOAuthCallback(
        auth: _auth,
        redirectUri: redirectUri,
      );

      final launched = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUri.toString(),
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception('Could not open Google Sign-In in your browser');
      }

      final sessionResponse = await callbackFuture;
      final session = sessionResponse.session!;

      return AuthResponse(session: session, user: session.user);
    } on AuthException catch (e) {
      if (e.message.contains('redirect') ||
          e.message.contains('No code detected')) {
        throw Exception(
          'Add ${SupabaseConstants.oauthRedirectUrl} to Supabase Auth → URL Configuration → Redirect URLs, then try again.',
        );
      }
      rethrow;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Native Apple Sign-In flow.
  /// Uses sign_in_with_apple to present the Apple credential sheet,
  /// then authenticates with Supabase using signInWithIdToken.
  Future<AuthResponse> signInWithApple() async {
    try {
      final rawNonce = _auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        throw Exception('Missing Apple ID token');
      }

      return await _auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } catch (e) {
      debugPrint('Apple Sign-In Error: $e');
      rethrow;
    }
  }
}
