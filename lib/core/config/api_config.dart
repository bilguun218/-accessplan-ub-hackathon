class ApiConfig {
  // USB debug + `adb reverse tcp:5000 tcp:5000` ашиглаж байгаа тул localhost.
  // Wi-Fi-р бол: 'http://192.168.15.169:5000/api'
  // Emulator-ийн хувьд:    'http://10.0.2.2:5000/api'
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );
}
