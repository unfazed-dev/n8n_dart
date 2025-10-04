import 'dart:async';
import 'dart:math';
import 'package:rxdart/rxdart.dart';

/// Stream error recovery strategies
enum StreamRecoveryStrategy {
  restart, // Restart stream from scratch
  retry, // Retry last operation with backoff
  fallback, // Use default/cached values
  skip, // Continue despite error
  escalate, // Bubble error to caller
}

/// Stream error configuration
class StreamErrorConfig {
  final StreamRecoveryStrategy defaultStrategy;
  final Map<Type, StreamRecoveryStrategy> errorStrategies;
  final int maxRetries;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;
  final double retryBackoffMultiplier;
  final Duration healthCheckInterval;
  final int errorThreshold;
  final Duration errorWindow;
  final bool enableHealthMonitoring;

  const StreamErrorConfig({
    this.defaultStrategy = StreamRecoveryStrategy.retry,
    this.errorStrategies = const {},
    this.maxRetries = 3,
    this.initialRetryDelay = const Duration(milliseconds: 500),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.retryBackoffMultiplier = 2.0,
    this.healthCheckInterval = const Duration(seconds: 30),
    this.errorThreshold = 5,
    this.errorWindow = const Duration(minutes: 5),
    this.enableHealthMonitoring = true,
  });

  /// Create minimal configuration
  factory StreamErrorConfig.minimal() {
    return const StreamErrorConfig(
      defaultStrategy: StreamRecoveryStrategy.fallback,
      maxRetries: 1,
      enableHealthMonitoring: false,
    );
  }

  /// Create resilient configuration
  factory StreamErrorConfig.resilient() {
    return const StreamErrorConfig(
      maxRetries: 5,
      initialRetryDelay: Duration(milliseconds: 200),
      maxRetryDelay: Duration(minutes: 2),
      retryBackoffMultiplier: 1.5,
      errorThreshold: 10,
      errorWindow: Duration(minutes: 10),
    );
  }

  /// Create high-performance configuration
  factory StreamErrorConfig.highPerformance() {
    return const StreamErrorConfig(
      defaultStrategy: StreamRecoveryStrategy.skip,
      maxRetries: 2,
      initialRetryDelay: Duration(milliseconds: 100),
      maxRetryDelay: Duration(seconds: 5),
      healthCheckInterval: Duration(seconds: 10),
      errorThreshold: 3,
    );
  }

  /// Get recovery strategy for error type
  StreamRecoveryStrategy getStrategyForError(Type errorType) {
    return errorStrategies[errorType] ?? defaultStrategy;
  }

  /// Calculate retry delay for attempt
  Duration calculateRetryDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    final baseDelay = initialRetryDelay.inMilliseconds *
        pow(retryBackoffMultiplier, attempt - 1);

    final delayMs = baseDelay.clamp(
      initialRetryDelay.inMilliseconds.toDouble(),
      maxRetryDelay.inMilliseconds.toDouble(),
    );

    return Duration(milliseconds: delayMs.round());
  }

  @override
  String toString() {
    return 'StreamErrorConfig(strategy: $defaultStrategy, maxRetries: $maxRetries, '
        'healthMonitoring: $enableHealthMonitoring)';
  }
}

/// Stream health metrics
class StreamHealth {
  final String streamId;
  final bool isHealthy;
  final double successRate;
  final Duration averageResponseTime;
  final int totalRequests;
  final int successfulRequests;
  final int errorCount;
  final DateTime lastSuccessTime;
  final DateTime lastErrorTime;
  final List<String> recentErrors;
  final Map<String, dynamic> metadata;

  const StreamHealth({
    required this.streamId,
    required this.isHealthy,
    required this.successRate,
    required this.averageResponseTime,
    required this.totalRequests,
    required this.successfulRequests,
    required this.errorCount,
    required this.lastSuccessTime,
    required this.lastErrorTime,
    required this.recentErrors,
    required this.metadata,
  });

  /// Create initial healthy state
  factory StreamHealth.initial(String streamId) {
    final now = DateTime.now();
    return StreamHealth(
      streamId: streamId,
      isHealthy: true,
      successRate: 1,
      averageResponseTime: Duration.zero,
      totalRequests: 0,
      successfulRequests: 0,
      errorCount: 0,
      lastSuccessTime: now,
      lastErrorTime: now,
      recentErrors: [],
      metadata: {},
    );
  }

  /// Create unhealthy state
  StreamHealth copyWithError(String error) {
    final now = DateTime.now();
    final newRecentErrors = List<String>.from(recentErrors);
    newRecentErrors.add(error);

    // Keep only recent errors (last 10)
    if (newRecentErrors.length > 10) {
      newRecentErrors.removeAt(0);
    }

    final newErrorCount = errorCount + 1;
    final newTotalRequests = totalRequests + 1;
    final newSuccessRate = successfulRequests / newTotalRequests;

    return StreamHealth(
      streamId: streamId,
      isHealthy: newSuccessRate > 0.5, // Healthy if success rate > 50%
      successRate: newSuccessRate,
      averageResponseTime: averageResponseTime,
      totalRequests: newTotalRequests,
      successfulRequests: successfulRequests,
      errorCount: newErrorCount,
      lastSuccessTime: lastSuccessTime,
      lastErrorTime: now,
      recentErrors: newRecentErrors,
      metadata: metadata,
    );
  }

