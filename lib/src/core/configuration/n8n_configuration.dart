/// n8n service configuration with comprehensive settings
///
/// Provides flexible configuration for different environments and use cases
/// with builder pattern and preset profiles for easy setup.
library;

import '../exceptions/error_handling.dart';
import '../services/polling_manager.dart';
import '../services/stream_recovery.dart';

/// Environment enumeration
enum N8nEnvironment {
  development,
  staging,
  production;

  /// Get default base URL for environment
  String get defaultBaseUrl {
    switch (this) {
      case N8nEnvironment.development:
        return 'http://localhost:5678';
      case N8nEnvironment.staging:
        return 'https://staging-n8n.example.com';
      case N8nEnvironment.production:
        return 'https://n8n.example.com';
    }
  }

  /// Check if environment is production
  bool get isProduction => this == N8nEnvironment.production;

  /// Check if environment is development
  bool get isDevelopment => this == N8nEnvironment.development;
}

/// Logging level enumeration
enum LogLevel {
  none,
  error,
  warning,
  info,
  debug,
  verbose;

  /// Check if level should log errors
  bool get shouldLogErrors => index >= LogLevel.error.index;

  /// Check if level should log warnings
  bool get shouldLogWarnings => index >= LogLevel.warning.index;

  /// Check if level should log info
  bool get shouldLogInfo => index >= LogLevel.info.index;

  /// Check if level should log debug
  bool get shouldLogDebug => index >= LogLevel.debug.index;

  /// Check if level should log verbose
  bool get shouldLogVerbose => index >= LogLevel.verbose.index;
}

/// Performance monitoring configuration
class PerformanceConfig {
  final Duration metricsInterval;
  final bool enableResponseTimeTracking;
  final bool enableMemoryMonitoring;
  final int maxMetricsHistory;
  final bool enablePerformanceAlerts;
  final Duration performanceAlertThreshold;

  const PerformanceConfig({
    this.metricsInterval = const Duration(minutes: 1),
    this.enableResponseTimeTracking = true,
    this.enableMemoryMonitoring = true,
    this.maxMetricsHistory = 100,
    this.enablePerformanceAlerts = false,
    this.performanceAlertThreshold = const Duration(seconds: 5),
  });

  /// Create minimal performance configuration
  factory PerformanceConfig.minimal() {
    return const PerformanceConfig(
      enableResponseTimeTracking: false,
      enableMemoryMonitoring: false,
    );
  }

  /// Create high-performance monitoring configuration
  factory PerformanceConfig.highPerformance() {
    return const PerformanceConfig(
      metricsInterval: Duration(seconds: 30),
      maxMetricsHistory: 200,
      enablePerformanceAlerts: true,
      performanceAlertThreshold: Duration(seconds: 2),
    );
  }

  @override
  String toString() {
    return 'PerformanceConfig(metricsInterval: $metricsInterval, '
        'responseTracking: $enableResponseTimeTracking, '
        'memoryMonitoring: $enableMemoryMonitoring)';
  }
}

/// Security configuration
class SecurityConfig {
  final String? apiKey;
  final bool validateSsl;
  final Map<String, String> customHeaders;
  final Duration rateLimitWindow;
  final int rateLimitRequests;
  final bool enableRequestSigning;
  final String? requestSigningSecret;

  const SecurityConfig({
    this.apiKey,
    this.validateSsl = true,
    this.customHeaders = const {},
    this.rateLimitWindow = const Duration(minutes: 1),
    this.rateLimitRequests = 60,
    this.enableRequestSigning = false,
    this.requestSigningSecret,
  });

  /// Create development security configuration
  factory SecurityConfig.development() {
    return const SecurityConfig(
      validateSsl: false,
      rateLimitRequests: 1000,
    );
  }

  /// Create production security configuration
  factory SecurityConfig.production({
    required String apiKey,
    String? signingSecret,
  }) {
    return SecurityConfig(
      apiKey: apiKey,
      rateLimitRequests: 100,
      enableRequestSigning: signingSecret != null,
      requestSigningSecret: signingSecret,
    );
  }

  /// Create secure configuration with custom headers
  factory SecurityConfig.withHeaders(Map<String, String> headers) {
    return SecurityConfig(
      customHeaders: headers,
    );
  }

  @override
  String toString() {
    return 'SecurityConfig(hasApiKey: ${apiKey != null}, '
        'validateSsl: $validateSsl, '
        'customHeaders: ${customHeaders.length}, '
        'rateLimit: $rateLimitRequests/$rateLimitWindow)';
  }
}

/// Cache configuration
class CacheConfig {
  final Duration defaultTtl;
  final int maxCacheSize;
  final bool enableCacheMetrics;
  final Duration cacheCleanupInterval;
  final Map<String, Duration> specificTtls;
  final bool enablePersistentCache;
  final String? persistentCacheKey;

