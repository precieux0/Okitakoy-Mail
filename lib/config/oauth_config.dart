class OAuthConfig {
  static const googleWebClientId =
      '114601066380-4cfloq6ldgrrsi8j9odmp830er6g4rui.apps.googleusercontent.com';

  static final String githubClientId =
      const String.fromEnvironment('GITHUB_CLIENT_ID', defaultValue: '');

  static final String githubClientSecret =
      const String.fromEnvironment('GITHUB_CLIENT_SECRET', defaultValue: '');

  static const String callbackScheme = 'okitakoymail';
  static const String githubRedirectUri = 'https://precieux0.github.io/Okitakoy-Mail/callback.html';
}
