class AppConfig {
  // For physical Android devices over USB, run:
  // adb reverse tcp:5000 tcp:5000
  // This makes device localhost:5000 point to your computer backend.
  // Override with --dart-define=API_BASE_URL=... when needed.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5000',
  );

  // Cloudinary configuration (use compile-time env or set defaults)
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: '',
  );

  static const String cloudinaryUploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: '',
  );
}
