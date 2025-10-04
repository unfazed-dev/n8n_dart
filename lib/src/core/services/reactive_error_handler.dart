import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../exceptions/error_handling.dart';

/// Circuit breaker states for reactive error handling
enum CircuitState {
  open, // Circuit is open, failing fast
  halfOpen, // Testing if service recovered
  closed, // Normal operation
}

/// Error handler configuration for reactive streams
class ErrorHandlerConfig {
  final int errorThreshold;
  final Duration errorWindow;
  final Duration circuitBreakerTimeout;
  final int maxRetries;
  final Duration initialRetryDelay;
  final Duration maxRetryDelay;
  final double retryBackoffMultiplier;
  final bool enableCircuitBreaker;

  const ErrorHandlerConfig({
    this.errorThreshold = 5,
    this.errorWindow = const Duration(minutes: 5),
    this.circuitBreakerTimeout = const Duration(minutes: 1),
    this.maxRetries = 3,
    this.initialRetryDelay = const Duration(milliseconds: 500),
    this.maxRetryDelay = const Duration(seconds: 30),
    this.retryBackoffMultiplier = 2.0,
    this.enableCircuitBreaker = true,
  });

  /// Create minimal configuration
  factory ErrorHandlerConfig.minimal() {
    return const ErrorHandlerConfig(
      errorThreshold: 10,
      maxRetries: 1,
      enableCircuitBreaker: false,
    );
  }

  /// Create resilient configuration
  factory ErrorHandlerConfig.resilient() {
    return const ErrorHandlerConfig(
      errorThreshold: 10,
      errorWindow: Duration(minutes: 10),
      maxRetries: 5,
      initialRetryDelay: Duration(milliseconds: 200),
      maxRetryDelay: Duration(minutes: 2),
      retryBackoffMultiplier: 1.5,
    );
  }

  /// Create strict configuration
  factory ErrorHandlerConfig.strict() {
    return const ErrorHandlerConfig(
      errorThreshold: 3,
      errorWindow: Duration(minutes: 1),
      maxRetries: 2,
      circuitBreakerTimeout: Duration(seconds: 30),
    );
  }

  @override
  String toString() {
    return 'ErrorHandlerConfig(threshold: $errorThreshold, maxRetries: $maxRetries, '
        'circuitBreaker: $enableCircuitBreaker)';
  }
}

/// Reactive error handler for n8n operations
///
/// Provides reactive error handling with:
/// - Error stream publishing
/// - Circuit breaker pattern
/// - Error rate monitoring
/// - Automatic retry with backoff
/// - Error filtering by type
class ReactiveErrorHandler {
  final ErrorHandlerConfig config;

  // Error streams
  final PublishSubject<N8nException> _errors$ = PublishSubject();

  // Circuit breaker state
  final BehaviorSubject<CircuitState> _circuitState$ =
      BehaviorSubject.seeded(CircuitState.closed);

  // Error tracking
  final List<DateTime> _recentErrors = [];
  int _failureCount = 0;
  DateTime? _circuitOpenedAt;

  ReactiveErrorHandler(this.config);

  /// Stream of all errors
  Stream<N8nException> get errors$ => _errors$.stream;

  /// Stream of network errors only
  Stream<N8nException> get networkErrors$ =>
      _errors$.where((e) => e.type == N8nErrorType.network);

  /// Stream of server errors only
  Stream<N8nException> get serverErrors$ =>
      _errors$.where((e) => e.type == N8nErrorType.serverError);

  /// Stream of timeout errors only
  Stream<N8nException> get timeoutErrors$ =>
      _errors$.where((e) => e.type == N8nErrorType.timeout);

  /// Stream of authentication errors only
  Stream<N8nException> get authErrors$ =>
      _errors$.where((e) => e.type == N8nErrorType.authentication);

  /// Stream of workflow errors only
  Stream<N8nException> get workflowErrors$ =>
      _errors$.where((e) => e.type == N8nErrorType.workflow);

  /// Stream of error rate (errors per second)
  Stream<double> get errorRate$ {
    return _errors$.scan<double>((accumulated, error, index) {
      _cleanOldErrors();
      return _recentErrors.length / config.errorWindow.inSeconds;
    }, 0);
  }

  /// Stream of circuit breaker state changes
  Stream<CircuitState> get circuitState$ => _circuitState$.stream;

  /// Get current circuit state
  CircuitState get currentCircuitState => _circuitState$.value;

