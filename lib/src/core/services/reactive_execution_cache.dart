/// Reactive Execution Cache with Invalidation
///
/// Smart cache with reactive invalidation and TTL management
library;

import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../models/n8n_models.dart';
import 'reactive_n8n_client.dart';

/// Smart cache with reactive invalidation
///
/// Features:
/// - BehaviorSubject for cache state
/// - TTL-based automatic expiration
/// - Manual invalidation (single, all, pattern-based)
/// - Auto-refresh on invalidation
/// - Merge pattern for cache hits and misses
/// - shareReplay for efficient multi-subscriber support
class ReactiveExecutionCache {
  final ReactiveN8nClient _client;
  final BehaviorSubject<Map<String, CachedExecution>> _cache$ =
      BehaviorSubject.seeded({});
  final PublishSubject<String> _invalidation$ = PublishSubject();
  final PublishSubject<CacheEvent> _events$ = PublishSubject();
  final BehaviorSubject<CacheMetrics> _metrics$ =
      BehaviorSubject.seeded(CacheMetrics.initial());
  final Duration _ttl;
  final Duration _cleanupInterval;

  Timer? _cleanupTimer;
  StreamSubscription<CacheEvent>? _eventSubscription;
  int _hitCount = 0;
  int _missCount = 0;

  ReactiveExecutionCache({
    required ReactiveN8nClient client,
    Duration ttl = const Duration(minutes: 5),
    Duration cleanupInterval = const Duration(minutes: 1),
  })  : _client = client,
        _ttl = ttl,
        _cleanupInterval = cleanupInterval {
    _startPeriodicCleanup();
    _subscribeToEvents();
  }

  /// Subscribe to cache events and update metrics
  void _subscribeToEvents() {
    _eventSubscription = _events$.listen((event) {
      if (event is CacheHitEvent) {
        _hitCount++;
      } else if (event is CacheMissEvent) {
        _missCount++;
      }

      if (!_metrics$.isClosed) {
        _metrics$.add(CacheMetrics(
          hitCount: _hitCount,
          missCount: _missCount,
          cacheSize: _cache$.value.length,
          timestamp: DateTime.now(),
        ));
      }
    });
  }

  /// Stream of cache state
  Stream<Map<String, CachedExecution>> get cache$ => _cache$.stream;

  /// Stream of cache size
  Stream<int> get cacheSize$ => _cache$.stream.map((cache) => cache.length);

  /// Stream of cache events
  Stream<CacheEvent> get events$ => _events$.stream;

  /// Stream of cache hits
  Stream<CacheHitEvent> get cacheHits$ => _events$.whereType<CacheHitEvent>();

  /// Stream of cache misses
  Stream<CacheMissEvent> get cacheMisses$ => _events$.whereType<CacheMissEvent>();

  /// Stream of cache metrics
  Stream<CacheMetrics> get metrics$ => _metrics$.stream;

  /// Watch cached execution with auto-refresh on invalidation
  ///
  /// Returns a stream that:
  /// - Emits from cache if valid
  /// - Emits null if not in cache or expired
  /// - Refetches on invalidation
  /// - Uses distinct to avoid duplicate emissions
  Stream<WorkflowExecution?> watch(String executionId) {
    return Rx.merge([
      // Emit from cache
      _cache$.stream.map((cache) {
        final cached = cache[executionId];

        if (cached == null) {
          _events$.add(CacheMissEvent(executionId: executionId));
          return null;
        }

        // Check if expired
        if (DateTime.now().difference(cached.timestamp) > _ttl) {
          _invalidation$.add(executionId);
          _events$.add(CacheExpiredEvent(executionId: executionId));
          return null;
        }

        _events$.add(CacheHitEvent(executionId: executionId));
        return cached.execution;
      }),

      // Refetch on invalidation
      _invalidation$.stream
          .where((id) => id == executionId)
          .switchMap((_) => _fetchAndCache(executionId)),
    ]).distinct();
  }

  /// Get execution from cache or fetch
  ///
  /// Returns immediately with cached value if valid,
  /// otherwise fetches from server
  Future<WorkflowExecution> get(String executionId) async {
    final cached = _cache$.value[executionId];

    // Check cache
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp);