  const CacheConfig({
    this.defaultTtl = const Duration(minutes: 5),
    this.maxCacheSize = 100,
    this.enableCacheMetrics = true,
    this.cacheCleanupInterval = const Duration(minutes: 10),
    this.specificTtls = const {},
    this.enablePersistentCache = false,
    this.persistentCacheKey,
  });

  /// Create no-cache configuration
  factory CacheConfig.disabled() {
    return const CacheConfig(
      defaultTtl: Duration.zero,
      maxCacheSize: 0,
      enableCacheMetrics: false,
    );
  }

  /// Create aggressive caching configuration
  factory CacheConfig.aggressive() {
    return const CacheConfig(
      defaultTtl: Duration(minutes: 30),
      maxCacheSize: 500,
      cacheCleanupInterval: Duration(minutes: 5),
      enablePersistentCache: true,
    );
  }

  /// Create memory-efficient configuration
  factory CacheConfig.memoryEfficient() {
    return const CacheConfig(
      defaultTtl: Duration(minutes: 2),
      maxCacheSize: 50,
      cacheCleanupInterval: Duration(minutes: 1),
    );
  }

  /// Get TTL for specific cache key
  Duration getTtl(String key) {
    return specificTtls[key] ?? defaultTtl;
  }

  @override
  String toString() {
    return 'CacheConfig(defaultTtl: $defaultTtl, '
        'maxSize: $maxCacheSize, '
        'persistent: $enablePersistentCache)';
  }
}

/// Webhook configuration
class WebhookConfig {
  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final bool enablePayloadValidation;
  final bool enablePayloadTransformation;
  final Map<String, dynamic>? defaultPayload;
  final List<String> allowedContentTypes;

  const WebhookConfig({
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.enablePayloadValidation = true,
    this.enablePayloadTransformation = false,
    this.defaultPayload,
    this.allowedContentTypes = const ['application/json'],
  });

  /// Create fast webhook configuration
  factory WebhookConfig.fast() {
    return const WebhookConfig(
      timeout: Duration(seconds: 10),
      maxRetries: 1,
      retryDelay: Duration(milliseconds: 500),
    );
  }

  /// Create reliable webhook configuration
  factory WebhookConfig.reliable() {
    return const WebhookConfig(
      timeout: Duration(minutes: 2),
      maxRetries: 5,
      retryDelay: Duration(seconds: 2),
    );
  }

  /// Create flexible webhook configuration
  factory WebhookConfig.flexible() {
    return const WebhookConfig(
      timeout: Duration(seconds: 45),
      enablePayloadTransformation: true,
      allowedContentTypes: [
        'application/json',
        'application/x-www-form-urlencoded',
        'text/plain',
      ],
    );
  }

  @override
  String toString() {
    return 'WebhookConfig(timeout: $timeout, '
        'maxRetries: $maxRetries, '
        'validation: $enablePayloadValidation)';
  }
}

/// Main n8n service configuration
class N8nServiceConfig {
  final String baseUrl;
  final N8nEnvironment environment;
  final LogLevel logLevel;
  final bool testConnectionOnInit;
  final PerformanceConfig performance;
  final SecurityConfig security;
  final CacheConfig cache;
  final WebhookConfig webhook;
  final PollingConfig polling;
  final RetryConfig retry;
  final StreamErrorConfig streamError;
  final Map<String, dynamic> metadata;

  N8nServiceConfig({
    required this.baseUrl,
    this.environment = N8nEnvironment.development,
    this.logLevel = LogLevel.info,
    this.testConnectionOnInit = true,
    this.performance = const PerformanceConfig(),
    this.security = const SecurityConfig(),
    this.cache = const CacheConfig(),
    this.webhook = const WebhookConfig(),
    this.polling = const PollingConfig(),
    this.retry = const RetryConfig(),
    this.streamError = const StreamErrorConfig(),
    this.metadata = const {},
  });

  /// Validate configuration
  List<String> validate() {
    final errors = <String>[];

    // Validate base URL
    if (baseUrl.isEmpty) {
      errors.add('Base URL cannot be empty');
    } else {
      try {
        final uri = Uri.parse(baseUrl);
        if (!uri.hasScheme || !uri.hasAuthority) {
          errors.add('Invalid base URL format');
        }
      } catch (e) {
        errors.add('Invalid base URL: $e');
      }
    }

    // Validate security configuration
    if (environment.isProduction && security.apiKey == null) {
      errors.add('API key is required for production environment');
    }

    // Validate performance configuration
    if (performance.metricsInterval.inSeconds < 10) {
      errors.add('Metrics interval should be at least 10 seconds');
    }

    // Validate cache configuration
    if (cache.maxCacheSize < 0) {
      errors.add('Cache size cannot be negative');
    }

    // Validate webhook configuration
    if (webhook.timeout.inSeconds < 1) {
      errors.add('Webhook timeout should be at least 1 second');
    }

    // Validate polling configuration
    if (polling.minInterval >= polling.maxInterval) {
      errors.add('Polling min interval must be less than max interval');
    }

    // Validate retry configuration
    if (retry.maxRetries < 0) {
      errors.add('Max retries cannot be negative');
    }

    return errors;
  }

