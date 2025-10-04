import 'dart:async';
import 'dart:math';

/// n8n-specific error types for classification
enum N8nErrorType {
  network,
  authentication,
  workflow,
  timeout,
  serverError,
  rateLimit,
  unknown;

  /// Check if error type is typically retryable
  bool get isRetryable {
    switch (this) {
      case N8nErrorType.network:
      case N8nErrorType.timeout:
      case N8nErrorType.serverError:
      case N8nErrorType.rateLimit:
        return true;
      case N8nErrorType.authentication:
      case N8nErrorType.workflow:
      case N8nErrorType.unknown:
        return false;
    }
  }
}

/// Custom n8n exception with error classification
class N8nException implements Exception {
  final String message;
  final N8nErrorType type;
  final int? statusCode;
  final bool isRetryable;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;
  final Exception? originalException;
  final int? retryCount;

  N8nException(
    this.message,
    this.type, {
    this.statusCode,
    bool? isRetryable,
    this.metadata,
    this.originalException,
    this.retryCount,
  })  : isRetryable = isRetryable ?? false,
        timestamp = DateTime.now();

  /// Create network error
  factory N8nException.network(String message, {Exception? originalException}) {
    return N8nException(
      message,
      N8nErrorType.network,
      isRetryable: true,
      originalException: originalException,
    );
  }

  /// Create authentication error
  factory N8nException.authentication(String message, {int? statusCode}) {
    return N8nException(
      message,
      N8nErrorType.authentication,
      statusCode: statusCode,
      isRetryable: false,
    );
  }

  /// Create workflow error
  factory N8nException.workflow(String message,
      {Map<String, dynamic>? metadata}) {
    return N8nException(
      message,
      N8nErrorType.workflow,
      isRetryable: false,
      metadata: metadata,
    );
  }

  /// Create timeout error
  factory N8nException.timeout(String message, {Duration? timeout}) {
    return N8nException(
      message,
      N8nErrorType.timeout,
      isRetryable: true,
      metadata: timeout != null ? {'timeout': timeout.inMilliseconds} : null,
    );
  }

  /// Create server error
  factory N8nException.serverError(String message, {int? statusCode}) {
    return N8nException(
      message,
      N8nErrorType.serverError,
      statusCode: statusCode,
      isRetryable: statusCode == null || statusCode >= 500,
    );
  }

  /// Create rate limit error
  factory N8nException.rateLimit(String message, {Duration? retryAfter}) {
    return N8nException(
      message,
      N8nErrorType.rateLimit,
      isRetryable: true,
      metadata:
          retryAfter != null ? {'retryAfter': retryAfter.inSeconds} : null,
    );
  }

  /// Create unknown error
  factory N8nException.unknown(String message, {Exception? originalException}) {
    return N8nException(
      message,
      N8nErrorType.unknown,
      isRetryable: false,
      originalException: originalException,
    );
  }

  /// Check if this is a network error
  bool get isNetworkError => type == N8nErrorType.network;

