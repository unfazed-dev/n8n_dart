import 'dart:async';
import 'dart:math';

/// Polling strategy types
enum PollingStrategy {
  fixed, // Constant interval polling
  adaptive, // Adjust based on workflow state
  smart, // Exponential backoff with activity detection
  hybrid, // Combination of adaptive and smart
}

/// Workflow activity tracking model
class WorkflowActivity {
  final String executionId;
  final String status;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const WorkflowActivity({
    required this.executionId,
    required this.status,
    required this.timestamp,
    this.metadata,
  });

  /// Check if activity indicates active workflow
  bool get isActive {
    switch (status.toLowerCase()) {
      case 'running':
      case 'waiting':
      case 'new':
        return true;
      case 'success':
      case 'error':
      case 'canceled':
      case 'crashed':
        return false;
      default:
        return false;
    }
  }

  /// Check if activity indicates finished workflow
  bool get isFinished => !isActive;

  /// Get activity age
  Duration get age => DateTime.now().difference(timestamp);

  @override
  String toString() {
    return 'WorkflowActivity(id: $executionId, status: $status, age: ${age.inSeconds}s)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkflowActivity &&
        other.executionId == executionId &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(executionId, status);
  }
}

/// Polling configuration
class PollingConfig {
  final PollingStrategy strategy;
  final Duration baseInterval;
  final Duration minInterval;
  final Duration maxInterval;
  final double backoffMultiplier;
  final Duration activityWindow;
  final int maxConsecutiveErrors;
  final bool enableBatteryOptimization;
  final bool enableAdaptiveThrottling;
  final Map<String, Duration> statusIntervals;

  const PollingConfig({
    this.strategy = PollingStrategy.smart,
    this.baseInterval = const Duration(seconds: 5),
    this.minInterval = const Duration(seconds: 1),
    this.maxInterval = const Duration(minutes: 5),
    this.backoffMultiplier = 1.5,
    this.activityWindow = const Duration(minutes: 10),
    this.maxConsecutiveErrors = 3,
    this.enableBatteryOptimization = true,
    this.enableAdaptiveThrottling = true,
    this.statusIntervals = const {
      'running': Duration(seconds: 2),
      'waiting': Duration(seconds: 10),
      'new': Duration(seconds: 3),
      'success': Duration(seconds: 30),
      'error': Duration(seconds: 30),
      'canceled': Duration(seconds: 60),
      'crashed': Duration(seconds: 60),
    },
  });

  /// Create minimal polling configuration
  factory PollingConfig.minimal() {
    return const PollingConfig(
      strategy: PollingStrategy.fixed,
      baseInterval: Duration(seconds: 30),
      enableBatteryOptimization: false,
      enableAdaptiveThrottling: false,
    );
  }

  /// Create high-frequency polling configuration
  factory PollingConfig.highFrequency() {
    return const PollingConfig(
      strategy: PollingStrategy.adaptive,
      baseInterval: Duration(seconds: 1),
      minInterval: Duration(milliseconds: 500),
      maxInterval: Duration(seconds: 30),
      enableBatteryOptimization: false,
    );
  }

  /// Create battery-optimized configuration
  factory PollingConfig.batteryOptimized() {
    return const PollingConfig(
      strategy: PollingStrategy.smart,
      baseInterval: Duration(seconds: 30),
      minInterval: Duration(seconds: 10),
      maxInterval: Duration(minutes: 10),
      backoffMultiplier: 2.0,
      enableBatteryOptimization: true,
      enableAdaptiveThrottling: true,
    );
  }

  /// Create balanced configuration
  factory PollingConfig.balanced() {
    return const PollingConfig(
      strategy: PollingStrategy.hybrid,
      baseInterval: Duration(seconds: 5),
      minInterval: Duration(seconds: 2),
      maxInterval: Duration(minutes: 2),
      backoffMultiplier: 1.3,
    );
  }