  /// Check if configuration is valid
  bool get isValid => validate().isEmpty;

  /// Create copy with updated fields
  N8nServiceConfig copyWith({
    String? baseUrl,
    N8nEnvironment? environment,
    LogLevel? logLevel,
    bool? testConnectionOnInit,
    PerformanceConfig? performance,
    SecurityConfig? security,
    CacheConfig? cache,
    WebhookConfig? webhook,
    PollingConfig? polling,
    RetryConfig? retry,
    StreamErrorConfig? streamError,
    Map<String, dynamic>? metadata,
  }) {
    return N8nServiceConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      environment: environment ?? this.environment,
      logLevel: logLevel ?? this.logLevel,
      testConnectionOnInit: testConnectionOnInit ?? this.testConnectionOnInit,
      performance: performance ?? this.performance,
      security: security ?? this.security,
      cache: cache ?? this.cache,
      webhook: webhook ?? this.webhook,
      polling: polling ?? this.polling,
      retry: retry ?? this.retry,
      streamError: streamError ?? this.streamError,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'baseUrl': baseUrl,
      'environment': environment.name,
      'logLevel': logLevel.name,
      'testConnectionOnInit': testConnectionOnInit,
      'performance': performance.toString(),
      'security': security.toString(),
      'cache': cache.toString(),
      'webhook': webhook.toString(),
      'polling': polling.toString(),
      'retry': retry.toString(),
      'streamError': streamError.toString(),
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'N8nServiceConfig(baseUrl: $baseUrl, '
        'environment: $environment, '
        'logLevel: $logLevel)';
  }
}

/// Fluent configuration builder
class N8nConfigBuilder {
  String? _baseUrl;
  N8nEnvironment _environment = N8nEnvironment.development;
  LogLevel _logLevel = LogLevel.info;
  bool _testConnectionOnInit = true;
  PerformanceConfig _performance = const PerformanceConfig();
  SecurityConfig _security = const SecurityConfig();
  CacheConfig _cache = const CacheConfig();
  WebhookConfig _webhook = const WebhookConfig();
  PollingConfig _polling = const PollingConfig();
  RetryConfig _retry = const RetryConfig();
  StreamErrorConfig _streamError = const StreamErrorConfig();
  Map<String, dynamic> _metadata = {};

  /// Set base URL
  N8nConfigBuilder baseUrl(String url) {
    _baseUrl = url;
    return this;
  }

  /// Set environment
  N8nConfigBuilder environment(N8nEnvironment env) {
    _environment = env;
    return this;
  }

  /// Set log level
  N8nConfigBuilder logLevel(LogLevel level) {
    _logLevel = level;
    return this;
  }

  /// Set test connection on init
  N8nConfigBuilder testConnectionOnInit(bool test) {
    _testConnectionOnInit = test;
    return this;
  }

  /// Set performance configuration
  N8nConfigBuilder performance(PerformanceConfig config) {
    _performance = config;
    return this;
  }

  /// Set security configuration
  N8nConfigBuilder security(SecurityConfig config) {
    _security = config;
    return this;
  }

  /// Set cache configuration
  N8nConfigBuilder cache(CacheConfig config) {
    _cache = config;
    return this;
  }

  /// Set webhook configuration
  N8nConfigBuilder webhook(WebhookConfig config) {
    _webhook = config;
    return this;
  }

  /// Set polling configuration
  N8nConfigBuilder polling(PollingConfig config) {
    _polling = config;
    return this;
  }

  /// Set retry configuration
  N8nConfigBuilder retry(RetryConfig config) {
    _retry = config;
    return this;
  }

  /// Set stream error configuration
  N8nConfigBuilder streamError(StreamErrorConfig config) {
    _streamError = config;
    return this;
  }

  /// Add metadata
  N8nConfigBuilder addMetadata(String key, dynamic value) {
    _metadata[key] = value;
    return this;
  }

  /// Set all metadata
  N8nConfigBuilder metadata(Map<String, dynamic> data) {
    _metadata = Map.from(data);
    return this;
  }

  /// Build configuration
  N8nServiceConfig build() {
    _baseUrl ??= _environment.defaultBaseUrl;

    return N8nServiceConfig(
      baseUrl: _baseUrl!,
      environment: _environment,
      logLevel: _logLevel,
      testConnectionOnInit: _testConnectionOnInit,
      performance: _performance,
      security: _security,
      cache: _cache,
      webhook: _webhook,
      polling: _polling,
      retry: _retry,
      streamError: _streamError,
      metadata: _metadata,
    );
  }
}

