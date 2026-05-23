class AppConstants {
  const AppConstants._();

  static const appName = 'Anikin';
    static const appVersion = '3.0.8+51';
  static const juroApiBaseUrl = String.fromEnvironment('JURO_API_BASE_URL');
  static const anilistGraphqlEndpoint = 'https://graphql.anilist.co';
  static const githubLatestReleaseEndpoint =
      'https://api.github.com/repos/jerry08/Anikin/releases/latest';
  static const githubReleasesUrl = 'https://github.com/jerry08/Anikin/releases';
  static const defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36';
}