      if (age <= _ttl) {
        _events$.add(CacheHitEvent(executionId: executionId));
        return cached.execution;
      } else {
        _events$.add(CacheExpiredEvent(executionId: executionId));
      }
    } else {
      _events$.add(CacheMissEvent(executionId: executionId));
    }

    // Fetch and cache
    return _fetchAndCache(executionId).first;
  }

  /// Set execution in cache manually
  void set(String executionId, WorkflowExecution execution) {
    final current = _cache$.value;
    final updated = Map<String, CachedExecution>.from(current);

    updated[executionId] = CachedExecution(
      execution: execution,
      timestamp: DateTime.now(),
    );

    _cache$.add(updated);
    _events$.add(CacheSetEvent(executionId: executionId));
  }

  /// Invalidate specific execution
  ///
  /// Triggers refetch for any watchers and removes from cache
  void invalidate(String executionId) {
    // Remove from cache
    final current = _cache$.value;
    if (current.containsKey(executionId)) {
      final updated = Map<String, CachedExecution>.from(current);
      updated.remove(executionId);
      _cache$.add(updated);
    }

    _invalidation$.add(executionId);
    _events$.add(CacheInvalidatedEvent(executionId: executionId));
  }

  /// Invalidate all cache entries
  void invalidateAll() {
    final executionIds = _cache$.value.keys.toList();

    for (final id in executionIds) {
      _invalidation$.add(id);
    }

    _cache$.add({});
    _events$.add(CacheInvalidatedAllEvent());
  }

  /// Invalidate by pattern (e.g., all executions for webhook)
  ///
  /// Example: `cache.invalidatePattern((id) => id.startsWith('exec-webhook-123'))`
  void invalidatePattern(bool Function(String executionId) matcher) {
    final current = _cache$.value;
    final toInvalidate = current.keys.where(matcher).toList();

    for (final id in toInvalidate) {
      _invalidation$.add(id);
      _events$.add(CacheInvalidatedEvent(executionId: id));
    }

    // Remove invalidated entries
    final updated = Map<String, CachedExecution>.from(current);
    for (final id in toInvalidate) {
      updated.remove(id);
    }

    _cache$.add(updated);
  }

  /// Prewarm cache with multiple executions
  Future<void> prewarm(List<String> executionIds) async {
    for (final id in executionIds) {
      try {
        await _fetchAndCache(id).first;
      } catch (e) {
        // Continue prewarming despite errors
      }
    }

    _events$.add(CachePrewarmedEvent(count: executionIds.length));
  }

  /// Clear expired entries manually
  int clearExpired() {
    final current = _cache$.value;
    final now = DateTime.now();
    final updated = Map<String, CachedExecution>.from(current);

    var clearedCount = 0;

    for (final entry in current.entries) {
      if (now.difference(entry.value.timestamp) > _ttl) {
        updated.remove(entry.key);
        clearedCount++;
      }
    }

    _cache$.add(updated);
    _events$.add(CacheCleanedEvent(clearedCount: clearedCount));

    return clearedCount;
  }

  /// Clear all cache entries
  void clear() {
    final count = _cache$.value.length;
    _cache$.add({});
    _events$.add(CacheClearedEvent(clearedCount: count));
  }

  /// Fetch execution and update cache
  Stream<WorkflowExecution> _fetchAndCache(String executionId) {
    return _client.pollExecutionStatus(executionId).doOnData((execution) {
      final current = _cache$.value;
      final updated = Map<String, CachedExecution>.from(current);

      updated[executionId] = CachedExecution(
        execution: execution,
        timestamp: DateTime.now(),
      );

      _cache$.add(updated);
      _events$.add(CacheSetEvent(executionId: executionId));
    }).take(1); // Only cache first emission
  }

  /// Start periodic cleanup of expired entries
  void _startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      clearExpired();
    });
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();
    _eventSubscription?.cancel();
    _cache$.close();
    _invalidation$.close();
    _events$.close();
    _metrics$.close();
  }
}

/// Cached execution wrapper
class CachedExecution {
  final WorkflowExecution execution;
  final DateTime timestamp;

  const CachedExecution({
    required this.execution,
    required this.timestamp,
  });

  /// Check if cache entry is expired
  bool isExpired(Duration ttl) {
    return DateTime.now().difference(timestamp) > ttl;
  }

  /// Age of cache entry
  Duration get age => DateTime.now().difference(timestamp);
}

/// Cache metrics
class CacheMetrics {
  final int hitCount;
  final int missCount;
  final int cacheSize;
  final DateTime timestamp;

  const CacheMetrics({
    required this.hitCount,
    required this.missCount,
    required this.cacheSize,
    required this.timestamp,
  });

  factory CacheMetrics.initial() => CacheMetrics(
        hitCount: 0,
        missCount: 0,
        cacheSize: 0,
        timestamp: DateTime.now(),
      );

  double get hitRate {
    final total = hitCount + missCount;
    if (total == 0) return 0;
    return hitCount / total;
  }

  double get missRate {
    final total = hitCount + missCount;
    if (total == 0) return 0;
    return missCount / total;
  }
}

/// Cache events
abstract class CacheEvent {
  final DateTime timestamp;

  const CacheEvent({required this.timestamp});
}

class CacheHitEvent extends CacheEvent {
  final String executionId;

  CacheHitEvent({required this.executionId}) : super(timestamp: DateTime.now());
}

class CacheMissEvent extends CacheEvent {
  final String executionId;

  CacheMissEvent({required this.executionId}) : super(timestamp: DateTime.now());
}

class CacheExpiredEvent extends CacheEvent {
  final String executionId;

  CacheExpiredEvent({required this.executionId}) : super(timestamp: DateTime.now());
}

class CacheSetEvent extends CacheEvent {
  final String executionId;

  CacheSetEvent({required this.executionId}) : super(timestamp: DateTime.now());
}

class CacheInvalidatedEvent extends CacheEvent {
  final String executionId;

  CacheInvalidatedEvent({required this.executionId})
      : super(timestamp: DateTime.now());
}

class CacheInvalidatedAllEvent extends CacheEvent {
  CacheInvalidatedAllEvent() : super(timestamp: DateTime.now());
}

class CachePrewarmedEvent extends CacheEvent {
  final int count;

  CachePrewarmedEvent({required this.count}) : super(timestamp: DateTime.now());
}

class CacheCleanedEvent extends CacheEvent {
  final int clearedCount;

  CacheCleanedEvent({required this.clearedCount}) : super(timestamp: DateTime.now());
}

class CacheClearedEvent extends CacheEvent {
  final int clearedCount;

  CacheClearedEvent({required this.clearedCount}) : super(timestamp: DateTime.now());
}