  @override
  String toString() {
    final buffer = StringBuffer('N8nException: $message');
    buffer.write(' (type: $type');

    if (statusCode != null) {
      buffer.write(', statusCode: $statusCode');
    }

    buffer.write(', retryable: $isRetryable');

    if (metadata != null && metadata!.isNotEmpty) {
      buffer.write(', metadata: $metadata');
    }

    buffer.write(')');

    if (originalException != null) {
      buffer.write('\nCaused by: $originalException');
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is N8nException &&
        other.message == message &&
        other.type == type &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode {
    return Object.hash(message, type, statusCode);
  }
}

/// Retry configuration for error handling
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final double jitter;
  final Set<N8nErrorType> retryableErrorTypes;
  final Set<int> retryableStatusCodes;
  final bool enableCircuitBreaker;
  final int circuitBreakerThreshold;
  final Duration circuitBreakerTimeout;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.jitter = 0.1,
    this.retryableErrorTypes = const {
      N8nErrorType.network,
      N8nErrorType.timeout,
      N8nErrorType.serverError,
      N8nErrorType.rateLimit,
    },
    this.retryableStatusCodes = const {500, 502, 503, 504, 429},
    this.enableCircuitBreaker = true,
    this.circuitBreakerThreshold = 5,
    this.circuitBreakerTimeout = const Duration(minutes: 1),
  });

  /// Create minimal retry configuration
  factory RetryConfig.minimal() {
    return const RetryConfig(
      maxRetries: 1,
      initialDelay: Duration(milliseconds: 100),
      enableCircuitBreaker: false,
    );
  }

  /// Create aggressive retry configuration
  factory RetryConfig.aggressive() {
    return const RetryConfig(
      maxRetries: 5,
      initialDelay: Duration(milliseconds: 200),
      maxDelay: Duration(minutes: 2),
      backoffMultiplier: 1.5,
      circuitBreakerThreshold: 10,
      circuitBreakerTimeout: Duration(minutes: 5),
    );
  }

  /// Create conservative retry configuration
  factory RetryConfig.conservative() {
    return const RetryConfig(
      maxRetries: 2,
      initialDelay: Duration(seconds: 1),
      maxDelay: Duration(seconds: 10),
      backoffMultiplier: 1.2,
      jitter: 0.05,
      circuitBreakerThreshold: 3,
    );
  }

  /// Calculate delay for retry attempt
  Duration calculateDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    // Exponential backoff with jitter
    final baseDelay =
        initialDelay.inMilliseconds * pow(backoffMultiplier, attempt - 1);

    // Add jitter to prevent thundering herd
    final jitterAmount = baseDelay * jitter * (Random().nextDouble() - 0.5);
    final delayMs = (baseDelay + jitterAmount).clamp(
      initialDelay.inMilliseconds.toDouble(),
      maxDelay.inMilliseconds.toDouble(),
    );

    return Duration(milliseconds: delayMs.round());
  }

  /// Check if error type is retryable
  bool isErrorTypeRetryable(N8nErrorType errorType) {
    return retryableErrorTypes.contains(errorType);
  }

  /// Check if status code is retryable
  bool isStatusCodeRetryable(int? statusCode) {
    if (statusCode == null) return false;
    return retryableStatusCodes.contains(statusCode);
  }

  @override
  String toString() {
    return 'RetryConfig(maxRetries: $maxRetries, initialDelay: $initialDelay, '
        'backoffMultiplier: $backoffMultiplier, circuitBreaker: $enableCircuitBreaker)';
  }
}

/// Circuit breaker states
enum CircuitBreakerState {
  closed, // Normal operation
  open, // Failing fast
  halfOpen, // Testing if service recovered
}

/// Circuit breaker for preventing cascading failures
class CircuitBreaker {
  final RetryConfig config;

  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _nextAttemptTime;

  CircuitBreaker(this.config);

  /// Get current circuit breaker state
  CircuitBreakerState get state => _state;

  /// Get failure count
  int get failureCount => _failureCount;

  /// Check if operation should be allowed
  bool shouldAllowOperation() {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;

      case CircuitBreakerState.open:
        if (_nextAttemptTime != null &&
            DateTime.now().isAfter(_nextAttemptTime!)) {
          _state = CircuitBreakerState.halfOpen;
          return true;
        }
        return false;

      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  /// Record successful operation
  void recordSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
    _nextAttemptTime = null;
  }

  /// Record failed operation
  void recordFailure() {
    _failureCount++;

    if (_failureCount >= config.circuitBreakerThreshold) {
      _state = CircuitBreakerState.open;
      _nextAttemptTime = DateTime.now().add(config.circuitBreakerTimeout);
    }
  }

  /// Reset circuit breaker
  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _nextAttemptTime = null;
  }

  @override
  String toString() {
    return 'CircuitBreaker(state: $_state, failures: $_failureCount)';
  }
}

/// Error handler with intelligent retry logic and circuit breaker
class N8nErrorHandler {
  final RetryConfig config;
  final CircuitBreaker? _circuitBreaker;

  // Retry tracking
  final Map<String, int> _retryAttempts = {};
  final Map<String, DateTime> _lastRetryTime = {};

  N8nErrorHandler(this.config)
      : _circuitBreaker =
            config.enableCircuitBreaker ? CircuitBreaker(config) : null;

  /// Get circuit breaker state
  CircuitBreakerState? get circuitBreakerState => _circuitBreaker?.state;