  /// Handle and publish an error
  void handleError(N8nException error) {
    // Track error
    _recentErrors.add(DateTime.now());
    _failureCount++;

    // Publish error
    _errors$.add(error);

    // Update circuit breaker
    if (config.enableCircuitBreaker) {
      _updateCircuitBreaker();
    }
  }

  /// Wrap a stream with retry logic
  Stream<T> withRetry<T>(Stream<T> stream) {
    return stream.handleError((error, stackTrace) {
      final n8nError = _classifyError(error);
      handleError(n8nError);

      // Re-throw if should not retry
      if (!_shouldRetry(n8nError) ||
          currentCircuitState == CircuitState.open) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  /// Check if error should be retried
  bool _shouldRetry(N8nException error) {
    // Don't retry if circuit is open
    if (currentCircuitState == CircuitState.open) {
      return false;
    }

    // Check if error type is retryable
    if (!error.isRetryable) {
      return false;
    }

    // Check retry count
    final retryCount = error.retryCount ?? _failureCount;
    if (retryCount > config.maxRetries) {
      return false;
    }

    return true;
  }

  /// Calculate retry delay with exponential backoff
  Duration calculateRetryDelay(int attempt) {
    if (attempt <= 0) return Duration.zero;

    final baseDelay = config.initialRetryDelay.inMilliseconds *
        pow(config.retryBackoffMultiplier, attempt - 1);

    final delayMs = baseDelay.clamp(
      config.initialRetryDelay.inMilliseconds.toDouble(),
      config.maxRetryDelay.inMilliseconds.toDouble(),
    );

    return Duration(milliseconds: delayMs.round());
  }

  /// Update circuit breaker state
  void _updateCircuitBreaker() {
    final currentState = _circuitState$.value;

    switch (currentState) {
      case CircuitState.closed:
        // Clean old errors
        _cleanOldErrors();

        // Check if threshold exceeded
        if (_recentErrors.length >= config.errorThreshold) {
          _openCircuit();
        }
        break;

      case CircuitState.open:
        // Check if timeout elapsed
        if (_circuitOpenedAt != null) {
          final elapsed = DateTime.now().difference(_circuitOpenedAt!);
          if (elapsed >= config.circuitBreakerTimeout) {
            _halfOpenCircuit();
          }
        }
        break;

      case CircuitState.halfOpen:
        // On any error in half-open state, go back to open
        _openCircuit();
        break;
    }
  }

  /// Open the circuit breaker
  void _openCircuit() {
    _circuitState$.add(CircuitState.open);
    _circuitOpenedAt = DateTime.now();
  }

  /// Half-open the circuit breaker (testing)
  void _halfOpenCircuit() {
    _circuitState$.add(CircuitState.halfOpen);
  }

  /// Close the circuit breaker (normal operation)
  void closeCircuit() {
    _circuitState$.add(CircuitState.closed);
    _failureCount = 0;
    _recentErrors.clear();
    _circuitOpenedAt = null;
  }

  /// Clean errors outside the error window
  void _cleanOldErrors() {
    final cutoff = DateTime.now().subtract(config.errorWindow);
    _recentErrors.removeWhere((errorTime) => errorTime.isBefore(cutoff));
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

    return N8nException.unknown(
      'Unclassified error: $error',
      originalException: error is Exception ? error : null,
    );
  }

  /// Get error statistics
  Map<String, dynamic> getStats() {
    _cleanOldErrors();

    return {
      'circuitState': currentCircuitState.name,
      'failureCount': _failureCount,
      'recentErrors': _recentErrors.length,
      'errorRate': _recentErrors.length / config.errorWindow.inSeconds,
      'circuitOpenedAt': _circuitOpenedAt?.toIso8601String(),
      'config': {
        'errorThreshold': config.errorThreshold,
        'maxRetries': config.maxRetries,
        'enableCircuitBreaker': config.enableCircuitBreaker,
      },
    };
  }

  /// Reset error handler state
  void reset() {
    _recentErrors.clear();
    _failureCount = 0;
    _circuitOpenedAt = null;
    _circuitState$.add(CircuitState.closed);
  }

  /// Dispose resources
  void dispose() {
    _errors$.close();
    _circuitState$.close();
  }
}

// Helper function for exponential calculation
num pow(num base, num exponent) {
  if (exponent == 0) return 1;
  if (exponent == 1) return base;

  num result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