  /// Get interval for specific status
  Duration getIntervalForStatus(String status) {
    return statusIntervals[status.toLowerCase()] ?? baseInterval;
  }

  @override
  String toString() {
    return 'PollingConfig(strategy: $strategy, baseInterval: $baseInterval, '
        'batteryOptimized: $enableBatteryOptimization)';
  }
}

/// Polling statistics and metrics
class PollingMetrics {
  final String executionId;
  final int totalPolls;
  final int successfulPolls;
  final int errorCount;
  final Duration totalPollingTime;
  final Duration averageInterval;
  final DateTime startTime;
  final DateTime? endTime;
  final List<Duration> recentIntervals;
  final Map<String, int> statusCounts;

  const PollingMetrics({
    required this.executionId,
    required this.totalPolls,
    required this.successfulPolls,
    required this.errorCount,
    required this.totalPollingTime,
    required this.averageInterval,
    required this.startTime,
    this.endTime,
    required this.recentIntervals,
    required this.statusCounts,
  });

  /// Create initial metrics
  factory PollingMetrics.initial(String executionId) {
    return PollingMetrics(
      executionId: executionId,
      totalPolls: 0,
      successfulPolls: 0,
      errorCount: 0,
      totalPollingTime: Duration.zero,
      averageInterval: Duration.zero,
      startTime: DateTime.now(),
      recentIntervals: [],
      statusCounts: {},
    );
  }

  /// Calculate success rate
  double get successRate {
    if (totalPolls == 0) return 1.0;
    return successfulPolls / totalPolls;
  }

  /// Calculate error rate
  double get errorRate {
    if (totalPolls == 0) return 0.0;
    return errorCount / totalPolls;
  }

  /// Check if polling is efficient
  bool get isEfficient {
    return successRate > 0.8 && errorRate < 0.2;
  }

  /// Get polling duration
  Duration get pollingDuration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// Update metrics with new poll result
  PollingMetrics copyWithPoll({
    required bool success,
    required Duration interval,
    String? status,
  }) {
    final newTotalPolls = totalPolls + 1;
    final newSuccessfulPolls = success ? successfulPolls + 1 : successfulPolls;
    final newErrorCount = success ? errorCount : errorCount + 1;

    final newRecentIntervals = List<Duration>.from(recentIntervals);
    newRecentIntervals.add(interval);

    // Keep only recent intervals (last 20)
    if (newRecentIntervals.length > 20) {
      newRecentIntervals.removeAt(0);
    }

    // Calculate new average interval
    final totalIntervalMs =
        newRecentIntervals.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    final newAverageInterval = Duration(
      milliseconds: (totalIntervalMs / newRecentIntervals.length).round(),
    );

    // Update status counts
    final newStatusCounts = Map<String, int>.from(statusCounts);
    if (status != null) {
      newStatusCounts[status] = (newStatusCounts[status] ?? 0) + 1;
    }

    return PollingMetrics(
      executionId: executionId,
      totalPolls: newTotalPolls,
      successfulPolls: newSuccessfulPolls,
      errorCount: newErrorCount,
      totalPollingTime: totalPollingTime + interval,
      averageInterval: newAverageInterval,
      startTime: startTime,
      endTime: endTime,
      recentIntervals: newRecentIntervals,
      statusCounts: newStatusCounts,
    );
  }

  /// Mark polling as finished
  PollingMetrics copyWithEnd() {
    return PollingMetrics(
      executionId: executionId,
      totalPolls: totalPolls,
      successfulPolls: successfulPolls,
      errorCount: errorCount,
      totalPollingTime: totalPollingTime,
      averageInterval: averageInterval,
      startTime: startTime,
      endTime: DateTime.now(),
      recentIntervals: recentIntervals,
      statusCounts: statusCounts,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'executionId': executionId,
      'totalPolls': totalPolls,
      'successfulPolls': successfulPolls,
      'errorCount': errorCount,
      'successRate': successRate,
      'errorRate': errorRate,
      'totalPollingTime': totalPollingTime.inMilliseconds,
      'averageInterval': averageInterval.inMilliseconds,
      'pollingDuration': pollingDuration.inMilliseconds,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isEfficient': isEfficient,
      'statusCounts': statusCounts,
    };
  }

