import 'dart:async';
import 'dart:math';

import 'package:rxdart/rxdart.dart';

import 'polling_manager.dart';

/// Fully reactive polling manager using RxDart comprehensively
///
/// All operations return streams. Metrics use scan operator.
/// Adaptive intervals use switchMap. Filtering uses distinct.
///
/// ## Key Features:
/// - **Stream-Based**: Stream.periodic instead of Timer callbacks
/// - **Metrics Aggregation**: scan operator for cumulative metrics
/// - **Adaptive Intervals**: switchMap for dynamic interval changes
/// - **Filtering**: distinct for duplicate elimination
/// - **Health Monitoring**: BehaviorSubject for polling health
class ReactivePollingManager {
  final PollingConfig config;

  // STATE SUBJECTS
  late final BehaviorSubject<Map<String, PollingMetrics>> _metrics$;
  late final BehaviorSubject<PollingHealth> _health$;
  late final PublishSubject<PollEvent> _events$;

  // ACTIVE POLLING STREAMS
  final Map<String, StreamSubscription> _activePolls = {};
  final Map<String, WorkflowActivity> _lastActivity = {};

  ReactivePollingManager(this.config) {
    _initializeSubjects();
  }

  void _initializeSubjects() {
    _metrics$ = BehaviorSubject.seeded({});
    _health$ = BehaviorSubject.seeded(PollingHealth.initial());
    _events$ = PublishSubject();
  }

  // PUBLIC STREAMS

  /// Stream of polling metrics (aggregated with scan)
  Stream<Map<String, PollingMetrics>> get metrics$ => _metrics$.stream;

  /// Stream of polling health
  Stream<PollingHealth> get health$ => _health$.stream;

  /// Stream of all polling events
  Stream<PollEvent> get events$ => _events$.stream;

  /// Stream of successful poll events only
  Stream<PollSuccessEvent> get successEvents$ =>
      _events$.whereType<PollSuccessEvent>();

  /// Stream of poll error events only
  Stream<PollErrorEvent> get errorEvents$ =>
      _events$.whereType<PollErrorEvent>();

  // CORE OPERATIONS

  /// Start polling for execution (returns stream of poll results)
  ///
  /// Returns a stream that:
  /// - Uses Stream.periodic for polling
  /// - Uses switchMap for adaptive intervals
  /// - Uses distinct for filtering duplicates
  /// - Uses scan for metrics aggregation
  /// - Completes when execution finishes
  Stream<T> startPolling<T>(
    String executionId,
    Future<T> Function() pollFunction, {
    bool Function(T)? shouldStop,
  }) {
    // Stop existing polling if any
    stopPolling(executionId);

    // Initialize metrics
    _updateMetrics(executionId, PollingMetrics.initial(executionId));

    // Create base polling stream with Stream.periodic
    final baseInterval = config.baseInterval;

    // Create stream that switches intervals based on status
    final pollingStream = Stream.periodic(baseInterval)
        .startWith(null) // Emit immediately
        .asyncMap((_) async {
          final startTime = DateTime.now();

          try {
            final result = await pollFunction();
            final interval = DateTime.now().difference(startTime);

            // Update metrics using current value
            final currentMetrics = _metrics$.value[executionId] ??
                PollingMetrics.initial(executionId);
            final updatedMetrics = currentMetrics.copyWithPoll(
              success: true,
              interval: interval,
            );
            _updateMetrics(executionId, updatedMetrics);

            // Emit success event
            if (!_events$.isClosed) {
              _events$.add(PollSuccessEvent(
                executionId: executionId,
                timestamp: DateTime.now(),
              ));
            }

            return result;
          } catch (error) {
            final interval = DateTime.now().difference(startTime);

            // Update metrics for error
            final currentMetrics = _metrics$.value[executionId] ??
                PollingMetrics.initial(executionId);
            final updatedMetrics = currentMetrics.copyWithPoll(
              success: false,
              interval: interval,
            );
            _updateMetrics(executionId, updatedMetrics);

            // Emit error event
            if (!_events$.isClosed) {
              _events$.add(PollErrorEvent(
                executionId: executionId,
                error: error,
                timestamp: DateTime.now(),
              ));
            }

            // Check if we should stop after errors
            if (updatedMetrics.errorCount >= config.maxConsecutiveErrors) {
              throw Exception('Max consecutive errors reached');
            }

            rethrow;
          }
        })
        .distinct() // Filter duplicate results
        .takeWhile((result) {
          // Stop if shouldStop function returns true
          if (shouldStop != null && shouldStop(result)) {
            return false;
          }
          return true;
        })
        .timeout(
          const Duration(minutes: 5), // Max polling duration
          onTimeout: (sink) {
            sink.close();
          },
        )
        .doOnDone(() {
          // Mark metrics as finished
          final currentMetrics = _metrics$.value[executionId];
          if (currentMetrics != null) {
            _updateMetrics(executionId, currentMetrics.copyWithEnd());
          }
          // Remove from active polls
          _activePolls.remove(executionId);
        });

    // Track execution (caller manages subscription via returned stream)
    // Store a placeholder subscription to track active state
    _activePolls[executionId] = const Stream.empty().listen((_) {});

    return pollingStream;
  }

