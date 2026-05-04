class AppConfig {
  // Backend running on your development machine
  // IP: 10.224.247.221, Port: 5000
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.224.247.221:5000',
  );
}