  @override
  String toString() {
    return 'PollingMetrics(id: $executionId, polls: $totalPolls, '
        'success: ${(successRate * 100).toStringAsFixed(1)}%, '
        'avgInterval: ${averageInterval.inSeconds}s)';
  }
}

/// Smart polling manager with multiple strategies
class SmartPollingManager {
  final PollingConfig config;

  // Active polling sessions
  final Map<String, Timer> _activeTimers = {};
  final Map<String, WorkflowActivity> _lastActivity = {};
  final Map<String, PollingMetrics> _metrics = {};
  final Map<String, int> _consecutiveErrors = {};
  final Map<String, DateTime> _lastPollTime = {};

  // Activity tracking
  final List<WorkflowActivity> _activityHistory = [];

  SmartPollingManager(this.config);

  /// Helper method to clamp Duration values
  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Start polling for execution
  void startPolling(String executionId, Future<void> Function() pollFunction) {
    // Stop existing polling if any
    stopPolling(executionId);

    // Initialize metrics
    _metrics[executionId] = PollingMetrics.initial(executionId);
    _consecutiveErrors[executionId] = 0;

    // Start polling based on strategy
    _scheduleNextPoll(executionId, pollFunction, config.baseInterval);
  }

  /// Stop polling for execution
  void stopPolling(String executionId) {
    _activeTimers[executionId]?.cancel();
    _activeTimers.remove(executionId);

    // Mark metrics as finished
    if (_metrics.containsKey(executionId)) {
      _metrics[executionId] = _metrics[executionId]!.copyWithEnd();
    }

    // Clean up tracking data
    _lastActivity.remove(executionId);
    _consecutiveErrors.remove(executionId);
    _lastPollTime.remove(executionId);
  }

  /// Record workflow activity
  void recordActivity(String executionId, String status) {
    final activity = WorkflowActivity(
      executionId: executionId,
      status: status,
      timestamp: DateTime.now(),
    );

    _lastActivity[executionId] = activity;
    _activityHistory.add(activity);

    // Keep activity history manageable (last 100 activities)
    if (_activityHistory.length > 100) {
      _activityHistory.removeAt(0);
    }

    // Update metrics if polling is active
    if (_metrics.containsKey(executionId)) {
      final lastPoll = _lastPollTime[executionId];
      if (lastPoll != null) {
        final interval = DateTime.now().difference(lastPoll);
        _metrics[executionId] = _metrics[executionId]!.copyWithPoll(
          success: true,
          interval: interval,
          status: status,
        );
      }
    }
  }

  /// Record polling error
  void recordError(String executionId) {
    _consecutiveErrors[executionId] =
        (_consecutiveErrors[executionId] ?? 0) + 1;

    // Update metrics
    if (_metrics.containsKey(executionId)) {
      final lastPoll = _lastPollTime[executionId];
      if (lastPoll != null) {
        final interval = DateTime.now().difference(lastPoll);
        _metrics[executionId] = _metrics[executionId]!.copyWithPoll(
          success: false,
          interval: interval,
        );
      }
    }
  }

  /// Schedule next poll based on strategy
  void _scheduleNextPoll(
    String executionId,
    Future<void> Function() pollFunction,
    Duration interval,
  ) {
    final adjustedInterval = _calculateNextInterval(executionId, interval);

    _activeTimers[executionId] = Timer(adjustedInterval, () async {
      await _executePoll(executionId, pollFunction);
    });
  }

