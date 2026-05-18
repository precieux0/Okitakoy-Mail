class OAuthConfig {
  // Google
  static const googleWebClientId =
      '114601066380-4cfloq6ldgrrsi8j9odmp830er6g4rui.apps.googleusercontent.com';

  // GitHub - lues depuis les dart-defines passés au build
  static final String githubClientId =
      const String.fromEnvironment('GITHUB_CLIENT_ID', defaultValue: '');

  static final String githubClientSecret =
      const String.fromEnvironment('GITHUB_CLIENT_SECRET', defaultValue: '');

  // Redirection URI : basée sur le schéma personnalisé
  static const String callbackScheme = 'okitakoymail';
  static String get githubRedirectUri => '$callbackScheme://callback';
}