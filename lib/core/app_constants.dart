class AppConstants {
  const AppConstants._();

  static const appName = 'Anikin';
  static const juroApiBaseUrl = String.fromEnvironment('JURO_API_BASE_URL');
  static const anilistGraphqlEndpoint = 'https://graphql.anilist.co';
  static const defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/83.0.4103.116 Safari/537.36';
}
