import 'dart:io';

import 'package:dotenv/dotenv.dart';

/// Integration test configuration loaded from .env.test file
///
/// This class manages all test environment configuration including:
/// - n8n cloud instance URL and credentials
/// - Test workflow webhook IDs
/// - Test execution parameters (timeouts, retries, polling intervals)
/// - CI/CD configuration
///
/// Usage:
/// ```dart
/// final config = TestConfig.load();
/// print('Testing against: ${config.baseUrl}');
/// ```
class TestConfig {
  // n8n Cloud Configuration
  final String baseUrl;
  final String? apiKey;

  // Test Workflow Webhook IDs
  final String simpleWebhookId;
  final String waitNodeWebhookId;
  final String slowWebhookId;
  final String errorWebhookId;

  // Test Configuration
  final int timeoutSeconds;
  final int maxRetries;
  final int pollingIntervalMs;

  // CI/CD Configuration
  final bool runIntegrationTests;
  final bool skipSlowTests;

  // Supabase Configuration (for Phase 3)
  final String? supabaseUrl;
  final String? supabaseKey;
  final String? supabaseDbHost;
  final String? supabaseDbPassword;

  const TestConfig({
    required this.baseUrl,
    required this.simpleWebhookId,
    required this.waitNodeWebhookId,
    required this.slowWebhookId,
    required this.errorWebhookId,
    this.apiKey,
    this.timeoutSeconds = 300,
    this.maxRetries = 3,
    this.pollingIntervalMs = 2000,
    this.runIntegrationTests = true,
    this.skipSlowTests = false,
    this.supabaseUrl,
    this.supabaseKey,
    this.supabaseDbHost,
    this.supabaseDbPassword,
  });

  /// Load test configuration from .env.test file
  ///
  /// Throws [FileSystemException] if .env.test file doesn't exist
  /// Throws [ArgumentError] if required environment variables are missing
  factory TestConfig.load() {
    // Check if .env.test file exists
    final envFile = File('.env.test');
    if (!envFile.existsSync()) {
      throw const FileSystemException(
        'Integration test configuration file not found.\n'
        'Please copy .env.test.example to .env.test and configure your credentials.\n'
        'See test/integration/README.md for setup instructions.',
        '.env.test',
      );
    }

    // Load environment variables
    final env = DotEnv()..load(['.env.test']);

    // Helper to get required environment variable
    String getRequired(String key) {
      final value = env[key];
      if (value == null || value.isEmpty) {
        throw ArgumentError(
          'Required environment variable $key is missing or empty in .env.test',
        );
      }
      return value;
    }

    // Helper to get optional environment variable
    String? getOptional(String key) {
      final value = env[key];
      return (value == null || value.isEmpty) ? null : value;
    }

    // Helper to get integer with default
    int getInt(String key, int defaultValue) {
      final value = env[key];
      if (value == null || value.isEmpty) return defaultValue;
      return int.tryParse(value) ?? defaultValue;
    }

    // Helper to get boolean with default
    bool getBool(String key, bool defaultValue) {
      final value = env[key];
      if (value == null || value.isEmpty) return defaultValue;
      return value.toLowerCase() == 'true';
    }

    return TestConfig(
      // n8n Cloud Configuration
      baseUrl: getRequired('N8N_BASE_URL'),
      apiKey: getOptional('N8N_API_KEY'),

      // Test Workflow Webhook IDs
      simpleWebhookId: getRequired('N8N_SIMPLE_WEBHOOK_ID'),
      waitNodeWebhookId: getRequired('N8N_WAIT_NODE_WEBHOOK_ID'),
      slowWebhookId: getRequired('N8N_SLOW_WEBHOOK_ID'),
      errorWebhookId: getRequired('N8N_ERROR_WEBHOOK_ID'),

      // Test Configuration
      timeoutSeconds: getInt('TEST_TIMEOUT_SECONDS', 300),
      maxRetries: getInt('TEST_MAX_RETRIES', 3),
      pollingIntervalMs: getInt('TEST_POLLING_INTERVAL_MS', 2000),

      // CI/CD Configuration
      runIntegrationTests: getBool('CI_RUN_INTEGRATION_TESTS', true),
      skipSlowTests: getBool('CI_SKIP_SLOW_TESTS', false),

      // Supabase Configuration (optional for Phase 3)
      supabaseUrl: getOptional('SUPABASE_URL'),
      supabaseKey: getOptional('SUPABASE_KEY'),
      supabaseDbHost: getOptional('SUPABASE_DB_HOST'),
      supabaseDbPassword: getOptional('SUPABASE_DB_PASSWORD'),
    );
  }