  /// Create success state
  StreamHealth copyWithSuccess(Duration responseTime) {
    final now = DateTime.now();
    final newSuccessfulRequests = successfulRequests + 1;
    final newTotalRequests = totalRequests + 1;
    final newSuccessRate = newSuccessfulRequests / newTotalRequests;

    // Calculate new average response time
    final totalResponseTime =
        averageResponseTime.inMilliseconds * successfulRequests;
    final newAverageResponseTime = Duration(
      milliseconds: ((totalResponseTime + responseTime.inMilliseconds) /
              newSuccessfulRequests)
          .round(),
    );

    return StreamHealth(
      streamId: streamId,
      isHealthy: newSuccessRate > 0.5,
      successRate: newSuccessRate,
      averageResponseTime: newAverageResponseTime,
      totalRequests: newTotalRequests,
      successfulRequests: newSuccessfulRequests,
      errorCount: errorCount,
      lastSuccessTime: now,
      lastErrorTime: lastErrorTime,
      recentErrors: recentErrors,
      metadata: metadata,
    );
  }

  /// Get health summary
  Map<String, dynamic> toJson() {
    return {
      'streamId': streamId,
      'isHealthy': isHealthy,
      'successRate': successRate,
      'averageResponseTime': averageResponseTime.inMilliseconds,
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'errorCount': errorCount,
      'lastSuccessTime': lastSuccessTime.toIso8601String(),
      'lastErrorTime': lastErrorTime.toIso8601String(),
      'recentErrors': recentErrors,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'StreamHealth(id: $streamId, healthy: $isHealthy, '
        'successRate: ${(successRate * 100).toStringAsFixed(1)}%, '
        'errors: $errorCount)';
  }
}

/// Resilient stream manager with error recovery
class ResilientStreamManager<T> {
  final StreamErrorConfig config;
  final T? fallbackValue;
  final String streamId;

  // Stream management
  StreamController<T>? _controller;
  StreamSubscription? _sourceSubscription;
  Stream<T>? _sourceStream;

  // Health monitoring
  late final BehaviorSubject<StreamHealth> _health$;
  Timer? _healthCheckTimer;

  // Recovery state
  int _retryCount = 0;
  DateTime? _lastRetryTime;
  bool _isRecovering = false;

  ResilientStreamManager(
    this.config, {
    this.fallbackValue,
    String? streamId,
  }) : streamId =
            streamId ?? 'stream_${DateTime.now().millisecondsSinceEpoch}' {
    _health$ = BehaviorSubject<StreamHealth>.seeded(
        StreamHealth.initial(this.streamId));

    if (config.enableHealthMonitoring) {
      _startHealthMonitoring();
    }
  }

  /// Get health stream
  Stream<StreamHealth> get health$ => _health$.stream;

  /// Get current health
  StreamHealth get currentHealth => _health$.value;

  /// Create resilient stream from source
  Stream<T> createResilientStream(Stream<T> sourceStream) {
    _sourceStream = sourceStream;
    _controller = StreamController<T>.broadcast();

    _subscribeToSource();

    return _controller!.stream;
  }

  /// Subscribe to source stream with error handling
  void _subscribeToSource() {
    if (_sourceStream == null || _controller == null) return;

    final startTime = DateTime.now();

    _sourceSubscription = _sourceStream!.listen(
      (data) {
        // Record success
        final responseTime = DateTime.now().difference(startTime);
        _recordSuccess(responseTime);

        // Forward data
        if (!_controller!.isClosed) {
          _controller!.add(data);
        }

        // Reset retry state on success
        _retryCount = 0;
        _isRecovering = false;
      },
      onError: (error, stackTrace) {
        _handleStreamError(error, stackTrace);
      },
      onDone: () {
        if (!_controller!.isClosed) {
          _controller!.close();
        }
      },
    );
  }

  /// Handle stream errors with recovery strategies
  void _handleStreamError(dynamic error, StackTrace stackTrace) {
    _recordError(error.toString());

    final strategy = config.getStrategyForError(error.runtimeType);

    switch (strategy) {
      case StreamRecoveryStrategy.restart:
        _restartStream();
        break;

      case StreamRecoveryStrategy.retry:
        _retryWithBackoff();
        break;

      case StreamRecoveryStrategy.fallback:
        _useFallback();
        break;

      case StreamRecoveryStrategy.skip:
        // Continue without action
        break;

      case StreamRecoveryStrategy.escalate:
        _escalateError(error, stackTrace);
        break;
    }
  }

  /// Restart stream from scratch
  void _restartStream() {
    if (_isRecovering) return;
    _isRecovering = true;

    // Cancel current subscription
    _sourceSubscription?.cancel();

    // Wait a bit before restarting
    Timer(config.initialRetryDelay, () {
      if (_sourceStream != null &&
          _controller != null &&
          !_controller!.isClosed) {
        _subscribeToSource();
      }
      _isRecovering = false;
    });
  }