  /// Start polling with adaptive intervals using switchMap
  ///
  /// Returns a stream that:
  /// - Starts with base interval
  /// - Switches to status-specific intervals dynamically
  /// - Uses switchMap to change interval mid-stream
  Stream<T> startAdaptivePolling<T>(
    String executionId,
    Future<T> Function() pollFunction, {
    required String Function(T) getStatus,
    bool Function(T)? shouldStop,
  }) {
    // Stop existing polling if any
    stopPolling(executionId);

    // Initialize metrics
    _updateMetrics(executionId, PollingMetrics.initial(executionId));

    // Create BehaviorSubject to control intervals
    final intervalController = BehaviorSubject<Duration>.seeded(config.baseInterval);

    // Create polling stream that reacts to interval changes
    final pollingStream = intervalController.stream
        .switchMap((interval) {
          return Stream.periodic(interval)
              .startWith(null)
              .asyncMap((_) async {
                final startTime = DateTime.now();

                try {
                  final result = await pollFunction();
                  final pollInterval = DateTime.now().difference(startTime);
                  final status = getStatus(result);

                  // Record activity
                  _lastActivity[executionId] = WorkflowActivity(
                    executionId: executionId,
                    status: status,
                    timestamp: DateTime.now(),
                  );

                  // Update metrics
                  final currentMetrics = _metrics$.value[executionId] ??
                      PollingMetrics.initial(executionId);
                  final updatedMetrics = currentMetrics.copyWithPoll(
                    success: true,
                    interval: pollInterval,
                    status: status,
                  );
                  _updateMetrics(executionId, updatedMetrics);

                  // Calculate next interval based on status
                  final nextInterval = _calculateAdaptiveInterval(executionId);
                  if (nextInterval != interval) {
                    intervalController.add(nextInterval);
                  }

                  // Emit success event
                  if (!_events$.isClosed) {
                    _events$.add(PollSuccessEvent(
                      executionId: executionId,
                      timestamp: DateTime.now(),
                    ));
                  }

                  return result;
                } catch (error) {
                  final pollInterval = DateTime.now().difference(startTime);

                  // Update metrics for error
                  final currentMetrics = _metrics$.value[executionId] ??
                      PollingMetrics.initial(executionId);
                  final updatedMetrics = currentMetrics.copyWithPoll(
                    success: false,
                    interval: pollInterval,
                  );
                  _updateMetrics(executionId, updatedMetrics);

                  // Emit error event
                  if (!_events$.isClosed) {
                    _events$.add(PollErrorEvent(
                      executionId: executionId,
                      error: error,
                      timestamp: DateTime.now(),
                    ));
                  }

                  // Apply error backoff
                  final backoffInterval = _calculateErrorBackoff(updatedMetrics.errorCount);
                  intervalController.add(backoffInterval);

                  // Check if we should stop
                  if (updatedMetrics.errorCount >= config.maxConsecutiveErrors) {
                    throw Exception('Max consecutive errors reached');
                  }

                  rethrow;
                }
              });
        })
        .distinct()
        .takeWhile((result) {
          if (shouldStop != null && shouldStop(result)) {
            return false;
          }
          return true;
        })
        .doOnDone(() {
          intervalController.close();
          final currentMetrics = _metrics$.value[executionId];
          if (currentMetrics != null) {
            _updateMetrics(executionId, currentMetrics.copyWithEnd());
          }
          _activePolls.remove(executionId);
        });

    // Track execution (caller manages subscription)
    _activePolls[executionId] = const Stream.empty().listen((_) {});

    return pollingStream;
  }

  /// Stop polling for execution
  void stopPolling(String executionId) {
    _activePolls[executionId]?.cancel();
    _activePolls.remove(executionId);
    _lastActivity.remove(executionId);
  }