  /// Create test configuration for CI/CD environments
  ///
  /// Uses environment variables directly without .env.test file
  factory TestConfig.fromEnvironment() {
    String getRequired(String key) {
      final value = Platform.environment[key];
      if (value == null || value.isEmpty) {
        throw ArgumentError(
          'Required environment variable $key is missing or empty',
        );
      }
      return value;
    }

    String? getOptional(String key) => Platform.environment[key];

    int getInt(String key, int defaultValue) {
      final value = Platform.environment[key];
      if (value == null || value.isEmpty) return defaultValue;
      return int.tryParse(value) ?? defaultValue;
    }

    bool getBool(String key, bool defaultValue) {
      final value = Platform.environment[key];
      if (value == null || value.isEmpty) return defaultValue;
      return value.toLowerCase() == 'true';
    }

    return TestConfig(
      baseUrl: getRequired('N8N_BASE_URL'),
      apiKey: getOptional('N8N_API_KEY'),
      simpleWebhookId: getRequired('N8N_SIMPLE_WEBHOOK_ID'),
      waitNodeWebhookId: getRequired('N8N_WAIT_NODE_WEBHOOK_ID'),
      slowWebhookId: getRequired('N8N_SLOW_WEBHOOK_ID'),
      errorWebhookId: getRequired('N8N_ERROR_WEBHOOK_ID'),
      timeoutSeconds: getInt('TEST_TIMEOUT_SECONDS', 300),
      maxRetries: getInt('TEST_MAX_RETRIES', 3),
      pollingIntervalMs: getInt('TEST_POLLING_INTERVAL_MS', 2000),
      runIntegrationTests: getBool('CI_RUN_INTEGRATION_TESTS', true),
      skipSlowTests: getBool('CI_SKIP_SLOW_TESTS', false),
      supabaseUrl: getOptional('SUPABASE_URL'),
      supabaseKey: getOptional('SUPABASE_KEY'),
      supabaseDbHost: getOptional('SUPABASE_DB_HOST'),
      supabaseDbPassword: getOptional('SUPABASE_DB_PASSWORD'),
    );
  }

  /// Validate configuration (checks for common issues)
  List<String> validate() {
    final errors = <String>[];

    // Validate base URL format
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      errors.add('baseUrl must start with http:// or https://');
    }

    // Validate timeout
    if (timeoutSeconds <= 0) {
      errors.add('timeoutSeconds must be positive');
    }

    // Validate retries
    if (maxRetries < 0) {
      errors.add('maxRetries cannot be negative');
    }

    // Validate polling interval
    if (pollingIntervalMs <= 0) {
      errors.add('pollingIntervalMs must be positive');
    }

    return errors;
  }

  /// Get timeout as Duration
  Duration get timeout => Duration(seconds: timeoutSeconds);

  /// Get polling interval as Duration
  Duration get pollingInterval => Duration(milliseconds: pollingIntervalMs);

  /// Check if Supabase credentials are configured
  bool get hasSupabaseCredentials =>
      supabaseUrl != null &&
      supabaseKey != null &&
      supabaseDbHost != null &&
      supabaseDbPassword != null;

  @override
  String toString() => 'TestConfig('
      'baseUrl: $baseUrl, '
      'simpleWebhookId: $simpleWebhookId, '
      'waitNodeWebhookId: $waitNodeWebhookId, '
      'timeout: ${timeout.inSeconds}s, '
      'pollingInterval: ${pollingInterval.inMilliseconds}ms'
      ')';
}