  /// Execute poll with error handling
  Future<void> _executePoll(
    String executionId,
    Future<void> Function() pollFunction,
  ) async {
    _lastPollTime[executionId] = DateTime.now();

    try {
      await pollFunction();

      // Reset consecutive errors on success
      _consecutiveErrors[executionId] = 0;

      // Schedule next poll if still active
      if (_activeTimers.containsKey(executionId)) {
        final nextInterval =
            _calculateNextInterval(executionId, config.baseInterval);
        _scheduleNextPoll(executionId, pollFunction, nextInterval);
      }
    } catch (error) {
      recordError(executionId);

      // Check if we should continue polling after error
      final consecutiveErrors = _consecutiveErrors[executionId] ?? 0;
      if (consecutiveErrors < config.maxConsecutiveErrors) {
        // Schedule next poll with backoff
        final backoffInterval =
            _calculateErrorBackoffInterval(consecutiveErrors);
        _scheduleNextPoll(executionId, pollFunction, backoffInterval);
      } else {
        // Stop polling after too many consecutive errors
        stopPolling(executionId);
      }
    }
  }

  /// Calculate next polling interval based on strategy
  Duration _calculateNextInterval(String executionId, Duration baseInterval) {
    switch (config.strategy) {
      case PollingStrategy.fixed:
        return _calculateFixedInterval();

      case PollingStrategy.adaptive:
        return _calculateAdaptiveInterval(executionId);

      case PollingStrategy.smart:
        return _calculateSmartInterval(executionId);

      case PollingStrategy.hybrid:
        return _calculateHybridInterval(executionId);
    }
  }

  /// Calculate fixed interval
  Duration _calculateFixedInterval() {
    return config.baseInterval;
  }

  /// Calculate adaptive interval based on workflow state
  Duration _calculateAdaptiveInterval(String executionId) {
    final lastActivity = _lastActivity[executionId];
    if (lastActivity == null) return config.baseInterval;

    // Use status-specific intervals
    final statusInterval = config.getIntervalForStatus(lastActivity.status);

    // Apply battery optimization if enabled
    if (config.enableBatteryOptimization) {
      return _applyBatteryOptimization(statusInterval, lastActivity);
    }

    return _clampDuration(
        statusInterval, config.minInterval, config.maxInterval);
  }

  /// Calculate smart interval with exponential backoff
  Duration _calculateSmartInterval(String executionId) {
    final lastActivity = _lastActivity[executionId];
    if (lastActivity == null) return config.baseInterval;

    // Start with adaptive interval
    Duration interval = _calculateAdaptiveInterval(executionId);

    // Apply exponential backoff for inactive workflows
    if (!lastActivity.isActive) {
      final inactiveTime = lastActivity.age;
      final backoffFactor = _calculateBackoffFactor(inactiveTime);
      interval = Duration(
        milliseconds: (interval.inMilliseconds * backoffFactor).round(),
      );
    }

    // Apply activity-based throttling
    if (config.enableAdaptiveThrottling) {
      interval = _applyActivityThrottling(executionId, interval);
    }

    return _clampDuration(interval, config.minInterval, config.maxInterval);
  }

  /// Calculate hybrid interval combining adaptive and smart strategies
  Duration _calculateHybridInterval(String executionId) {
    final adaptiveInterval = _calculateAdaptiveInterval(executionId);
    final smartInterval = _calculateSmartInterval(executionId);

    // Use the longer of the two intervals for efficiency
    return Duration(
      milliseconds: max(
        adaptiveInterval.inMilliseconds,
        smartInterval.inMilliseconds,
      ),
    );
  }

  /// Calculate error backoff interval
  Duration _calculateErrorBackoffInterval(int consecutiveErrors) {
    final backoffFactor = pow(config.backoffMultiplier, consecutiveErrors);
    final interval = Duration(
      milliseconds:
          (config.baseInterval.inMilliseconds * backoffFactor).round(),
    );

    return _clampDuration(interval, config.minInterval, config.maxInterval);
  }

