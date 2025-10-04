# RxDart Patterns Guide

**Best practices and design patterns for reactive n8n_dart**

## Table of Contents

1. [Introduction](#introduction)
2. [Core Reactive Concepts](#core-reactive-concepts)
3. [Essential Patterns](#essential-patterns)
4. [Advanced Patterns](#advanced-patterns)
5. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)
6. [Performance Optimization](#performance-optimization)
7. [Testing Reactive Code](#testing-reactive-code)

---

## Introduction

This guide covers **production-ready reactive patterns** using RxDart in n8n_dart. All patterns have been battle-tested and follow functional reactive programming (FRP) best practices.

### When to Use Which Pattern?

| Use Case | Pattern | Complexity |
|----------|---------|------------|
| Single async operation | `Stream.fromFuture()` | ⭐ Easy |
| Repeated polling | `Stream.periodic()` + operators | ⭐⭐ Medium |
| State management | `BehaviorSubject` | ⭐⭐ Medium |
| Event broadcasting | `PublishSubject` | ⭐⭐ Medium |
| Multiple parallel operations | `combineLatest`, `forkJoin` | ⭐⭐⭐ Advanced |
| Sequential operations | `concatMap`, `asyncExpand` | ⭐⭐⭐ Advanced |
| Error recovery | `retryWhen`, `onErrorReturnWith` | ⭐⭐⭐ Advanced |
| Performance optimization | `shareReplay`, `publish` | ⭐⭐⭐⭐ Expert |

---

## Core Reactive Concepts

### Streams vs Futures

**Future:** Single value, one-time execution
**Stream:** Multiple values over time

```dart
// Future: Returns ONE execution ID
Future<String> startWorkflow() async {
  return await client.startWorkflow('webhook', data);
}

// Stream: Emits execution updates over time
Stream<WorkflowExecution> watchWorkflow() {
  return client.pollExecutionStatus(executionId);
}
```

### Hot vs Cold Streams

**Cold Stream:** Starts producing values when subscribed
**Hot Stream:** Produces values regardless of subscribers

```dart
// COLD: Creates new HTTP request for each subscriber
final coldStream = Stream.fromFuture(
  httpClient.get('https://api.example.com/data')
);

coldStream.listen((_) {});  // HTTP request 1
coldStream.listen((_) {});  // HTTP request 2 (different request!)

// HOT: Shares single HTTP request among all subscribers
final hotStream = Stream.fromFuture(
  httpClient.get('https://api.example.com/data')
).shareReplay(maxSize: 1);

hotStream.listen((_) {});  // HTTP request 1
hotStream.listen((_) {});  // Reuses request 1 (cached!)
```

### BehaviorSubject vs PublishSubject

```dart
// BehaviorSubject: Remembers last value, emits immediately to new subscribers
final behaviorSubject = BehaviorSubject<int>.seeded(0);
behaviorSubject.add(1);
behaviorSubject.add(2);

behaviorSubject.listen(print);  // Immediately prints: 2 (current value)

// PublishSubject: No memory, only emits future values
final publishSubject = PublishSubject<int>();
publishSubject.add(1);
publishSubject.add(2);

publishSubject.listen(print);  // Prints nothing (missed previous values)
publishSubject.add(3);          // Prints: 3
```

**Use BehaviorSubject for:**
- Application state (current executions, config, connection status)
- Cache (last known value)
- UI state synchronization

**Use PublishSubject for:**
- Events (workflow started, completed, error occurred)
- Notifications
- Command/action buses

---

## Essential Patterns

### Pattern 1: Reactive State Management

**Use Case:** Track application state reactively

```dart
class ReactiveExecutionManager {
  final ReactiveN8nClient _client;

  // State subject - remembers current executions
  final BehaviorSubject<Map<String, WorkflowExecution>> _executions$ =
      BehaviorSubject.seeded({});

  ReactiveExecutionManager(this._client);

  /// Stream of all executions
  Stream<Map<String, WorkflowExecution>> get executions$ =>
      _executions$.stream;

  /// Stream of active (running) executions only
  Stream<List<WorkflowExecution>> get activeExecutions$ =>
      _executions$.stream.map((executions) =>
        executions.values
            .where((e) => !e.isFinished)
            .toList()
      );

  /// Stream of execution count
  Stream<int> get executionCount$ =>
      _executions$.stream.map((executions) => executions.length);

  /// Add execution to state
  void addExecution(WorkflowExecution execution) {
    final current = _executions$.value;
    final updated = Map<String, WorkflowExecution>.from(current);
    updated[execution.id] = execution;
    _executions$.add(updated);
  }

  /// Remove execution from state
  void removeExecution(String executionId) {
    final current = _executions$.value;
    final updated = Map<String, WorkflowExecution>.from(current);
    updated.remove(executionId);
    _executions$.add(updated);
  }

  /// Update execution in state
  void updateExecution(WorkflowExecution execution) {
    addExecution(execution);  // Same as add
  }

  void dispose() {
    _executions$.close();
  }
}
```

**Benefits:**
- ✅ Single source of truth
- ✅ Automatic UI updates
- ✅ Derived streams (activeExecutions$, executionCount$)
- ✅ Immutable state updates

### Pattern 2: Event-Driven Architecture

**Use Case:** React to workflow lifecycle events

```dart
class WorkflowEventHandler {
  final ReactiveN8nClient _client;
  final List<StreamSubscription> _subscriptions = [];

  WorkflowEventHandler(this._client) {
    _setupEventHandlers();
  }

  void _setupEventHandlers() {
    // Handle workflow started events
    _subscriptions.add(
      _client.workflowStarted$.listen((event) {
        _logEvent('Workflow ${event.executionId} started at ${event.timestamp}');
        _notifyUser('Workflow started');
      })
    );

    // Handle workflow completed events
    _subscriptions.add(
      _client.workflowCompleted$.listen((event) {
        _logEvent('Workflow ${event.executionId} completed: ${event.status}');
        _notifyUser('Workflow completed');
        _cleanupResources(event.executionId);
      })
    );

    // Handle workflow error events
    _subscriptions.add(
      _client.workflowErrors$.listen((event) {
        _logError('Workflow ${event.executionId} error', event.error);
        _notifyUser('Workflow failed');
        _triggerRecovery(event.executionId, event.error);
      })
    );

    // Handle all events with pattern matching
    _subscriptions.add(
      _client.workflowEvents$.listen((event) {
        if (event is WorkflowStartedEvent) {
          // Handle start
        } else if (event is WorkflowCompletedEvent) {
          // Handle completion
        } else if (event is WorkflowErrorEvent) {
          // Handle error
        } else if (event is WorkflowResumedEvent) {
          // Handle resume
        } else if (event is WorkflowCancelledEvent) {
          // Handle cancellation
        }
      })
    );
  }

  void _logEvent(String message) => print('[EVENT] $message');
  void _logError(String message, N8nException error) =>
      print('[ERROR] $message: $error');
  void _notifyUser(String message) => print('[NOTIFY] $message');
  void _cleanupResources(String executionId) =>
      print('[CLEANUP] $executionId');
  void _triggerRecovery(String executionId, N8nException error) =>
      print('[RECOVERY] $executionId');

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
```

**Benefits:**
- ✅ Decoupled event handling
- ✅ Easy to add new handlers
- ✅ Centralized event processing
- ✅ Automatic cleanup

### Pattern 3: Smart Polling with Auto-Stop

**Use Case:** Poll execution status until completion

```dart
/// Poll execution with automatic completion detection
Stream<WorkflowExecution> smartPoll(String executionId) {
  return Stream.periodic(Duration(seconds: 2))
      .startWith(null)  // Emit immediately
      .asyncMap((_) => _client.getExecutionStatus(executionId))
      .distinctUntilChanged((prev, next) =>
          prev.status == next.status &&
          prev.finishedAt == next.finishedAt
      )  // Filter duplicates
      .takeWhile((execution) => !execution.finished)  // Auto-stop
      .doOnData((execution) {
        print('Status: ${execution.status}');
      })
      .doOnDone(() {
        print('Polling complete');
      });
}
```

**Benefits:**
- ✅ Automatic polling stop
- ✅ Duplicate filtering
- ✅ Immediate first emission
- ✅ Side effects with `doOnData`

### Pattern 4: Adaptive Polling Intervals

**Use Case:** Adjust polling speed based on execution status

```dart
/// Poll with interval that adapts to execution status
Stream<WorkflowExecution> adaptivePoll(String executionId) {
  // Start with base interval
  final baseInterval = Duration(seconds: 2);

  return Stream.periodic(baseInterval)
      .startWith(null)
      .asyncMap((_) => _client.getExecutionStatus(executionId))
      .switchMap((execution) {
        // Determine adaptive interval based on status
        final interval = _getAdaptiveInterval(execution.status);

        if (interval != baseInterval) {
          // Switch to new polling stream with different interval
          return Stream.periodic(interval)
              .startWith(null)
              .asyncMap((_) => _client.getExecutionStatus(executionId))
              .takeWhile((e) => !e.finished);
        }

        return Stream.value(execution);
      })
      .takeWhile((execution) => !execution.finished)
      .distinct((execution) => execution.status);
}

Duration _getAdaptiveInterval(WorkflowStatus status) {
  switch (status) {
    case WorkflowStatus.running:
      return Duration(seconds: 2);  // Fast polling
    case WorkflowStatus.waiting:
      return Duration(seconds: 10); // Slow polling
    case WorkflowStatus.error:
      return Duration(seconds: 5);  // Medium polling
    default:
      return Duration(seconds: 2);
  }
}
```

**Benefits:**
- ✅ Efficient resource usage
- ✅ Responsive for active executions
- ✅ Battery-friendly for waiting states
- ✅ Automatic interval switching

### Pattern 5: Error Recovery with Retry

**Use Case:** Automatically retry on transient errors

```dart
/// Execute with automatic retry and exponential backoff
Stream<T> withSmartRetry<T>(
  Stream<T> stream, {
  int maxRetries = 3,
  Duration initialDelay = const Duration(seconds: 1),
  Duration maxDelay = const Duration(seconds: 30),
}) {
  return stream.retryWhen((errors, stackTraces) {
    return errors.zipWith<StackTrace, MapEntry<dynamic, StackTrace>>(
      stackTraces,
      (error, stackTrace) => MapEntry(error, stackTrace),
    ).asyncExpand((errorEntry) {
      final error = errorEntry.key;
      final stackTrace = errorEntry.value;

      // Only retry network errors
      if (error is N8nException && error.isNetworkError) {
        final retryCount = error.retryCount ?? 0;

        if (retryCount >= maxRetries) {
          // Max retries exceeded
          return Stream.error(error, stackTrace);
        }

        // Calculate exponential backoff delay
        final delay = Duration(
          milliseconds: (initialDelay.inMilliseconds *
              (1 << retryCount)).clamp(
                initialDelay.inMilliseconds,
                maxDelay.inMilliseconds,
              ),
        );

        print('Retry ${retryCount + 1}/$maxRetries after ${delay.inSeconds}s');

        // Emit after delay to trigger retry
        return Stream.value(null).delay(delay);
      }

      // Don't retry other errors
      return Stream.error(error, stackTrace);
    });
  });
}

// Usage
withSmartRetry(
  _client.startWorkflow('webhook', data),
  maxRetries: 5,
).listen(
  (execution) => print('Success: ${execution.id}'),
  onError: (error) => print('Failed after retries: $error'),
);
```

**Benefits:**
- ✅ Automatic retry for transient errors
- ✅ Exponential backoff prevents server overload
- ✅ Configurable retry limits
- ✅ Only retries appropriate errors

---

## Advanced Patterns

### Pattern 6: Parallel Execution with combineLatest

**Use Case:** Start multiple workflows and wait for all to update

```dart
/// Watch multiple executions in parallel
Stream<List<WorkflowExecution>> watchAll(List<String> executionIds) {
  if (executionIds.isEmpty) {
    return Stream.value([]);
  }

  final streams = executionIds.map((id) =>
    _client.pollExecutionStatus(id)
  ).toList();

  // Combine all streams - emits when ANY execution updates
  return Rx.combineLatest<WorkflowExecution, List<WorkflowExecution>>(
    streams,
    (values) => values,
  );
}

// Usage
watchAll(['exec-1', 'exec-2', 'exec-3']).listen((executions) {
  final allFinished = executions.every((e) => e.isFinished);
  print('Progress: ${executions.where((e) => e.isFinished).length}/${executions.length}');

  if (allFinished) {
    print('All executions completed!');
  }
});
```

**Benefits:**
- ✅ Real-time updates for all executions
- ✅ Emits on any status change
- ✅ Easy progress tracking
- ✅ Type-safe results

### Pattern 7: Sequential Execution with concatMap

**Use Case:** Execute workflows one after another

```dart
/// Execute workflows sequentially (wait for each to complete)
Stream<WorkflowExecution> runSequential(
  List<MapEntry<String, Map<String, dynamic>>> workflows,
) {
  return Stream.fromIterable(workflows)
      .concatMap((workflow) {
        final webhookId = workflow.key;
        final data = workflow.value;

        // Start workflow
        return _client.startWorkflow(webhookId, data)
            .flatMap((execution) {
              // Wait for completion before starting next
              return _client.pollExecutionStatus(execution.id)
                  .lastWhere((e) => e.isFinished);
            });
      });
}

// Usage
runSequential([
  MapEntry('webhook-1', {'step': 1}),
  MapEntry('webhook-2', {'step': 2}),
  MapEntry('webhook-3', {'step': 3}),
]).listen(
  (execution) => print('Completed: ${execution.id}'),
  onDone: () => print('All workflows completed sequentially'),
);
```

**Benefits:**
- ✅ Guaranteed execution order
- ✅ Each workflow completes before next starts
- ✅ Easy error isolation
- ✅ Predictable timing

### Pattern 8: Race Condition (First Wins)

**Use Case:** Start multiple workflows, use result from fastest

```dart
/// Race multiple workflows - first to complete wins
Stream<WorkflowExecution> raceWorkflows(
  List<String> webhookIds,
  Map<String, dynamic> data,
) {
  final streams = webhookIds.map((id) =>
    _client.startWorkflow(id, data)
        .flatMap((execution) =>
          _client.pollExecutionStatus(execution.id)
              .firstWhere((e) => e.isFinished)
        )
  ).toList();

  // First stream to emit wins, others are cancelled
  return Rx.race(streams);
}

// Usage
raceWorkflows(['fast-webhook', 'slow-webhook'], data).listen((execution) {
  print('Winner: ${execution.id} - Completed first!');
});
```

**Benefits:**
- ✅ Use fastest available service
- ✅ Automatic cancellation of losers
- ✅ Redundancy for reliability
- ✅ Performance optimization

### Pattern 9: Batch Processing with forkJoin

**Use Case:** Start all workflows in parallel, wait for all to complete

```dart
/// Batch start workflows and wait for all to complete
Stream<List<WorkflowExecution>> batchExecute(
  List<MapEntry<String, Map<String, dynamic>>> workflows,
) {
  final streams = workflows.map((workflow) {
    final webhookId = workflow.key;
    final data = workflow.value;

    return _client.startWorkflow(webhookId, data)
        .flatMap((execution) =>
          _client.pollExecutionStatus(execution.id)
              .lastWhere((e) => e.isFinished)
        );
  }).toList();

  // Wait for ALL streams to complete
  return Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(streams);
}

// Usage
batchExecute([
  MapEntry('webhook-1', {'batch': 1}),
  MapEntry('webhook-2', {'batch': 2}),
  MapEntry('webhook-3', {'batch': 3}),
]).listen((executions) {
  print('All ${executions.length} workflows completed!');
  final successCount = executions.where((e) => e.status == WorkflowStatus.success).length;
  print('Success rate: $successCount/${executions.length}');
});
```

**Benefits:**
- ✅ Maximum parallelization
- ✅ Single emission with all results
- ✅ Waits for slowest execution
- ✅ Perfect for batch operations

### Pattern 10: Throttled Execution (Rate Limiting)

**Use Case:** Limit workflow execution rate to prevent server overload

```dart
/// Throttle workflow execution to max 1 per second
Stream<WorkflowExecution> throttledExecute(
  Stream<Map<String, dynamic>> dataStream,
  String webhookId,
) {
  return dataStream
      .throttleTime(Duration(seconds: 1))  // Max 1 emission per second
      .flatMap((data) => _client.startWorkflow(webhookId, data));
}

// Usage
final rapidDataStream = Stream.periodic(
  Duration(milliseconds: 100),
  (i) => {'request': i},
).take(20);

throttledExecute(rapidDataStream, 'webhook-123').listen((execution) {
  print('Started: ${execution.id}');  // Max 1 per second!
});
```

**Benefits:**
- ✅ Prevents server overload
- ✅ Respects API rate limits
- ✅ Automatic queuing
- ✅ Configurable throttle duration

### Pattern 11: Debounced Input Validation

**Use Case:** Validate user input only after they stop typing

```dart
/// Debounce form input validation
class FormValidator {
  final _input$ = PublishSubject<String>();

  Stream<ValidationResult> get validationResults$ =>
      _input$.stream
          .debounceTime(Duration(milliseconds: 300))  // Wait 300ms after typing stops
          .distinct()  // Skip duplicate values
          .map((input) => _validateInput(input));

  void onInputChanged(String value) {
    _input$.add(value);
  }

  ValidationResult _validateInput(String input) {
    if (input.isEmpty) {
      return ValidationResult.error('Input cannot be empty');
    }
    if (input.length < 3) {
      return ValidationResult.error('Input must be at least 3 characters');
    }
    return ValidationResult.success(input);
  }

  void dispose() {
    _input$.close();
  }
}

// Usage
final validator = FormValidator();

validator.validationResults$.listen((result) {
  if (result.isValid) {
    print('✓ Valid input: ${result.value}');
  } else {
    print('✗ Error: ${result.errors.join(', ')}');
  }
});

// Simulate rapid typing
validator.onInputChanged('a');    // Ignored
validator.onInputChanged('ab');   // Ignored
validator.onInputChanged('abc');  // Validated after 300ms!
```

**Benefits:**
- ✅ Reduces validation calls
- ✅ Better UX (no validation while typing)
- ✅ Resource efficient
- ✅ Automatic duplicate filtering

### Pattern 12: Stream Caching with shareReplay

**Use Case:** Share expensive operations among multiple subscribers

```dart
class CachedWorkflowService {
  final ReactiveN8nClient _client;
  final Map<String, Stream<WorkflowExecution>> _cache = {};

  CachedWorkflowService(this._client);

  /// Get execution with caching
  Stream<WorkflowExecution> getExecution(String executionId) {
    // Return cached stream if exists
    if (_cache.containsKey(executionId)) {
      return _cache[executionId]!;
    }

    // Create new stream with caching
    final stream = _client.pollExecutionStatus(executionId)
        .shareReplay(maxSize: 1);  // Cache last emission

    _cache[executionId] = stream;
    return stream;
  }

  /// Invalidate cache
  void invalidate(String executionId) {
    _cache.remove(executionId);
  }

  void dispose() {
    _cache.clear();
  }
}

// Usage
final service = CachedWorkflowService(client);

// Multiple subscribers share same HTTP calls!
service.getExecution('exec-123').listen((e) => print('Subscriber 1: $e'));
service.getExecution('exec-123').listen((e) => print('Subscriber 2: $e'));
service.getExecution('exec-123').listen((e) => print('Subscriber 3: $e'));
// Only ONE HTTP request made!
```

**Benefits:**
- ✅ Reduces HTTP calls
- ✅ Shares results among subscribers
- ✅ Automatic replay for late subscribers
- ✅ Configurable cache size

---

## Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Not Disposing Subscriptions

**Problem:**
```dart
class BadService {
  void watchExecution(String id) {
    // WRONG: Subscription never cancelled!
    client.pollExecutionStatus(id).listen((execution) {
      print(execution.status);
    });
  }
}
```

**Solution:**
```dart
class GoodService {
  final List<StreamSubscription> _subscriptions = [];

  void watchExecution(String id) {
    // RIGHT: Track subscription for cleanup
    final sub = client.pollExecutionStatus(id).listen((execution) {
      print(execution.status);
    });
    _subscriptions.add(sub);
  }

  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
```

### ❌ Anti-Pattern 2: Nested subscriptions (Callback Hell)

**Problem:**
```dart
// WRONG: Nested subscriptions are hard to read and manage
client.startWorkflow('webhook', data).listen((execution1) {
  client.pollExecutionStatus(execution1.id).listen((status1) {
    client.startWorkflow('webhook-2', data).listen((execution2) {
      client.pollExecutionStatus(execution2.id).listen((status2) {
        // Callback hell!
      });
    });
  });
});
```

**Solution:**
```dart
// RIGHT: Flatten with flatMap/concatMap
client.startWorkflow('webhook', data)
    .flatMap((execution1) =>
      client.pollExecutionStatus(execution1.id)
          .lastWhere((e) => e.isFinished)
    )
    .flatMap((status1) =>
      client.startWorkflow('webhook-2', data)
    )
    .flatMap((execution2) =>
      client.pollExecutionStatus(execution2.id)
          .lastWhere((e) => e.isFinished)
    )
    .listen((finalStatus) {
      print('All done: ${finalStatus.status}');
    });
```

### ❌ Anti-Pattern 3: Synchronous Operations in asyncMap

**Problem:**
```dart
// WRONG: Blocking operation in asyncMap
stream.asyncMap((data) {
  final result = expensiveOperation(data);  // Blocks!
  return result;
});
```

**Solution:**
```dart
// RIGHT: Use async function
stream.asyncMap((data) async {
  final result = await expensiveOperationAsync(data);
  return result;
});

// OR use map for synchronous operations
stream.map((data) => expensiveOperation(data));
```

### ❌ Anti-Pattern 4: Not Handling Errors

**Problem:**
```dart
// WRONG: Unhandled errors crash the app
client.startWorkflow('webhook', data).listen((execution) {
  print(execution.id);
});  // Error crashes app!
```

**Solution:**
```dart
// RIGHT: Always handle errors
client.startWorkflow('webhook', data).listen(
  (execution) => print(execution.id),
  onError: (error) => print('Error: $error'),
  onDone: () => print('Complete'),
);

// OR use stream operators
client.startWorkflow('webhook', data)
    .handleError((error) {
      print('Handled: $error');
    })
    .listen((execution) => print(execution.id));
```

### ❌ Anti-Pattern 5: Creating New Streams in UI

**Problem:**
```dart
// WRONG: Creates new stream on every build (Flutter)
Widget build(BuildContext context) {
  return StreamBuilder(
    stream: client.pollExecutionStatus(executionId),  // New stream each build!
    builder: (context, snapshot) { },
  );
}
```

**Solution:**
```dart
// RIGHT: Create stream once in initState
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final Stream<WorkflowExecution> _executionStream;

  @override
  void initState() {
    super.initState();
    _executionStream = client.pollExecutionStatus(executionId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _executionStream,  // Reuse same stream
      builder: (context, snapshot) { },
    );
  }
}
```

---

## Performance Optimization

### Optimization 1: Use shareReplay for Expensive Operations

```dart
// Expensive operation (HTTP call, computation, etc.)
final expensiveStream = Stream.fromFuture(expensiveOperation())
    .shareReplay(maxSize: 1);  // Cache result for all subscribers

// Multiple subscribers share result
expensiveStream.listen((_) {});  // Executes operation
expensiveStream.listen((_) {});  // Reuses cached result
expensiveStream.listen((_) {});  // Reuses cached result
```

### Optimization 2: Dispose Subjects to Prevent Memory Leaks

```dart
class MyService {
  final _subject = BehaviorSubject<int>();

  void dispose() {
    _subject.close();  // CRITICAL: Prevents memory leak
  }
}
```

### Optimization 3: Use distinct to Skip Duplicate Emissions

```dart
// Skip duplicate status updates
client.pollExecutionStatus(executionId)
    .distinct((execution) => execution.status)  // Only emit on status change
    .listen((execution) {
      print('Status changed to: ${execution.status}');
    });
```

### Optimization 4: Batch Operations with Buffer

```dart
// Batch workflow starts into groups of 10
dataStream
    .bufferCount(10)  // Collect 10 items
    .map((batch) {
      // Process batch
      return batch.map((data) => client.startWorkflow('webhook', data));
    });
```

---

## Testing Reactive Code

### Test Pattern 1: Testing Stream Emissions

```dart
test('should emit execution status updates', () async {
  final stream = client.pollExecutionStatus('exec-123');

  await expectLater(
    stream,
    emitsInOrder([
      predicate<WorkflowExecution>((e) => e.status == WorkflowStatus.running),
      predicate<WorkflowExecution>((e) => e.status == WorkflowStatus.success),
      emitsDone,
    ]),
  );
});
```

### Test Pattern 2: Testing Error Handling

```dart
test('should emit error on failure', () async {
  final stream = client.startWorkflow('invalid-webhook', {});

  await expectLater(
    stream,
    emitsError(isA<N8nException>()),
  );
});
```

### Test Pattern 3: Testing Subjects

```dart
test('BehaviorSubject should emit current value to new subscribers', () async {
  final subject = BehaviorSubject<int>.seeded(0);
  subject.add(1);
  subject.add(2);

  await expectLater(subject.stream, emits(2));  // Current value
});
```

### Test Pattern 4: Testing Stream Completion

```dart
test('should complete when execution finishes', () async {
  final stream = client.pollExecutionStatus('exec-123');

  await expectLater(
    stream.last,
    completion(predicate<WorkflowExecution>((e) => e.isFinished)),
  );
});
```

---

## Best Practices Summary

### DO ✅

- ✅ Use `BehaviorSubject` for state
- ✅ Use `PublishSubject` for events
- ✅ Use `shareReplay` for expensive operations
- ✅ Always dispose subscriptions and subjects
- ✅ Handle errors with `onError` or stream operators
- ✅ Use `distinctUntilChanged` to filter duplicates
- ✅ Use `takeWhile` for auto-stopping streams
- ✅ Flatten nested streams with `flatMap`/`concatMap`
- ✅ Test stream emissions and errors
- ✅ Use async/await with `.first` when appropriate

### DON'T ❌

- ❌ Forget to dispose subjects
- ❌ Nest subscriptions (callback hell)
- ❌ Create new streams in UI build methods
- ❌ Ignore errors (always handle them!)
- ❌ Use synchronous operations in `asyncMap`
- ❌ Subscribe to cold streams multiple times for same operation
- ❌ Hardcode retry/polling values (use config)
- ❌ Mix state and events in same subject
- ❌ Use `.listen()` when operators would be cleaner
- ❌ Block the stream with heavy computation

---

## Next Steps

1. **Practice** - Implement these patterns in your project
2. **Experiment** - Try different operator combinations
3. **Read** - [RxDart API docs](https://pub.dev/documentation/rxdart/latest/)
4. **Explore** - Check out `example/reactive/` for more examples
5. **Contribute** - Share your patterns at [GitHub Discussions](https://github.com/yourusername/n8n_dart/discussions)

---

**Questions?** Open an issue at [GitHub Issues](https://github.com/yourusername/n8n_dart/issues)