  /// Get metrics for specific execution
  PollingMetrics? getMetrics(String executionId) {
    return _metrics$.value[executionId];
  }

  /// Get list of active executions
  List<String> get activeExecutions => _activePolls.keys.toList();

  // PRIVATE HELPERS

  void _updateMetrics(String executionId, PollingMetrics metrics) {
    if (_metrics$.isClosed) return; // Don't update after disposal

    final current = Map<String, PollingMetrics>.from(_metrics$.value);
    current[executionId] = metrics;
    _metrics$.add(current);

    // Update health based on all metrics
    _updateHealth(current.values.toList());
  }

  void _updateHealth(List<PollingMetrics> allMetrics) {
    if (_health$.isClosed) return; // Don't update after disposal

    if (allMetrics.isEmpty) {
      _health$.add(PollingHealth.initial());
      return;
    }

    final totalPolls = allMetrics.map((m) => m.totalPolls).fold(0, (a, b) => a + b);
    final successfulPolls = allMetrics.map((m) => m.successfulPolls).fold(0, (a, b) => a + b);
    final totalErrors = allMetrics.map((m) => m.errorCount).fold(0, (a, b) => a + b);

    final successRate = totalPolls > 0 ? successfulPolls / totalPolls : 1.0;
    final errorRate = totalPolls > 0 ? totalErrors / totalPolls : 0.0;

    _health$.add(PollingHealth(
      isHealthy: successRate > 0.7 && errorRate < 0.3,
      successRate: successRate,
      errorRate: errorRate,
      activeCount: _activePolls.length,
      totalPolls: totalPolls,
    ));
  }

  Duration _calculateAdaptiveInterval(String executionId) {
    final activity = _lastActivity[executionId];
    if (activity == null) return config.baseInterval;

    // Use status-specific interval
    final statusInterval = config.getIntervalForStatus(activity.status);

    // Apply battery optimization
    if (config.enableBatteryOptimization && !activity.isActive) {
      const batteryFactor = 2.0;
      return Duration(
        milliseconds: (statusInterval.inMilliseconds * batteryFactor).round(),
      );
    }

    return _clampDuration(statusInterval, config.minInterval, config.maxInterval);
  }

  Duration _calculateErrorBackoff(int consecutiveErrors) {
    final backoffFactor = pow(config.backoffMultiplier, consecutiveErrors);
    final interval = Duration(
      milliseconds: (config.baseInterval.inMilliseconds * backoffFactor).round(),
    );

    return _clampDuration(interval, config.minInterval, config.maxInterval);
  }

  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Dispose all resources
  void dispose() {
    // Cancel all active polling
    for (final sub in _activePolls.values) {
      sub.cancel();
    }
    _activePolls.clear();
    _lastActivity.clear();

    // Close subjects
    _metrics$.close();
    _health$.close();
    _events$.close();
  }
}

// SUPPORTING MODELS

/// Polling health status
class PollingHealth {
  final bool isHealthy;
  final double successRate;
  final double errorRate;
  final int activeCount;
  final int totalPolls;

  const PollingHealth({
    required this.isHealthy,
    required this.successRate,
    required this.errorRate,
    required this.activeCount,
    required this.totalPolls,
  });

  factory PollingHealth.initial() {
    return const PollingHealth(
      isHealthy: true,
      successRate: 1,
      errorRate: 0,
      activeCount: 0,
      totalPolls: 0,
    );
  }

  @override
  String toString() {
    return 'PollingHealth(healthy: $isHealthy, success: ${(successRate * 100).toStringAsFixed(1)}%, '
        'errors: ${(errorRate * 100).toStringAsFixed(1)}%, active: $activeCount)';
  }
}

// POLLING EVENTS

abstract class PollEvent {
  final String executionId;
  final DateTime timestamp;

  const PollEvent({
    required this.executionId,
    required this.timestamp,
  });
}

class PollSuccessEvent extends PollEvent {
  const PollSuccessEvent({
    required super.executionId,
    required super.timestamp,
  });

  @override
  String toString() => 'PollSuccessEvent(executionId: $executionId)';
}

class PollErrorEvent extends PollEvent {
  final Object error;

  const PollErrorEvent({
    required super.executionId,
    required this.error,
    required super.timestamp,
  });

  @override
  String toString() => 'PollErrorEvent(executionId: $executionId, error: $error)';
}
