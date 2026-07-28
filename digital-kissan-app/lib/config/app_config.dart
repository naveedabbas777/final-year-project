class AppConfig {
  // Default to the deployed Render backend.
  // Override with --dart-define=API_BASE_URL=... for local development.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://digital-kissan-backend.onrender.com',
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
