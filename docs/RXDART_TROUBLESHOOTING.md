# RxDart Troubleshooting Guide

**Solutions to common issues when using reactive n8n_dart**

## Table of Contents

1. [Stream Subscription Errors](#stream-subscription-errors)
2. [Memory Leaks](#memory-leaks)
3. [Stream Completion Issues](#stream-completion-issues)
4. [Error Handling Problems](#error-handling-problems)
5. [Performance Issues](#performance-issues)
6. [Type Errors](#type-errors)
7. [Testing Problems](#testing-problems)
8. [Flutter-Specific Issues](#flutter-specific-issues)

---

## Stream Subscription Errors

### Error: "Bad state: Stream has already been listened to"

**Symptoms:**
```dart
final stream = client.startWorkflow('webhook', data);
stream.listen((_) {});  // OK
stream.listen((_) {});  // ERROR: Stream has already been listened to
```

**Cause:** Trying to subscribe to a single-subscription stream multiple times.

**Solution 1: Use `shareReplay()`**
```dart
final stream = client.startWorkflow('webhook', data)
    .shareReplay(maxSize: 1);  // Makes stream hot (broadcast)

stream.listen((_) {});  // OK
stream.listen((_) {});  // OK - shared subscription
```

**Solution 2: Use `asBroadcastStream()`**
```dart
final stream = client.startWorkflow('webhook', data)
    .asBroadcastStream();

stream.listen((_) {});  // OK
stream.listen((_) {});  // OK
```

**Solution 3: Create stream once and reuse**
```dart
class MyService {
  late final Stream<WorkflowExecution> _workflowStream;

  MyService() {
    _workflowStream = client.startWorkflow('webhook', data)
        .shareReplay(maxSize: 1);
  }

  Stream<WorkflowExecution> get workflowStream => _workflowStream;
}
```

**When to use which?**
- `shareReplay()` - When you want to cache last N emissions (recommended)
- `asBroadcastStream()` - When you don't need caching
- Create once - When stream is created at initialization

---

### Error: "Bad state: Cannot add new events after calling close"

**Symptoms:**
```dart
final subject = PublishSubject<int>();
subject.close();
subject.add(1);  // ERROR: Cannot add new events after calling close
```

**Cause:** Trying to add events to a closed subject.

**Solution 1: Check if closed before adding**
```dart
final subject = PublishSubject<int>();

void addValue(int value) {
  if (!subject.isClosed) {
    subject.add(value);
  }
}

void dispose() {
  subject.close();
}
```

**Solution 2: Use null safety**
```dart
class MyService {
  PublishSubject<int>? _subject;

  MyService() {
    _subject = PublishSubject<int>();
  }

  void addValue(int value) {
    _subject?.add(value);  // Safe - won't error if null
  }

  void dispose() {
    _subject?.close();
    _subject = null;  // Mark as disposed
  }
}
```

---

## Memory Leaks

### Issue: Subscriptions not cancelled

**Symptoms:**
- App memory usage grows over time
- Old callbacks still executing
- Performance degradation

**Diagnosis:**
```dart
// BAD - subscription never cancelled
class BadService {
  void startMonitoring() {
    client.workflowEvents$.listen((event) {
      print(event);  // This will keep running forever!
    });
  }
}
```

**Solution: Track and cancel subscriptions**
```dart
// GOOD - proper cleanup
class GoodService {
  final List<StreamSubscription> _subscriptions = [];

  void startMonitoring() {
    final sub = client.workflowEvents$.listen((event) {
      print(event);
    });
    _subscriptions.add(sub);  // Track subscription
  }

  void dispose() {
    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
```

**Alternative: Use `takeUntil()` operator**
```dart
class SmartService {
  final _disposed$ = PublishSubject<void>();

  void startMonitoring() {
    client.workflowEvents$
        .takeUntil(_disposed$)  // Auto-cancels when disposed
        .listen((event) {
          print(event);
        });
  }

  void dispose() {
    _disposed$.add(null);  // Triggers takeUntil
    _disposed$.close();
  }
}
```

---

### Issue: Subjects not closed

**Symptoms:**
- Memory leaks
- Dart analyzer warnings
- Resources not released

**Diagnosis:**
```dart
// BAD - subject never closed
class BadManager {
  final _state$ = BehaviorSubject<int>.seeded(0);
  // Missing dispose()!
}
```

**Solution: Always close subjects**
```dart
// GOOD - proper disposal
class GoodManager {
  final _state$ = BehaviorSubject<int>.seeded(0);

  Stream<int> get state$ => _state$.stream;

  void dispose() {
    _state$.close();  // CRITICAL: Prevents memory leak
  }
}
```

**Checklist for disposal:**
```dart
class CompleteService {
  // Track all disposable resources
  final _subject1 = BehaviorSubject<int>();
  final _subject2 = PublishSubject<String>();
  final _subscriptions = <StreamSubscription>[];
  final ReactiveN8nClient _client;

  void dispose() {
    // 1. Cancel all subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    // 2. Close all subjects
    _subject1.close();
    _subject2.close();

    // 3. Dispose client
    _client.dispose();

    // 4. (Optional) Set references to null
    // This helps garbage collection
  }
}
```

---

## Stream Completion Issues

### Issue: Stream never completes

**Symptoms:**
- `onDone` callback never called
- `await stream.last` hangs forever
- Infinite polling

**Diagnosis:**
```dart
// Stream that never completes
client.pollExecutionStatus(executionId).listen(
  (execution) => print(execution.status),
  onDone: () => print('Never printed!'),
);
```

**Cause 1: Missing `takeWhile` condition**
```dart
// BAD - polls forever
Stream.periodic(Duration(seconds: 2))
    .asyncMap((_) => client.getExecutionStatus(id))
    .listen((_) {});  // Never stops!

// GOOD - stops when finished
Stream.periodic(Duration(seconds: 2))
    .asyncMap((_) => client.getExecutionStatus(id))
    .takeWhile((execution) => !execution.finished)  // Auto-stops
    .listen((_) {});
```

**Cause 2: Infinite subject stream**
```dart
// BehaviorSubject/PublishSubject streams never complete naturally
final subject = BehaviorSubject<int>();
subject.stream.listen(
  (_) {},
  onDone: () => print('Never called unless subject.close()'),
);

// Must explicitly close
subject.close();  // Now onDone will be called
```

**Solution: Add timeout for safety**
```dart
client.pollExecutionStatus(executionId)
    .timeout(
      Duration(minutes: 30),
      onTimeout: (sink) {
        sink.addError(TimeoutException('Polling timeout after 30 minutes'));
        sink.close();
      },
    )
    .listen(
      (_) {},
      onDone: () => print('Complete or timed out'),
    );
```

---

### Issue: Stream completes too early

**Symptoms:**
- Missing expected emissions
- `onDone` called prematurely
- Data loss

**Diagnosis:**
```dart
// Stream completes before all data emitted
client.pollExecutionStatus(executionId).listen(
  (execution) => print(execution.status),  // Only prints once!
  onDone: () => print('Done too early'),
);
```

**Cause: Using `first` or `take(1)` unintentionally**
```dart
// BAD - completes after first emission
client.pollExecutionStatus(id)
    .first  // Only takes first value then completes
    .then((execution) => print(execution));

// GOOD - takes all until finished
client.pollExecutionStatus(id)
    .listen((execution) => print(execution));
```

**Cause: Incorrect `takeWhile` condition**
```dart
// BAD - stops too early
stream.takeWhile((execution) => execution.status == WorkflowStatus.running)
    .listen((_) {});  // Stops as soon as status != running

// GOOD - continues until finished
stream.takeWhile((execution) => !execution.finished)
    .listen((_) {});
```

---

## Error Handling Problems

### Issue: Unhandled stream errors crash app

**Symptoms:**
- App crashes with uncaught exception
- No error message shown to user
- Dart unhandled exception errors

**Diagnosis:**
```dart
// BAD - no error handling
client.startWorkflow('webhook', data).listen((execution) {
  print(execution.id);
});  // If error occurs, app crashes!
```

**Solution 1: Add onError callback**
```dart
// GOOD - errors handled
client.startWorkflow('webhook', data).listen(
  (execution) => print('Success: ${execution.id}'),
  onError: (error) => print('Error: $error'),  // Handle errors
);
```

**Solution 2: Use stream operators**
```dart
// GOOD - errors handled in stream
client.startWorkflow('webhook', data)
    .handleError((error) {
      print('Error: $error');
      // Log error, show user message, etc.
    })
    .listen((execution) => print('Success: ${execution.id}'));
```

**Solution 3: Use onErrorReturnWith for fallback**
```dart
// GOOD - provide fallback value
client.startWorkflow('webhook', data)
    .onErrorReturnWith((error, stackTrace) {
      print('Error: $error');
      return WorkflowExecution(
        id: 'fallback',
        status: WorkflowStatus.error,
        finished: true,
        data: {'error': error.toString()},
      );
    })
    .listen((execution) {
      if (execution.id == 'fallback') {
        print('Using fallback due to error');
      }
    });
```

---

### Issue: Errors not propagating through stream chain

**Symptoms:**
- Error thrown but never caught
- Silent failures
- Missing error callbacks

**Diagnosis:**
```dart
// Error thrown in asyncMap but not caught
client.pollExecutionStatus(id)
    .asyncMap((execution) {
      if (execution.status == WorkflowStatus.error) {
        throw Exception('Workflow failed');  // Where does this go?
      }
      return execution;
    })
    .listen((execution) => print(execution));
```

**Solution: Add error handling at subscription**
```dart
client.pollExecutionStatus(id)
    .asyncMap((execution) {
      if (execution.status == WorkflowStatus.error) {
        throw Exception('Workflow failed');
      }
      return execution;
    })
    .listen(
      (execution) => print('Success: $execution'),
      onError: (error) => print('Caught error: $error'),  // Catches asyncMap error
    );
```

**Alternative: Handle errors in operators**
```dart
client.pollExecutionStatus(id)
    .asyncMap((execution) {
      if (execution.status == WorkflowStatus.error) {
        throw Exception('Workflow failed');
      }
      return execution;
    })
    .onErrorResume((error) {
      // Recover from error
      return Stream.value(fallbackExecution);
    })
    .listen((execution) => print(execution));
```

---

## Performance Issues

### Issue: Too many HTTP requests

**Symptoms:**
- High network traffic
- Server rate limiting
- Slow performance

**Diagnosis:**
```dart
// BAD - new HTTP request for each subscriber
Widget build(BuildContext context) {
  return StreamBuilder(
    stream: client.pollExecutionStatus(executionId),  // New poll each build!
    builder: (context, snapshot) {
      return Text('Status: ${snapshot.data?.status}');
    },
  );
}
```

**Solution: Use shareReplay to cache**
```dart
// GOOD - single HTTP request shared
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final Stream<WorkflowExecution> _executionStream;

  @override
  void initState() {
    super.initState();
    _executionStream = client.pollExecutionStatus(executionId)
        .shareReplay(maxSize: 1);  // Cache and share
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _executionStream,  // Reuses cached stream
      builder: (context, snapshot) {
        return Text('Status: ${snapshot.data?.status}');
      },
    );
  }
}
```

---

### Issue: Stream emissions too frequent

**Symptoms:**
- UI updates too rapidly
- High CPU usage
- Battery drain

**Solution: Use throttleTime or debounceTime**
```dart
// Throttle - emit at most once per interval
client.workflowEvents$
    .throttleTime(Duration(milliseconds: 500))  // Max 2/second
    .listen((event) => updateUI(event));

// Debounce - emit only after quiet period
client.workflowEvents$
    .debounceTime(Duration(milliseconds: 300))  // Wait 300ms after last event
    .listen((event) => updateUI(event));
```

---

### Issue: Memory usage growing

**Symptoms:**
- App memory increases over time
- Eventual out-of-memory crash

**Diagnosis:**
```dart
// BAD - unbounded cache
final _cache = <String, Stream<WorkflowExecution>>{};

Stream<WorkflowExecution> getExecution(String id) {
  if (!_cache.containsKey(id)) {
    _cache[id] = client.pollExecutionStatus(id)
        .shareReplay(maxSize: 1);  // Cache grows forever!
  }
  return _cache[id]!;
}
```

**Solution: Limit cache size**
```dart
// GOOD - bounded cache with LRU eviction
class BoundedCache {
  final _cache = <String, Stream<WorkflowExecution>>{};
  final int _maxSize = 100;

  Stream<WorkflowExecution> get(String id) {
    if (!_cache.containsKey(id)) {
      // Evict oldest if at capacity
      if (_cache.length >= _maxSize) {
        final oldestKey = _cache.keys.first;
        _cache.remove(oldestKey);
      }

      _cache[id] = client.pollExecutionStatus(id)
          .shareReplay(maxSize: 1);
    }
    return _cache[id]!;
  }

  void clear() {
    _cache.clear();
  }
}
```

---

## Type Errors

### Error: "type 'Stream<dynamic>' is not a subtype of type 'Stream<WorkflowExecution>'"

**Symptoms:**
```dart
// Type inference fails
final streams = webhookIds.map((id) =>
  client.startWorkflow(id, data)
);

Rx.combineLatest(streams, (values) => values);  // Type error!
```

**Solution: Explicit types**
```dart
// GOOD - explicit types
final streams = webhookIds.map((id) =>
  client.startWorkflow(id, data)
).toList();  // Convert to List

Rx.combineLatest<WorkflowExecution, List<WorkflowExecution>>(
  streams,
  (values) => values,
);
```

---

### Error: "The method 'map' isn't defined for the type 'Future'"

**Symptoms:**
```dart
// Trying to use stream operators on Future
final execution = client.startWorkflow('webhook', data).first;
execution.map((e) => e.id);  // ERROR: Future doesn't have map
```

**Solution: Use Future.then or convert to Stream**
```dart
// Solution 1: Use Future.then
final execution = client.startWorkflow('webhook', data).first;
execution.then((e) => e.id);

// Solution 2: Convert to Stream
final stream = client.startWorkflow('webhook', data);
stream.map((e) => e.id);
```

---

## Testing Problems

### Issue: Tests timeout waiting for streams

**Symptoms:**
```dart
test('should emit value', () async {
  final stream = client.startWorkflow('webhook', data);

  await expectLater(stream, emits(anything));  // Times out!
});
```

**Solution 1: Use fake timer**
```dart
test('should emit value', () async {
  await withClock(Clock.fixed(DateTime(2024)), () async {
    final stream = client.pollExecutionStatus(id);

    await expectLater(stream, emits(anything));
  });
});
```

**Solution 2: Add timeout**
```dart
test('should emit value', () async {
  final stream = client.startWorkflow('webhook', data)
      .timeout(Duration(seconds: 5));

  await expectLater(stream, emits(anything));
}, timeout: Timeout(Duration(seconds: 10)));
```

---

### Issue: Streams emit more values than expected

**Symptoms:**
```dart
test('should emit 2 values', () async {
  final stream = client.pollExecutionStatus(id);

  await expectLater(stream, emitsInOrder([
    anything,
    anything,
    emitsDone,  // Test fails - more values emitted!
  ]));
});
```

**Solution: Use take() to limit**
```dart
test('should emit first 2 values', () async {
  final stream = client.pollExecutionStatus(id).take(2);

  await expectLater(stream, emitsInOrder([
    anything,
    anything,
    emitsDone,
  ]));
});
```

---

## Flutter-Specific Issues

### Issue: StreamBuilder rebuilds too often

**Symptoms:**
- UI flickers
- Performance issues
- High CPU usage

**Solution: Use distinct() to filter duplicates**
```dart
StreamBuilder<WorkflowExecution>(
  stream: client.pollExecutionStatus(id)
      .distinct((prev, next) => prev.status == next.status),  // Only rebuild on status change
  builder: (context, snapshot) {
    return Text('Status: ${snapshot.data?.status}');
  },
)
```

---

### Issue: Stream created on every build

**Symptoms:**
- Memory leaks
- Multiple subscriptions
- Incorrect behavior

**Solution: Create stream in initState**
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late final Stream<WorkflowExecution> _stream;

  @override
  void initState() {
    super.initState();
    _stream = client.pollExecutionStatus(executionId);  // Create once
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _stream,  // Reuse same stream
      builder: (context, snapshot) {
        return Text('Status: ${snapshot.data?.status}');
      },
    );
  }
}
```

---

## Diagnostic Tools

### Enable RxDart debugging

```dart
// Add this at app start
void main() {
  // Enable RxDart debugging
  debugPrintRxDartStack = true;

  runApp(MyApp());
}
```

### Monitor stream subscriptions

```dart
class DebugService {
  final _subscriptions = <String, StreamSubscription>{};

  void subscribe(String name, Stream stream) {
    _subscriptions[name] = stream.listen(
      (_) {},
      onDone: () => print('[$name] Stream completed'),
      onError: (e) => print('[$name] Error: $e'),
    );
  }

  void printActiveSubscriptions() {
    print('Active subscriptions: ${_subscriptions.length}');
    for (final name in _subscriptions.keys) {
      print('  - $name');
    }
  }

  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _subscriptions.clear();
  }
}
```

### Memory leak detector

```dart
class MemoryLeakDetector {
  final _subjects = <String, Subject>{};

  void registerSubject(String name, Subject subject) {
    _subjects[name] = subject;
  }

  void checkForLeaks() {
    for (final entry in _subjects.entries) {
      if (!entry.value.isClosed) {
        print('⚠ Memory leak: ${entry.key} is not closed');
      }
    }
  }
}
```

---

## Prevention Checklist

### Before Production

- [ ] All subscriptions are cancelled in `dispose()`
- [ ] All subjects are closed in `dispose()`
- [ ] Error handlers added to all streams
- [ ] Streams use `shareReplay()` for multiple subscribers
- [ ] Timeouts added to long-running streams
- [ ] Memory leak tests pass (100+ dispose cycles)
- [ ] No streams created in `build()` methods
- [ ] Distinct operators used to prevent duplicate emissions
- [ ] Circuit breaker configured for error-prone operations
- [ ] Performance profiling completed

---

## Getting Help

If you're still stuck:

1. **Check examples** - `example/reactive/`
2. **Read guides:**
   - [RxDart Migration Guide](RXDART_MIGRATION_GUIDE.md)
   - [RxDart Patterns Guide](RXDART_PATTERNS_GUIDE.md)
3. **Search issues** - https://github.com/yourusername/n8n_dart/issues
4. **Ask questions** - https://github.com/yourusername/n8n_dart/discussions
5. **RxDart docs** - https://pub.dev/documentation/rxdart/latest/

---

**Still having issues?** Open an issue with:
- Minimal code example
- Expected behavior
- Actual behavior
- Error messages
- Environment (Dart/Flutter version, platform)
