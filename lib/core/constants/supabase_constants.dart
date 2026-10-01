class SupabaseConstants {
  // Configured with your Supabase project credentials.
  static const String url = 'https://csvescnsdvgwagxfzsje.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNzdmVzY25zZHZnd2FneGZ6c2plIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3MDkxMTYsImV4cCI6MjA5NTI4NTExNn0.g7PmNE9ZNBFOfQ0He2E2akpG7-2M0rGODUakKXT3RTo';

  // Google OAuth Client IDs — replace with real values from Google Cloud Console
  // Web Client ID is required by Supabase to verify tokens server-side
  static const String googleWebClientId =
      '398688850525-6vvt83pansdfjcd0ga61r5iih0o51dad.apps.googleusercontent.com';
  // iOS Client ID is needed for the native Google Sign-In dialog on iOS
  static const String googleIosClientId =
      '398688850525-pjpr7aeb6ldavka8brreflrc4hdrafqe.apps.googleusercontent.com';
  // macOS Client ID for the native Google Sign-In dialog on macOS
  static const String googleMacOsClientId =
      '398688850525-pjpr7aeb6ldavka8brreflrc4hdrafqe.apps.googleusercontent.com';
  // Android Client ID for Google Sign-In
  static const String googleAndroidClientId =
      '398688850525-sbuq1739f8an0gl7p5q0s58voab5otgp.apps.googleusercontent.com';

  /// Loopback redirect for macOS browser OAuth (add to Supabase Auth redirect URLs).
  static const int oauthCallbackPort = 46489;
  static const String oauthRedirectUrl = 'http://127.0.0.1:46489/auth/callback';
}