  /// Retry with exponential backoff
  void _retryWithBackoff() {
    if (_isRecovering || _retryCount >= config.maxRetries) {
      _escalateError('Max retries exceeded', StackTrace.current);
      return;
    }

    _isRecovering = true;
    _retryCount++;
    _lastRetryTime = DateTime.now();

    final delay = config.calculateRetryDelay(_retryCount);

    Timer(delay, () {
      if (_sourceStream != null &&
          _controller != null &&
          !_controller!.isClosed) {
        _subscribeToSource();
      }
      _isRecovering = false;
    });
  }

  /// Use fallback value
  void _useFallback() {
    if (fallbackValue != null &&
        _controller != null &&
        !_controller!.isClosed) {
      _controller!.add(fallbackValue as T);
    }
  }

  /// Escalate error to controller
  void _escalateError(dynamic error, StackTrace stackTrace) {
    if (_controller != null && !_controller!.isClosed) {
      _controller!.addError(error, stackTrace);
    }
  }

  /// Record successful operation
  void _recordSuccess(Duration responseTime) {
    final currentHealth = _health$.value;
    final newHealth = currentHealth.copyWithSuccess(responseTime);
    _health$.add(newHealth);
  }

  /// Record error
  void _recordError(String error) {
    final currentHealth = _health$.value;
    final newHealth = currentHealth.copyWithError(error);
    _health$.add(newHealth);
  }

  /// Start health monitoring
  void _startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(config.healthCheckInterval, (timer) {
      _performHealthCheck();
    });
  }

  /// Perform health check
  void _performHealthCheck() {
    final health = _health$.value;

    // Check if stream needs recovery based on health metrics
    if (!health.isHealthy && !_isRecovering) {
      final timeSinceLastError =
          DateTime.now().difference(health.lastErrorTime);

      // If errors are recent and above threshold, trigger recovery
      if (timeSinceLastError < config.errorWindow &&
          health.errorCount >= config.errorThreshold) {
        _restartStream();
      }
    }
  }

  /// Get recovery statistics
  Map<String, dynamic> getRecoveryStats() {
    return {
      'streamId': streamId,
      'retryCount': _retryCount,
      'lastRetryTime': _lastRetryTime?.toIso8601String(),
      'isRecovering': _isRecovering,
      'health': currentHealth.toJson(),
      'config': {
        'defaultStrategy': config.defaultStrategy.name,
        'maxRetries': config.maxRetries,
        'healthMonitoring': config.enableHealthMonitoring,
      },
    };
  }

  /// Reset recovery state
  void resetRecoveryState() {
    _retryCount = 0;
    _lastRetryTime = null;
    _isRecovering = false;

    // Reset health
    _health$.add(StreamHealth.initial(streamId));
  }

  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _sourceSubscription?.cancel();
    _controller?.close();
    _health$.close();
  }
}

/// Stream extension methods for resilience
extension StreamErrorRecovery<T> on Stream<T> {
  /// Add resilience to stream with default configuration
  Stream<T> withResilience({
    StreamErrorConfig? config,
    T? fallbackValue,
    String? streamId,
  }) {
    final manager = ResilientStreamManager<T>(
      config ?? const StreamErrorConfig(),
      fallbackValue: fallbackValue,
      streamId: streamId,
    );

    return manager.createResilientStream(this);
  }

  /// Add retry capability to stream
  Stream<T> withRetry({
    int maxRetries = 3,
    Duration delay = const Duration(milliseconds: 500),
    double backoffMultiplier = 2.0,
  }) {
    final config = StreamErrorConfig(
      maxRetries: maxRetries,
      initialRetryDelay: delay,
      retryBackoffMultiplier: backoffMultiplier,
      enableHealthMonitoring: false,
    );

    return withResilience(config: config);
  }

  /// Add fallback capability to stream
  Stream<T> withFallback(T fallbackValue) {
    const config = StreamErrorConfig(
      defaultStrategy: StreamRecoveryStrategy.fallback,
      enableHealthMonitoring: false,
    );

    return withResilience(
      config: config,
      fallbackValue: fallbackValue,
    );
  }

  /// Add health monitoring to stream
  Stream<T> withHealthMonitoring({
    Duration healthCheckInterval = const Duration(seconds: 30),
    int errorThreshold = 5,
    Duration errorWindow = const Duration(minutes: 5),
  }) {
    final config = StreamErrorConfig(
      healthCheckInterval: healthCheckInterval,
      errorThreshold: errorThreshold,
      errorWindow: errorWindow,
    );

    return withResilience(config: config);
  }

  /// Add circuit breaker pattern to stream
  Stream<T> withCircuitBreaker({
    int errorThreshold = 5,
    Duration timeout = const Duration(minutes: 1),
    T? fallbackValue,
  }) {
    final config = StreamErrorConfig(
      defaultStrategy: fallbackValue != null
          ? StreamRecoveryStrategy.fallback
          : StreamRecoveryStrategy.escalate,
      errorThreshold: errorThreshold,
      errorWindow: timeout,
    );

    return withResilience(
      config: config,
      fallbackValue: fallbackValue,
    );
  }
}
