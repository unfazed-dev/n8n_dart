# RxDart Migration Guide

**Complete guide for migrating from Future-based to Reactive n8n_dart**

## Table of Contents

1. [Overview](#overview)
2. [Why Migrate to Reactive?](#why-migrate-to-reactive)
3. [Migration Strategies](#migration-strategies)
4. [Step-by-Step Migration](#step-by-step-migration)
5. [API Comparison](#api-comparison)
6. [Common Patterns](#common-patterns)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The n8n_dart package now provides **two APIs**:

- **Legacy Future-based API** - `N8nClient` (still supported)
- **New Reactive API** - `ReactiveN8nClient` (recommended)

Both APIs are fully functional and can coexist in the same application during migration.

### What Changed?

| Aspect | Legacy (Future-based) | Reactive (Stream-based) |
|--------|----------------------|-------------------------|
| **Return Type** | `Future<T>` | `Stream<T>` |
| **State Management** | Manual tracking | `BehaviorSubject` |
| **Events** | Callbacks | `PublishSubject` streams |
| **Polling** | `Timer` + callbacks | Stream operators |
| **Error Handling** | try/catch blocks | Stream error handlers |
| **Composition** | Sequential awaits | RxDart operators |

---

## Why Migrate to Reactive?

### Benefits

1. **Better State Management** - Automatic propagation of state changes
2. **Powerful Composition** - Combine multiple operations with operators
3. **Real-time Updates** - Stream-based subscriptions for live data
4. **Error Recovery** - Built-in retry, fallback, and circuit breaker patterns
5. **Memory Efficiency** - Automatic resource cleanup with `shareReplay`
6. **Type Safety** - Strong typing throughout the reactive chain

### Performance Improvements

```dart
// Legacy: Manual polling with Timer (inefficient)
Timer.periodic(Duration(seconds: 2), (timer) async {
  final execution = await client.getExecutionStatus(executionId);
  // Handle manually...
});

// Reactive: Automatic polling with adaptive intervals
client.pollExecutionStatus(executionId).listen((execution) {
  // Automatically adjusts interval based on status!
  // Stops polling when finished!
});
```

---

## Migration Strategies

### Strategy 1: Gradual Migration (Recommended)

Migrate feature by feature while maintaining backwards compatibility.

**Pros:**
- ✅ Low risk
- ✅ Can test incrementally
- ✅ No breaking changes for users

**Cons:**
- ❌ Longer migration time
- ❌ Temporary code duplication

### Strategy 2: Full Rewrite

Replace all `N8nClient` usage with `ReactiveN8nClient` at once.

**Pros:**
- ✅ Clean codebase
- ✅ Full reactive benefits immediately
- ✅ No legacy code maintenance

**Cons:**
- ❌ Higher risk
- ❌ More testing required upfront

### Strategy 3: Adapter Pattern

Use both APIs simultaneously with an adapter layer.

**Pros:**
- ✅ Can use best tool for each use case
- ✅ No forced migration
- ✅ Learn reactive gradually

**Cons:**
- ❌ Higher complexity
- ❌ Larger bundle size

---

## Step-by-Step Migration

### Phase 1: Setup

**1. Update dependencies**

```yaml
# pubspec.yaml
dependencies:
  n8n_dart: ^2.0.0  # Version with reactive support
  rxdart: ^0.27.0   # RxDart for reactive programming
```

**2. Create reactive client**

```dart
import 'package:n8n_dart/n8n_dart.dart';
import 'package:rxdart/rxdart.dart';

// Keep existing legacy client
final legacyClient = N8nClient(
  config: N8nConfigProfiles.production(
    baseUrl: 'https://n8n.example.com',
    apiKey: 'your-api-key',
  ),
);

// Add new reactive client (can coexist!)
final reactiveClient = ReactiveN8nClient(
  config: N8nConfigProfiles.production(
    baseUrl: 'https://n8n.example.com',
    apiKey: 'your-api-key',
  ),
);
```

### Phase 2: Migrate Simple Operations

**Start with single workflow execution (easiest)**

```dart
// BEFORE (Legacy Future-based)
Future<void> startWorkflowLegacy() async {
  try {
    final executionId = await legacyClient.startWorkflow(
      'webhook-123',
      {'data': 'test'},
    );
    print('Started: $executionId');
  } catch (error) {
    print('Error: $error');
  }
}

// AFTER (Reactive Stream-based)
void startWorkflowReactive() {
  reactiveClient.startWorkflow('webhook-123', {'data': 'test'}).listen(
    (execution) {
      print('Started: ${execution.id}');
    },
    onError: (error) {
      print('Error: $error');
    },
  );
}

// OR with async/await pattern (if you prefer)
Future<void> startWorkflowReactiveAsync() async {
  try {
    final execution = await reactiveClient
        .startWorkflow('webhook-123', {'data': 'test'})
        .first;  // Convert stream to future
    print('Started: ${execution.id}');
  } catch (error) {
    print('Error: $error');
  }
}
```

### Phase 3: Migrate Polling

**Polling is where reactive shines!**

```dart
// BEFORE (Legacy with manual polling)
Future<void> pollExecutionLegacy(String executionId) async {
  while (true) {
    await Future.delayed(Duration(seconds: 2));

    final execution = await legacyClient.getExecutionStatus(executionId);
    print('Status: ${execution.status}');

    if (execution.isFinished) {
      print('Completed!');
      break;
    }
  }
}

// AFTER (Reactive with automatic polling)
void pollExecutionReactive(String executionId) {
  reactiveClient.pollExecutionStatus(executionId).listen(
    (execution) {
      print('Status: ${execution.status}');

      if (execution.isFinished) {
        print('Completed!');
        // Stream auto-completes when finished!
      }
    },
    onDone: () => print('Polling complete'),
  );
}
```

### Phase 4: Migrate State Management

**Use BehaviorSubjects for reactive state**

```dart
// BEFORE (Legacy with manual state tracking)
class WorkflowServiceLegacy {
  Map<String, WorkflowExecution> _executionCache = {};

  Future<WorkflowExecution> getExecution(String id) async {
    if (_executionCache.containsKey(id)) {
      return _executionCache[id]!;
    }

    final execution = await legacyClient.getExecutionStatus(id);
    _executionCache[id] = execution;
    return execution;
  }

  void clearCache() {
    _executionCache.clear();
  }
}

// AFTER (Reactive with automatic state propagation)
class WorkflowServiceReactive {
  final ReactiveN8nClient client;

  WorkflowServiceReactive(this.client);

  // State automatically tracked via client.executionState$
  Stream<Map<String, WorkflowExecution>> get executions$ =>
      client.executionState$;

  Stream<WorkflowExecution?> watchExecution(String id) {
    return client.executionState$.map((state) => state[id]);
  }

  // No manual cache management needed!
}
```

### Phase 5: Migrate Error Handling

**Leverage reactive error recovery**

```dart
// BEFORE (Legacy with manual retry)
Future<WorkflowExecution> getExecutionWithRetryLegacy(
  String executionId,
) async {
  int retries = 0;
  const maxRetries = 3;

  while (retries < maxRetries) {
    try {
      return await legacyClient.getExecutionStatus(executionId);
    } catch (error) {
      retries++;
      if (retries >= maxRetries) rethrow;
      await Future.delayed(Duration(seconds: retries * 2));
    }
  }

  throw Exception('Max retries exceeded');
}

// AFTER (Reactive with automatic retry)
Stream<WorkflowExecution> getExecutionWithRetryReactive(
  String executionId,
) {
  return reactiveClient
      .watchExecution(executionId)  // Already includes retry logic!
      .onErrorReturnWith((error, stackTrace) {
        // Fallback value if all retries fail
        return WorkflowExecution(
          id: executionId,
          status: WorkflowStatus.error,
          finished: true,
          data: {'error': error.toString()},
        );
      });
}
```

### Phase 6: Advanced Patterns

**Use RxDart operators for complex workflows**

```dart
// Parallel execution with combineLatest
Stream<List<WorkflowExecution>> runParallel(
  List<String> webhookIds,
  Map<String, dynamic> data,
) {
  final streams = webhookIds.map((id) =>
    reactiveClient.startWorkflow(id, data)
  ).toList();

  return Rx.combineLatest<WorkflowExecution, List<WorkflowExecution>>(
    streams,
    (values) => values,
  );
}

// Sequential execution with concatMap
Stream<WorkflowExecution> runSequential(
  List<String> webhookIds,
  Map<String, dynamic> data,
) {
  return Stream.fromIterable(webhookIds)
      .concatMap((id) => reactiveClient.startWorkflow(id, data));
}

// Race condition (first to complete wins)
Stream<WorkflowExecution> runRace(
  List<String> webhookIds,
  Map<String, dynamic> data,
) {
  return reactiveClient.raceWorkflows(webhookIds, data);
}

// Throttled execution (rate limiting)
Stream<WorkflowExecution> runThrottled(
  Stream<Map<String, dynamic>> dataStream,
  String webhookId,
) {
  return reactiveClient.startWorkflowsThrottled(
    dataStream,
    webhookId,
    throttleDuration: Duration(seconds: 1),
  );
}
```

---

## API Comparison

### Starting Workflows

| Operation | Legacy | Reactive |
|-----------|--------|----------|
| Start workflow | `Future<String> startWorkflow()` | `Stream<WorkflowExecution> startWorkflow()` |
| Return value | Execution ID (String) | Full execution object |
| Error handling | try/catch | `.onError()` or stream error handlers |
| Multiple subscribers | Not applicable | Supported via `shareReplay` |

```dart
// Legacy
final executionId = await legacyClient.startWorkflow('webhook', data);

// Reactive
final execution = await reactiveClient.startWorkflow('webhook', data).first;
// OR subscribe to stream
reactiveClient.startWorkflow('webhook', data).listen((execution) { });
```

### Polling Status

| Operation | Legacy | Reactive |
|-----------|--------|----------|
| Get status | `Future<WorkflowExecution> getExecutionStatus()` | `Stream<WorkflowExecution> pollExecutionStatus()` |
| Polling | Manual with Timer | Automatic with adaptive intervals |
| Stop condition | Manual check | Auto-completes when `finished == true` |
| Duplicate filtering | Manual | Automatic via `distinctUntilChanged()` |

```dart
// Legacy
Timer.periodic(Duration(seconds: 2), (timer) async {
  final execution = await legacyClient.getExecutionStatus(id);
  if (execution.isFinished) timer.cancel();
});

// Reactive
reactiveClient.pollExecutionStatus(id).listen((execution) {
  // Auto-stops when finished!
});
```

### Error Handling

| Operation | Legacy | Reactive |
|-----------|--------|----------|
| Retry | Manual implementation | `retry()`, `retryWhen()` operators |
| Fallback | Manual try/catch | `onErrorReturnWith()` |
| Circuit breaker | Manual tracking | Built into `ReactiveErrorHandler` |
| Error categorization | Manual | Automatic streams per error type |

```dart
// Legacy
try {
  final result = await legacyClient.startWorkflow('webhook', data);
} catch (error) {
  if (error is N8nException && error.isRetryable) {
    // Manual retry logic...
  }
}

// Reactive
reactiveClient
    .startWorkflow('webhook', data)
    .retry(3)  // Automatic retry
    .onErrorReturnWith((error, stackTrace) => fallbackValue);
```

---

## Common Patterns

### Pattern 1: Watch Multiple Executions

```dart
// Monitor progress of multiple workflows simultaneously
void watchMultiple(List<String> executionIds) {
  reactiveClient.watchMultipleExecutions(executionIds).listen((executions) {
    for (var execution in executions) {
      print('${execution.id}: ${execution.status}');
    }
  });
}
```

### Pattern 2: Event-Driven Architecture

```dart
// React to workflow lifecycle events
void setupEventHandlers() {
  // Listen to all events
  reactiveClient.workflowEvents$.listen((event) {
    if (event is WorkflowStartedEvent) {
      print('Workflow ${event.executionId} started');
    } else if (event is WorkflowCompletedEvent) {
      print('Workflow ${event.executionId} completed: ${event.status}');
    } else if (event is WorkflowErrorEvent) {
      print('Workflow ${event.executionId} error: ${event.error}');
    }
  });

  // Or listen to specific event types
  reactiveClient.workflowStarted$.listen((event) {
    print('Started: ${event.executionId}');
  });

  reactiveClient.workflowCompleted$.listen((event) {
    print('Completed: ${event.executionId}');
  });

  reactiveClient.workflowErrors$.listen((event) {
    print('Error: ${event.error}');
  });
}
```

### Pattern 3: State Synchronization

```dart
// Keep UI in sync with execution state
class WorkflowViewModel {
  final ReactiveN8nClient client;

  WorkflowViewModel(this.client);

  // Expose state streams to UI
  Stream<Map<String, WorkflowExecution>> get executions$ =>
      client.executionState$;

  Stream<int> get activeCount$ =>
      client.executionState$.map((state) =>
        state.values.where((e) => !e.isFinished).length
      );

  Stream<int> get completedCount$ =>
      client.executionState$.map((state) =>
        state.values.where((e) => e.status == WorkflowStatus.success).length
      );

  Stream<ConnectionState> get connectionStatus$ =>
      client.connectionState$;

  Stream<PerformanceMetrics> get metrics$ =>
      client.metrics$;
}

// In Flutter widget
StreamBuilder<int>(
  stream: viewModel.activeCount$,
  builder: (context, snapshot) {
    return Text('Active: ${snapshot.data ?? 0}');
  },
)
```

### Pattern 4: Queue Management

```dart
// Use ReactiveWorkflowQueue for automatic throttling
import 'package:n8n_dart/n8n_dart.dart';

void setupQueue() {
  final queue = ReactiveWorkflowQueue(
    client: reactiveClient,
    config: QueueConfig.standard(),
  );

  // Enqueue multiple workflows
  queue.enqueue('webhook-1', {'priority': 'high'});
  queue.enqueue('webhook-2', {'priority': 'normal'});
  queue.enqueue('webhook-3', {'priority': 'low'});

  // Watch queue processing
  queue.processQueue().listen((execution) {
    print('Processed: ${execution.id}');
  });

  // Monitor queue metrics
  queue.metrics$.listen((metrics) {
    print('Queue size: ${metrics.queueSize}');
    print('Processed: ${metrics.processedCount}');
    print('Success rate: ${metrics.successRate}');
  });
}
```

### Pattern 5: Smart Caching

```dart
// Use ReactiveExecutionCache for intelligent caching
import 'package:n8n_dart/n8n_dart.dart';

void setupCache() {
  final cache = ReactiveExecutionCache(
    client: reactiveClient,
    ttl: Duration(minutes: 5),
  );

  // Watch execution with automatic caching
  cache.watch('execution-123').listen((execution) {
    if (execution != null) {
      print('From cache: ${execution.status}');
    } else {
      print('Cache miss - fetching...');
    }
  });

  // Invalidate when needed
  cache.invalidate('execution-123');

  // Invalidate by pattern
  cache.invalidatePattern((id) => id.startsWith('webhook-'));

  // Monitor cache metrics
  cache.metrics$.listen((metrics) {
    print('Hit rate: ${metrics.hitRate}');
    print('Cache size: ${metrics.cacheSize}');
  });
}
```

---

## Troubleshooting

### Issue: "Stream has already been listened to"

**Problem:** Trying to subscribe to a single-subscription stream multiple times.

**Solution:** Use `shareReplay()` or `asBroadcastStream()`:

```dart
// WRONG
final stream = reactiveClient.startWorkflow('webhook', data);
stream.listen((e) => print('Listener 1: $e'));
stream.listen((e) => print('Listener 2: $e'));  // ERROR!

// RIGHT
final stream = reactiveClient
    .startWorkflow('webhook', data)
    .shareReplay(maxSize: 1);  // Already applied in ReactiveN8nClient!

stream.listen((e) => print('Listener 1: $e'));
stream.listen((e) => print('Listener 2: $e'));  // OK!
```

### Issue: Memory Leaks

**Problem:** Subscriptions not cancelled, subjects not closed.

**Solution:** Always dispose and cancel subscriptions:

```dart
class MyService {
  final ReactiveN8nClient client;
  final List<StreamSubscription> _subscriptions = [];

  MyService(this.client) {
    // Track all subscriptions
    _subscriptions.add(
      client.workflowEvents$.listen((event) { })
    );
  }

  void dispose() {
    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // Dispose client
    client.dispose();
  }
}
```

### Issue: Stream Never Completes

**Problem:** Polling stream doesn't stop.

**Solution:** Ensure `finished` property is correctly set:

```dart
// Check execution model
final execution = await reactiveClient.pollExecutionStatus(id).first;
print('Finished: ${execution.finished}');  // Should be true when done

// Polling auto-stops when execution.finished == true
```

### Issue: Errors Not Being Caught

**Problem:** Stream errors crash the app.

**Solution:** Add error handlers:

```dart
// Add onError callback
reactiveClient.startWorkflow('webhook', data).listen(
  (execution) => print('Success: $execution'),
  onError: (error) => print('Error: $error'),  // Catch errors!
);

// Or use stream operators
reactiveClient
    .startWorkflow('webhook', data)
    .handleError((error) {
      print('Handled: $error');
    });
```

### Issue: Type Errors with Operators

**Problem:** Type inference fails with RxDart operators.

**Solution:** Be explicit with generic types:

```dart
// WRONG (type inference fails)
final streams = webhookIds.map((id) =>
  reactiveClient.startWorkflow(id, data)
);

Rx.combineLatest(streams, (values) => values);  // Type error!

// RIGHT (explicit types)
final streams = webhookIds.map((id) =>
  reactiveClient.startWorkflow(id, data)
).toList();

Rx.combineLatest<WorkflowExecution, List<WorkflowExecution>>(
  streams,
  (values) => values,
);
```

---

## Migration Checklist

- [ ] Update `pubspec.yaml` with `rxdart` dependency
- [ ] Create `ReactiveN8nClient` instance
- [ ] Migrate simple workflow starts (Phase 2)
- [ ] Migrate polling logic (Phase 3)
- [ ] Migrate state management (Phase 4)
- [ ] Migrate error handling (Phase 5)
- [ ] Update tests to handle streams
- [ ] Add stream error handlers everywhere
- [ ] Implement proper disposal patterns
- [ ] Remove legacy `N8nClient` usage
- [ ] Update documentation
- [ ] Performance testing
- [ ] Production deployment

---

## Next Steps

1. **Read the [RxDart Patterns Guide](RXDART_PATTERNS_GUIDE.md)** for best practices
2. **Explore examples** in `example/reactive/`
3. **Review API docs** at [pub.dev/documentation/n8n_dart](https://pub.dev/documentation/n8n_dart/latest/)
4. **Join discussions** at [GitHub Discussions](https://github.com/yourusername/n8n_dart/discussions)

---

**Questions? Issues?** Open an issue at [GitHub Issues](https://github.com/yourusername/n8n_dart/issues)
