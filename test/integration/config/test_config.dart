import 'dart:io';

import 'package:dotenv/dotenv.dart';
import 'package:n8n_dart/n8n_dart.dart';

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

  // Test Workflow Configuration
  // Workflow IDs (used for listing executions via API)
  final String simpleWorkflowId;
  final String waitNodeWorkflowId;
  final String slowWorkflowId;
  final String errorWorkflowId;

  // Webhook paths (used for triggering workflows)
  final String simpleWebhookPath;
  final String waitNodeWebhookPath;
  final String slowWebhookPath;
  final String errorWebhookPath;

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
    required this.simpleWorkflowId,
    required this.waitNodeWorkflowId,
    required this.slowWorkflowId,
    required this.errorWorkflowId,
    required this.simpleWebhookPath,
    required this.waitNodeWebhookPath,
    required this.slowWebhookPath,
    required this.errorWebhookPath,
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

  /// Check if integration tests can run (config file exists)
  static bool canRun() {
    return File('.env.test').existsSync();
  }

  /// Load test configuration from .env.test file with auto-discovery
  ///
  /// This method loads the configuration and automatically fetches workflow IDs
  /// from the n8n API if they're set to 'auto' in the .env.test file.
  ///
  /// Throws [FileSystemException] if .env.test file doesn't exist
  /// Throws [ArgumentError] if required environment variables are missing
  static Future<TestConfig> loadWithAutoDiscovery() async {
    final config = TestConfig.load();

    // Auto-discover workflow IDs if needed
    final idsToFetch = <String, String>{};

    if (config.simpleWorkflowId == 'auto') {
      idsToFetch['simple'] = config.simpleWebhookPath;
    }
    if (config.waitNodeWorkflowId == 'auto') {
      idsToFetch['waitNode'] = config.waitNodeWebhookPath;
    }
    if (config.slowWorkflowId == 'auto') {
      idsToFetch['slow'] = config.slowWebhookPath;
    }
    if (config.errorWorkflowId == 'auto') {
      idsToFetch['error'] = config.errorWebhookPath;
    }

    if (idsToFetch.isEmpty) {
      return config; // No auto-discovery needed
    }

    // Fetch workflow IDs from API
    final discoveredIds = <String, String>{};
    for (final entry in idsToFetch.entries) {
      final id = await config.fetchWorkflowIdByWebhookPath(entry.value);
      if (id != null) {
        discoveredIds[entry.key] = id;
      } else {
        throw StateError(
          'Failed to auto-discover workflow ID for ${entry.value}. '
          'Make sure the workflow is active in n8n.',
        );
      }
    }

    // Return new config with discovered IDs
    return TestConfig(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
      simpleWorkflowId: discoveredIds['simple'] ?? config.simpleWorkflowId,
      waitNodeWorkflowId: discoveredIds['waitNode'] ?? config.waitNodeWorkflowId,
      slowWorkflowId: discoveredIds['slow'] ?? config.slowWorkflowId,
      errorWorkflowId: discoveredIds['error'] ?? config.errorWorkflowId,
      simpleWebhookPath: config.simpleWebhookPath,
      waitNodeWebhookPath: config.waitNodeWebhookPath,
      slowWebhookPath: config.slowWebhookPath,
      errorWebhookPath: config.errorWebhookPath,
      timeoutSeconds: config.timeoutSeconds,
      maxRetries: config.maxRetries,
      pollingIntervalMs: config.pollingIntervalMs,
      runIntegrationTests: config.runIntegrationTests,
      skipSlowTests: config.skipSlowTests,
      supabaseUrl: config.supabaseUrl,
      supabaseKey: config.supabaseKey,
      supabaseDbHost: config.supabaseDbHost,
      supabaseDbPassword: config.supabaseDbPassword,
    );
  }

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

    // Helper to get string with default
    String getString(String key, String defaultValue) {
      final value = env[key];
      return (value == null || value.isEmpty) ? defaultValue : value;
    }

    return TestConfig(
      // n8n Cloud Configuration
      baseUrl: getRequired('N8N_BASE_URL'),
      apiKey: getOptional('N8N_API_KEY'),

      // Test Workflow IDs (default to 'auto' for auto-discovery)
      simpleWorkflowId: getString('N8N_SIMPLE_WORKFLOW_ID', 'auto'),
      waitNodeWorkflowId: getString('N8N_WAIT_NODE_WORKFLOW_ID', 'auto'),
      slowWorkflowId: getString('N8N_SLOW_WORKFLOW_ID', 'auto'),
      errorWorkflowId: getString('N8N_ERROR_WORKFLOW_ID', 'auto'),

      // Test Webhook Paths (default paths for auto-discovery)
      simpleWebhookPath: getString('N8N_SIMPLE_WEBHOOK_PATH', 'test/simple'),
      waitNodeWebhookPath: getString('N8N_WAIT_NODE_WEBHOOK_PATH', 'test/wait-node'),
      slowWebhookPath: getString('N8N_SLOW_WEBHOOK_PATH', 'test/slow'),
      errorWebhookPath: getString('N8N_ERROR_WEBHOOK_PATH', 'test/error'),

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
      simpleWorkflowId: getRequired('N8N_SIMPLE_WORKFLOW_ID'),
      waitNodeWorkflowId: getRequired('N8N_WAIT_NODE_WORKFLOW_ID'),
      slowWorkflowId: getRequired('N8N_SLOW_WORKFLOW_ID'),
      errorWorkflowId: getRequired('N8N_ERROR_WORKFLOW_ID'),
      simpleWebhookPath: getRequired('N8N_SIMPLE_WEBHOOK_PATH'),
      waitNodeWebhookPath: getRequired('N8N_WAIT_NODE_WEBHOOK_PATH'),
      slowWebhookPath: getRequired('N8N_SLOW_WEBHOOK_PATH'),
      errorWebhookPath: getRequired('N8N_ERROR_WEBHOOK_PATH'),
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

  /// Get discovery service instance
  N8nDiscoveryService _getDiscoveryService() {
    if (apiKey == null) {
      throw StateError('API key is required for workflow discovery');
    }
    return N8nDiscoveryService(
      baseUrl: baseUrl,
      apiKey: apiKey!,
    );
  }

  /// Fetch workflow ID from n8n API by webhook path
  ///
  /// This method queries the n8n API to find the active workflow that has a webhook
  /// matching the given path. This ensures we always use the correct workflow ID
  /// even if workflows are recreated or duplicated.
  ///
  /// Returns the workflow ID if found, null otherwise.
  Future<String?> fetchWorkflowIdByWebhookPath(String webhookPath) async {
    final service = _getDiscoveryService();
    try {
      return await service.findWorkflowByWebhookPath(webhookPath);
    } finally {
      service.dispose();
    }
  }

  /// Auto-discover all workflow IDs from n8n API
  ///
  /// This method fetches workflow IDs for all configured webhook paths.
  /// Returns a map of webhook path to workflow ID.
  Future<Map<String, String>> fetchAllWorkflowIds() async {
    final ids = <String, String>{};

    final paths = [
      simpleWebhookPath,
      waitNodeWebhookPath,
      slowWebhookPath,
      errorWebhookPath,
    ];

    for (final path in paths) {
      final id = await fetchWorkflowIdByWebhookPath(path);
      if (id != null) {
        ids[path] = id;
      }
    }

    return ids;
  }

  /// Fetch recent execution IDs for a workflow
  ///
  /// This method queries the n8n API to get recent executions for a specific workflow.
  /// Useful when you need to find existing executions without triggering new ones.
  ///
  /// Parameters:
  /// - [workflowId]: The workflow ID to fetch executions for
  /// - [limit]: Maximum number of executions to return (default: 10)
  /// - [status]: Filter by execution status (optional)
  ///
  /// Returns a list of execution IDs, ordered by most recent first.
  Future<List<String>> fetchExecutionIds({
    required String workflowId,
    int limit = 10,
    WorkflowStatus? status,
  }) async {
    final service = _getDiscoveryService();
    try {
      return await service.getRecentExecutions(
        workflowId,
        limit: limit,
        status: status,
      );
    } finally {
      service.dispose();
    }
  }

  /// Fetch the most recent execution ID for a workflow
  ///
  /// This is a convenience method that returns just the latest execution ID.
  ///
  /// Returns the execution ID if found, null otherwise.
  Future<String?> fetchLatestExecutionId({
    required String workflowId,
    WorkflowStatus? status,
  }) async {
    final service = _getDiscoveryService();
    try {
      return await service.getLatestExecution(
        workflowId,
        status: status,
      );
    } finally {
      service.dispose();
    }
  }

  /// Fetch execution IDs by webhook path
  ///
  /// This method first finds the workflow ID for the given webhook path,
  /// then fetches recent execution IDs for that workflow.
  ///
  /// This is useful when you know the webhook path but not the workflow ID.
  Future<List<String>> fetchExecutionIdsByWebhookPath({
    required String webhookPath,
    int limit = 10,
    WorkflowStatus? status,
  }) async {
    final service = _getDiscoveryService();
    try {
      return await service.getRecentExecutionsByWebhookPath(
        webhookPath,
        limit: limit,
        status: status,
      );
    } finally {
      service.dispose();
    }
  }

  @override
  String toString() => 'TestConfig('
      'baseUrl: $baseUrl, '
      'simpleWorkflowId: $simpleWorkflowId, '
      'simpleWebhookPath: $simpleWebhookPath, '
      'timeout: ${timeout.inSeconds}s, '
      'pollingInterval: ${pollingInterval.inMilliseconds}ms'
      ')';
}