/// Preset configuration profiles
class N8nConfigProfiles {
  /// Minimal configuration for basic usage
  static N8nServiceConfig minimal({String? baseUrl}) {
    return N8nConfigBuilder()
        .baseUrl(baseUrl ?? N8nEnvironment.development.defaultBaseUrl)
        .environment(N8nEnvironment.development)
        .logLevel(LogLevel.error)
        .testConnectionOnInit(false)
        .performance(PerformanceConfig.minimal())
        .security(SecurityConfig.development())
        .cache(CacheConfig.disabled())
        .webhook(WebhookConfig.fast())
        .polling(PollingConfig.minimal())
        .retry(RetryConfig.minimal())
        .streamError(StreamErrorConfig.minimal())
        .build();
  }

  /// High-performance configuration for demanding applications
  static N8nServiceConfig highPerformance({
    String? baseUrl,
    String? apiKey,
  }) {
    return N8nConfigBuilder()
        .baseUrl(baseUrl ?? N8nEnvironment.production.defaultBaseUrl)
        .environment(N8nEnvironment.production)
        .logLevel(LogLevel.warning)
        .testConnectionOnInit(true)
        .performance(PerformanceConfig.highPerformance())
        .security(SecurityConfig.production(apiKey: apiKey ?? ''))
        .cache(CacheConfig.memoryEfficient())
        .webhook(WebhookConfig.fast())
        .polling(PollingConfig.highFrequency())
        .retry(RetryConfig.conservative())
        .streamError(StreamErrorConfig.highPerformance())
        .build();
  }

  /// Resilient configuration for unreliable networks
  static N8nServiceConfig resilient({
    String? baseUrl,
    String? apiKey,
  }) {
    return N8nConfigBuilder()
        .baseUrl(baseUrl ?? N8nEnvironment.production.defaultBaseUrl)
        .environment(N8nEnvironment.production)
        .logLevel(LogLevel.info)
        .testConnectionOnInit(true)
        .performance(const PerformanceConfig())
        .security(SecurityConfig.production(apiKey: apiKey ?? ''))
        .cache(CacheConfig.aggressive())
        .webhook(WebhookConfig.reliable())
        .polling(PollingConfig.batteryOptimized())
        .retry(RetryConfig.aggressive())
        .streamError(StreamErrorConfig.resilient())
        .build();
  }

  /// Development configuration with extensive logging
  static N8nServiceConfig development({String? baseUrl}) {
    return N8nConfigBuilder()
        .baseUrl(baseUrl ?? N8nEnvironment.development.defaultBaseUrl)
        .environment(N8nEnvironment.development)
        .logLevel(LogLevel.verbose)
        .testConnectionOnInit(true)
        .performance(const PerformanceConfig())
        .security(SecurityConfig.development())
        .cache(const CacheConfig())
        .webhook(WebhookConfig.flexible())
        .polling(PollingConfig.balanced())
        .retry(const RetryConfig())
        .streamError(const StreamErrorConfig())
        .addMetadata('profile', 'development')
        .build();
  }

  /// Production configuration with security and monitoring
  static N8nServiceConfig production({
    required String baseUrl,
    required String apiKey,
    String? signingSecret,
  }) {
    return N8nConfigBuilder()
        .baseUrl(baseUrl)
        .environment(N8nEnvironment.production)
        .logLevel(LogLevel.warning)
        .testConnectionOnInit(true)
        .performance(PerformanceConfig.highPerformance())
        .security(SecurityConfig.production(
          apiKey: apiKey,
          signingSecret: signingSecret,
        ))
        .cache(const CacheConfig())
        .webhook(WebhookConfig.reliable())
        .polling(PollingConfig.balanced())
        .retry(const RetryConfig())
        .streamError(const StreamErrorConfig())
        .addMetadata('profile', 'production')
        .build();
  }

  /// Battery-optimized configuration for mobile devices
  static N8nServiceConfig batteryOptimized({
    String? baseUrl,
    String? apiKey,
  }) {
    return N8nConfigBuilder()
        .baseUrl(baseUrl ?? N8nEnvironment.production.defaultBaseUrl)
        .environment(N8nEnvironment.production)
        .logLevel(LogLevel.error)
        .testConnectionOnInit(false)
        .performance(PerformanceConfig.minimal())
        .security(apiKey != null
            ? SecurityConfig.production(apiKey: apiKey)
            : SecurityConfig.development())
        .cache(CacheConfig.aggressive())
        .webhook(WebhookConfig.fast())
        .polling(PollingConfig.batteryOptimized())
        .retry(RetryConfig.conservative())
        .streamError(StreamErrorConfig.minimal())
        .addMetadata('profile', 'battery_optimized')
        .build();
  }
}