  /// Execute operation with retry logic
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    String? operationId,
  }) async {
    final opId = operationId ?? 'default';

    // Check circuit breaker
    if (_circuitBreaker != null && !_circuitBreaker!.shouldAllowOperation()) {
      throw N8nException(
        'Circuit breaker is open - operation not allowed',
        N8nErrorType.serverError,
        isRetryable: false,
        metadata: {
          'circuitBreakerState': _circuitBreaker!.state.name,
          'failureCount': _circuitBreaker!.failureCount,
        },
      );
    }

    var attempt = 0;
    N8nException? lastException;

    while (attempt <= config.maxRetries) {
      attempt++;

      try {
        final result = await operation();

        // Record success
        _retryAttempts.remove(opId);
        _lastRetryTime.remove(opId);
        _circuitBreaker?.recordSuccess();

        return result;
      } catch (error) {
        final n8nError = _classifyError(error);
        lastException = n8nError;

        // Record failure
        _circuitBreaker?.recordFailure();

        // Check if we should retry
        if (attempt > config.maxRetries || !shouldRetry(n8nError, attempt)) {
          _retryAttempts.remove(opId);
          _lastRetryTime.remove(opId);
          rethrow;
        }

        // Calculate and apply delay
        final delay = config.calculateDelay(attempt);
        _retryAttempts[opId] = attempt;
        _lastRetryTime[opId] = DateTime.now();

        await Future.delayed(delay);
      }
    }

    // This should never be reached, but just in case
    throw lastException ?? N8nException.unknown('Max retries exceeded');
  }

  /// Check if error should be retried
  bool shouldRetry(N8nException error, [int? currentAttempt]) {
    // Check if error type is retryable
    if (!config.isErrorTypeRetryable(error.type)) {
      return false;
    }

    // Check if status code is retryable
    if (error.statusCode != null &&
        !config.isStatusCodeRetryable(error.statusCode)) {
      return false;
    }

    // Check explicit retryable flag
    if (!error.isRetryable) {
      return false;
    }

    // Check attempt count
    if (currentAttempt != null && currentAttempt > config.maxRetries) {
      return false;
    }

    // Special handling for rate limit errors
    if (error.type == N8nErrorType.rateLimit) {
      return _shouldRetryRateLimit(error);
    }

    return true;
  }

  /// Check if rate limit error should be retried
  bool _shouldRetryRateLimit(N8nException error) {
    // Check if we have retry-after information
    if (error.metadata != null && error.metadata!.containsKey('retryAfter')) {
      final retryAfterSeconds = error.metadata!['retryAfter'] as int?;
      if (retryAfterSeconds != null) {
        // Only retry if retry-after is reasonable
        return retryAfterSeconds <= config.maxDelay.inSeconds;
      }
    }

    return true;
  }

  /// Classify generic errors into N8nException
  N8nException _classifyError(dynamic error) {
    if (error is N8nException) {
      return error;
    }

    if (error is TimeoutException) {
      return N8nException.timeout(
        'Operation timed out: ${error.message ?? 'Unknown timeout'}',
        timeout: error.duration,
      );
    }

    // Add more error classification as needed
    return N8nException.unknown(
      'Unclassified error: $error',
      originalException: error is Exception ? error : null,
    );
  }

  /// Get retry statistics for operation
  Map<String, dynamic> getRetryStats(String operationId) {
    return {
      'attempts': _retryAttempts[operationId] ?? 0,
      'lastRetryTime': _lastRetryTime[operationId]?.toIso8601String(),
      'circuitBreakerState': _circuitBreaker?.state.name,
      'circuitBreakerFailures': _circuitBreaker?.failureCount ?? 0,
    };
  }

  /// Reset retry state for operation
  void resetRetryState(String operationId) {
    _retryAttempts.remove(operationId);
    _lastRetryTime.remove(operationId);
  }

  /// Reset circuit breaker
  void resetCircuitBreaker() {
    _circuitBreaker?.reset();
  }

  /// Get overall error handler statistics
  Map<String, dynamic> getStats() {
    return {
      'activeRetries': _retryAttempts.length,
      'circuitBreakerState': _circuitBreaker?.state.name,
      'circuitBreakerFailures': _circuitBreaker?.failureCount ?? 0,
      'config': {
        'maxRetries': config.maxRetries,
        'initialDelay': config.initialDelay.inMilliseconds,
        'maxDelay': config.maxDelay.inMilliseconds,
        'backoffMultiplier': config.backoffMultiplier,
        'circuitBreakerEnabled': config.enableCircuitBreaker,
      },
    };
  }

  @override
  String toString() {
    return 'N8nErrorHandler(maxRetries: ${config.maxRetries}, '
        'circuitBreaker: ${_circuitBreaker?.state.name ?? 'disabled'})';
  }
}
