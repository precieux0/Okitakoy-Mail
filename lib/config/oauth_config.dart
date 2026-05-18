class OAuthConfig {
  // Google
  static const googleWebClientId =
      '114601066380-4cfloq6ldgrrsi8j9odmp830er6g4rui.apps.googleusercontent.com';

  // GitHub – lus depuis --dart-define
  static final String githubClientId =
      const String.fromEnvironment('GITHUB_CLIENT_ID', defaultValue: '');

  static final String githubClientSecret =
      const String.fromEnvironment('GITHUB_CLIENT_SECRET', defaultValue: '');

  // Pour GitHub, on utilise une redirection HTTP locale (obligatoire)
  static const String githubRedirectUri = 'http://localhost:53069/callback';
}