  /// Apply battery optimization
  Duration _applyBatteryOptimization(
      Duration interval, WorkflowActivity activity) {
    // Increase interval for inactive workflows to save battery
    if (!activity.isActive) {
      const batteryFactor = 2.0; // Double the interval for inactive workflows
      return Duration(
        milliseconds: (interval.inMilliseconds * batteryFactor).round(),
      );
    }

    return interval;
  }

  /// Calculate backoff factor based on inactive time
  double _calculateBackoffFactor(Duration inactiveTime) {
    // Gradually increase polling interval for long-inactive workflows
    final minutes = inactiveTime.inMinutes;

    if (minutes < 5) return 1.0;
    if (minutes < 15) return 1.5;
    if (minutes < 30) return 2.0;
    if (minutes < 60) return 3.0;
    return 4.0;
  }

  /// Apply activity-based throttling
  Duration _applyActivityThrottling(String executionId, Duration interval) {
    final metrics = _metrics[executionId];
    if (metrics == null) return interval;

    // If polling is very efficient, we can afford to poll more frequently
    if (metrics.isEfficient && metrics.totalPolls > 10) {
      return Duration(
        milliseconds: (interval.inMilliseconds * 0.8).round(),
      );
    }

    // If polling is inefficient, reduce frequency
    if (metrics.errorRate > 0.3 && metrics.totalPolls > 5) {
      return Duration(
        milliseconds: (interval.inMilliseconds * 1.5).round(),
      );
    }

    return interval;
  }

  /// Get recent activity for execution
  List<WorkflowActivity> getRecentActivity(String executionId,
      {Duration? window}) {
    final cutoff = DateTime.now().subtract(window ?? config.activityWindow);

    return _activityHistory
        .where((activity) =>
            activity.executionId == executionId &&
            activity.timestamp.isAfter(cutoff))
        .toList();
  }

  /// Get polling metrics for execution
  PollingMetrics? getMetrics(String executionId) {
    return _metrics[executionId];
  }

  /// Get all active polling sessions
  List<String> get activeExecutions => _activeTimers.keys.toList();

  /// Get overall polling statistics
  Map<String, dynamic> getOverallStats() {
    final allMetrics = _metrics.values.toList();

    if (allMetrics.isEmpty) {
      return {
        'totalExecutions': 0,
        'activeExecutions': 0,
        'totalPolls': 0,
        'averageSuccessRate': 0.0,
        'averageErrorRate': 0.0,
      };
    }

    final totalPolls =
        allMetrics.map((m) => m.totalPolls).reduce((a, b) => a + b);
    final totalSuccessful =
        allMetrics.map((m) => m.successfulPolls).reduce((a, b) => a + b);
    final totalErrors =
        allMetrics.map((m) => m.errorCount).reduce((a, b) => a + b);

    return {
      'totalExecutions': allMetrics.length,
      'activeExecutions': _activeTimers.length,
      'totalPolls': totalPolls,
      'totalSuccessful': totalSuccessful,
      'totalErrors': totalErrors,
      'averageSuccessRate': totalPolls > 0 ? totalSuccessful / totalPolls : 0.0,
      'averageErrorRate': totalPolls > 0 ? totalErrors / totalPolls : 0.0,
      'recentActivity': _activityHistory.length,
      'config': {
        'strategy': config.strategy.name,
        'baseInterval': config.baseInterval.inMilliseconds,
        'batteryOptimized': config.enableBatteryOptimization,
        'adaptiveThrottling': config.enableAdaptiveThrottling,
      },
    };
  }

  /// Dispose all resources
  void dispose() {
    // Cancel all active timers
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }

    // Clear all data
    _activeTimers.clear();
    _lastActivity.clear();
    _metrics.clear();
    _consecutiveErrors.clear();
    _lastPollTime.clear();
    _activityHistory.clear();
  }

  @override
  String toString() {
    return 'SmartPollingManager(strategy: ${config.strategy}, '
        'active: ${_activeTimers.length}, '
        'total: ${_metrics.length})';
  }
}
