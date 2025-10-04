# n8n_dart

[![Pub Version](https://img.shields.io/pub/v/n8n_dart)](https://pub.dev/packages/n8n_dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Production-ready Dart package for **n8n workflow automation** integration. Works with both pure Dart applications and Flutter mobile/web apps.

## ✨ Features

### Core Features
- ✅ **Pure Dart Core** - No Flutter dependencies in core package
- ✅ **Type-Safe Models** - Comprehensive validation with `ValidationResult<T>`
- ✅ **Dynamic Forms** - 18 form field types for wait node interactions
- ✅ **Configuration Profiles** - 6 pre-configured profiles for common use cases
- ✅ **Webhook Support** - Full webhook lifecycle management
- ✅ **Health Checks** - Connection monitoring and validation
- ✅ **Workflow Generator** - Programmatically create n8n workflow JSON files
- ✅ **Pre-built Templates** - Ready-to-use workflow templates (CRUD, Auth, File Upload, etc.)

### Reactive Programming (NEW! 🔥)
- ✅ **Fully Reactive API** - Stream-based architecture with RxDart
- ✅ **Reactive State Management** - BehaviorSubjects for automatic state propagation
- ✅ **Smart Polling** - Auto-stop polling with adaptive intervals
- ✅ **Error Recovery** - Automatic retry with exponential backoff and circuit breaker
- ✅ **Stream Composition** - Parallel, sequential, race, and batch operations
- ✅ **Event-Driven** - PublishSubjects for workflow lifecycle events
- ✅ **Reactive Queue** - Automatic workflow queue with throttling
- ✅ **Smart Caching** - TTL-based caching with reactive invalidation
- ✅ **Live Validation** - Reactive workflow builder with real-time validation
- ✅ **Performance Metrics** - Real-time monitoring of success rate, latency, etc.

### Both APIs Available
- ✅ **Legacy Future-based API** - Traditional async/await patterns (still supported)
- ✅ **Reactive Stream-based API** - Modern reactive programming with RxDart (recommended)

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  n8n_dart: ^1.0.0
```

Then run:

```bash
dart pub get
# or
flutter pub get
```

## 🚀 Quick Start

### Pure Dart Usage

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  // Create client with production configuration
  final client = N8nClient(
    config: N8nConfigProfiles.production(
      baseUrl: 'https://n8n.example.com',
      apiKey: 'your-api-key',
    ),
  );

  // Test connection
  final isHealthy = await client.testConnection();
  print('n8n server healthy: $isHealthy');

  // Start a workflow
  final executionId = await client.startWorkflow(
    'my-webhook-id',
    {'name': 'John', 'action': 'process'},
  );

  print('Started execution: $executionId');

  // Poll for completion
  while (true) {
    await Future.delayed(Duration(seconds: 2));

    final execution = await client.getExecutionStatus(executionId);
    print('Status: ${execution.status}');

    if (execution.isFinished) {
      print('Completed with data: ${execution.data}');
      break;
    }

    // Handle wait nodes
    if (execution.waitingForInput && execution.waitNodeData != null) {
      print('Waiting for input: ${execution.waitNodeData!.nodeName}');

      // Provide user input
      final input = {'userChoice': 'approve'};
      await client.resumeWorkflow(executionId, input);
    }
  }

  // Clean up
  client.dispose();
}
```

### Flutter Usage

For Flutter-specific features, see the [Flutter Integration](#flutter-integration) section.

## 📖 Core Concepts

### 1. Workflow Execution Lifecycle

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│   new   │ ──> │ running │ ──> │ waiting │ ──> │ success │
└─────────┘     └─────────┘     └─────────┘     └─────────┘
                      │                               │
                      │                               │
                      ▼                               ▼
                ┌─────────┐                     ┌─────────┐
                │  error  │                     │canceled │
                └─────────┘                     └─────────┘
```

### 2. Wait Nodes

n8n workflows can pause execution and wait for external input using Wait nodes:

```dart
final execution = await client.getExecutionStatus(executionId);

if (execution.waitingForInput && execution.waitNodeData != null) {
  final waitNode = execution.waitNodeData!;

  // Examine required fields
  for (final field in waitNode.fields) {
    print('Field: ${field.name} (${field.type}) - ${field.required}');
  }

  // Validate and provide input
  final input = {'fieldName': 'value'};
  final validationResult = waitNode.validateFormData(input);

  if (validationResult.isValid) {
    await client.resumeWorkflow(executionId, input);
  } else {
    print('Validation errors: ${validationResult.errors}');
  }
}
```

### 3. Configuration Profiles

The package provides 6 preset configurations:

```dart
// Minimal - Basic usage with minimal overhead
final config1 = N8nConfigProfiles.minimal();

// Development - Extensive logging and debugging
final config2 = N8nConfigProfiles.development();

// Production - Security, performance, monitoring
final config3 = N8nConfigProfiles.production(
  baseUrl: 'https://n8n.example.com',
  apiKey: 'your-api-key',
  signingSecret: 'optional-signing-secret',
);

// Resilient - For unreliable networks
final config4 = N8nConfigProfiles.resilient(
  baseUrl: 'https://n8n.example.com',
  apiKey: 'your-api-key',
);

// High Performance - For demanding applications
final config5 = N8nConfigProfiles.highPerformance(
  baseUrl: 'https://n8n.example.com',
  apiKey: 'your-api-key',
);

// Battery Optimized - For mobile devices
final config6 = N8nConfigProfiles.batteryOptimized(
  baseUrl: 'https://n8n.example.com',
  apiKey: 'your-api-key',
);
```

Or build custom configuration:

```dart
final customConfig = N8nConfigBuilder()
  .baseUrl('https://n8n.example.com')
  .environment(N8nEnvironment.production)
  .logLevel(LogLevel.warning)
  .security(SecurityConfig.production(apiKey: 'key'))
  .polling(PollingConfig.balanced())
  .retry(RetryConfig.aggressive())
  .build();
```

## 🏗️ n8n Workflow Generator

NEW! Generate n8n workflow JSON files programmatically using Dart:

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  // Create a workflow using fluent API
  final workflow = WorkflowBuilder.create()
      .name('User Registration API')
      .tags(['api', 'auth'])
      .webhookTrigger(
        name: 'Registration Webhook',
        path: 'auth/register',
        method: 'POST',
      )
      .postgres(
        name: 'Save User',
        operation: 'insert',
        table: 'users',
      )
      .emailSend(
        name: 'Welcome Email',
        fromEmail: 'welcome@example.com',
        toEmail: '={{$json.email}}',
        subject: 'Welcome!',
      )
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 201,
      )
      .connectSequence([
        'Registration Webhook',
        'Save User',
        'Welcome Email',
        'Return Success',
      ])
      .build();

  // Save to file
  await workflow.saveToFile('user_registration.json');

  // Import into n8n UI!
}
```

### Pre-built Templates

```dart
// CRUD API
final crudWorkflow = WorkflowTemplates.crudApi(
  resourceName: 'products',
  tableName: 'products',
);

// User Registration
final authWorkflow = WorkflowTemplates.userRegistration(
  webhookPath: 'auth/register',
  tableName: 'users',
  fromEmail: 'noreply@example.com',
);

// File Upload with S3
final uploadWorkflow = WorkflowTemplates.fileUpload(
  webhookPath: 'upload',
  s3Bucket: 'my-uploads',
);

// Order Processing with Stripe
final orderWorkflow = WorkflowTemplates.orderProcessing(
  webhookPath: 'orders',
  notificationEmail: 'orders@example.com',
);

// Multi-step Form
final formWorkflow = WorkflowTemplates.multiStepForm(
  webhookPath: 'onboarding',
  tableName: 'onboarding_data',
);
```

**See the [Workflow Generator Guide](docs/WORKFLOW_GENERATOR_GUIDE.md) for complete documentation!**

---

## 🚀 Reactive Programming with RxDart

**NEW!** n8n_dart now includes comprehensive reactive programming support using RxDart!

### ReactiveN8nClient - Stream-Based API

The reactive client provides a fully stream-based API with powerful RxDart operators:

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  // Create reactive client
  final client = ReactiveN8nClient(
    config: N8nConfigProfiles.production(
      baseUrl: 'https://n8n.example.com',
      apiKey: 'your-api-key',
    ),
  );

  // Start workflow - returns Stream<WorkflowExecution>
  client.startWorkflow('my-webhook-id', {'action': 'process'}).listen(
    (execution) => print('Started: ${execution.id}'),
    onError: (error) => print('Error: $error'),
  );

  // Auto-polling with smart stop
  client.pollExecutionStatus(executionId).listen(
    (execution) {
      print('Status: ${execution.status}');
      // Automatically stops when finished!
    },
    onDone: () => print('Workflow completed'),
  );

  // Watch multiple executions in parallel
  client.watchMultipleExecutions(['exec-1', 'exec-2', 'exec-3']).listen(
    (executions) {
      final finished = executions.where((e) => e.isFinished).length;
      print('Progress: $finished/${executions.length}');
    },
  );
}
```

### Reactive State Management

All state is managed reactively using BehaviorSubjects:

```dart
// Subscribe to execution state changes
client.executionState$.listen((executions) {
  print('Active executions: ${executions.length}');
});

// Monitor connection status
client.connectionState$.listen((state) {
  if (state == ConnectionState.connected) {
    print('Connected to n8n server');
  }
});

// Track performance metrics
client.metrics$.listen((metrics) {
  print('Success rate: ${metrics.successRate * 100}%');
  print('Avg response time: ${metrics.averageResponseTime.inMilliseconds}ms');
});

// React to workflow lifecycle events
client.workflowStarted$.listen((event) {
  print('Workflow ${event.executionId} started');
});

client.workflowCompleted$.listen((event) {
  print('Workflow ${event.executionId} completed: ${event.status}');
});
```

### Advanced Reactive Patterns

**Parallel Execution:**
```dart
// Start multiple workflows, wait for all to complete
client.batchStartWorkflows([
  MapEntry('webhook-1', {'batch': 1}),
  MapEntry('webhook-2', {'batch': 2}),
  MapEntry('webhook-3', {'batch': 3}),
]).listen((allExecutions) {
  print('All ${allExecutions.length} workflows completed!');
});
```

**Sequential Execution:**
```dart
// Execute workflows one after another
client.startWorkflowsSequential(
  Stream.fromIterable([data1, data2, data3]),
  'sequential-webhook',
).listen((execution) {
  print('Step completed: ${execution.id}');
});
```

**Race Condition (Fastest Wins):**
```dart
// First workflow to complete wins
client.raceWorkflows(
  ['fast-webhook', 'slow-webhook'],
  {'data': 'test'},
).listen((winner) {
  print('Winner: ${winner.id}');
});
```

**Throttled Execution (Rate Limiting):**
```dart
// Limit execution rate to max 1 per second
client.startWorkflowsThrottled(
  dataStream,
  'rate-limited-webhook',
  throttleDuration: Duration(seconds: 1),
).listen((execution) {
  print('Throttled start: ${execution.id}');
});
```

### Reactive Error Handling

Built-in circuit breaker and error recovery:

```dart
final errorHandler = ReactiveErrorHandler(
  config: ErrorHandlerConfig.resilient(),
);

// Listen to categorized errors
errorHandler.networkErrors$.listen((error) {
  print('Network error: ${error.message}');
});

errorHandler.serverErrors$.listen((error) {
  print('Server error: ${error.message}');
});

// Monitor circuit breaker state
errorHandler.circuitState$.listen((state) {
  if (state == CircuitState.open) {
    print('Circuit breaker activated - too many errors!');
  }
});

// Monitor error rate
errorHandler.errorRate$.listen((rate) {
  print('Error rate: ${(rate * 100).toStringAsFixed(1)}%');
});

// Automatic retry with exponential backoff
errorHandler.withRetry(
  client.startWorkflow('flaky-webhook', data),
).listen(
  (execution) => print('Success: ${execution.id}'),
  onError: (error) => print('Failed after retries: $error'),
);
```

### Reactive Workflow Queue

Automatic queue management with throttling:

```dart
final queue = ReactiveWorkflowQueue(
  client: client,
  config: QueueConfig.standard(),
);

// Enqueue workflows
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
  print('Success rate: ${metrics.successRate}');
});
```

### Reactive Execution Cache

Smart caching with TTL and invalidation:

```dart
final cache = ReactiveExecutionCache(
  client: client,
  ttl: Duration(minutes: 5),
);

// Watch cached execution (auto-refreshes on invalidation)
cache.watch('execution-123').listen((execution) {
  if (execution != null) {
    print('From cache: ${execution.status}');
  } else {
    print('Cache miss - fetching...');
  }
});

// Invalidate cache entries
cache.invalidate('execution-123');
cache.invalidatePattern((id) => id.startsWith('webhook-'));

// Monitor cache performance
cache.metrics$.listen((metrics) {
  print('Hit rate: ${metrics.hitRate}');
});
```

### Reactive Workflow Builder

Build workflows with live validation:

```dart
final builder = ReactiveWorkflowBuilder.create('My API Workflow');

// Watch validation state
builder.isValid$.listen((isValid) {
  print('Workflow ${isValid ? "valid" : "invalid"}');
});

builder.validationErrors$.listen((errors) {
  for (final error in errors) {
    print('Error: $error');
  }
});

// Build reactively
builder.webhookTrigger(path: 'api/v1/process');
builder.setNode(name: 'Process Data', type: 'function');
builder.respondToWebhook();
builder.connect('Webhook', 'Process Data');

// Watch the built workflow
builder.workflow$.listen((workflow) {
  print('Workflow updated: ${workflow.nodes.length} nodes');
});
```

### Migration from Future-based to Reactive

Both APIs coexist! You can migrate gradually:

```dart
// Legacy Future-based API (still supported)
final client = N8nClient(config: config);
final executionId = await client.startWorkflow('webhook', data);

// New Reactive API (recommended)
final reactiveClient = ReactiveN8nClient(config: config);
reactiveClient.startWorkflow('webhook', data).listen((execution) {
  print('Execution: ${execution.id}');
});

// Convert stream to future when needed
final execution = await reactiveClient.startWorkflow('webhook', data).first;
```

**Learn More:**
- 📖 [RxDart Migration Guide](docs/RXDART_MIGRATION_GUIDE.md)
- 🎯 [RxDart Patterns Guide](docs/RXDART_PATTERNS_GUIDE.md)
- 🔧 [Troubleshooting Guide](docs/RXDART_TROUBLESHOOTING.md)
- 💡 [Reactive Examples](example/reactive/)

---

## 🔧 Advanced Features

### Smart Polling

The package includes both legacy and reactive polling:

**Legacy (Future-based):**
```dart
final pollingManager = SmartPollingManager(PollingConfig.balanced());

pollingManager.startPolling(executionId, () async {
  final execution = await client.getExecutionStatus(executionId);
  pollingManager.recordActivity(executionId, execution.status.toString());

  if (execution.isFinished) {
    pollingManager.stopPolling(executionId);
  }
});
```

**Reactive (Stream-based - Recommended):**
```dart
final reactivePolling = ReactivePollingManager(
  config: PollingConfig.balanced(),
);

reactivePolling.startPolling(executionId, pollFunction).listen(
  (execution) => print('Status: ${execution.status}'),
  onDone: () => print('Polling complete'),
);

// Watch polling metrics
reactivePolling.pollingMetrics$.listen((metrics) {
  print('Success rate: ${metrics.successRate}');
});
```

### Error Handling with Retry

Intelligent retry logic with exponential backoff:

```dart
final errorHandler = N8nErrorHandler(RetryConfig.aggressive());

final result = await errorHandler.executeWithRetry(() async {
  return await someOperationThatMightFail();
});

// Check circuit breaker state
print('Circuit breaker: ${errorHandler.circuitBreakerState}');
```

### Stream Resilience

Add resilience to Dart streams:

```dart
final resilientStream = myStream
  .withResilience(
    config: StreamErrorConfig.resilient(),
    fallbackValue: defaultValue,
  );

// Or use specific recovery strategies
final retryStream = myStream.withRetry(maxRetries: 5);
final fallbackStream = myStream.withFallback(defaultValue);
final healthMonitoredStream = myStream.withHealthMonitoring();
```

## 🎯 Flutter Integration

**Note:** Flutter integration requires additional dependencies (Stacked, RxDart, etc.) which you need to add to your Flutter project.

The core `n8n_dart` package is pure Dart and works in any Dart application. For Flutter-specific features, you can:

1. Use the core `N8nClient` directly in your Flutter app
2. Create your own reactive wrapper using the included models and services
3. Refer to the included `n8n_service.dart` as a reference implementation

Example Flutter integration:

```dart
import 'package:n8n_dart/n8n_dart.dart';
import 'package:rxdart/rxdart.dart';

class N8nFlutterService {
  final N8nClient client;
  final BehaviorSubject<WorkflowExecution?> _execution$ =
      BehaviorSubject.seeded(null);

  Stream<WorkflowExecution?> get execution$ => _execution$.stream;

  N8nFlutterService({required this.client});

  Future<void> startWorkflow(String webhookId, Map<String, dynamic>? data) async {
    final executionId = await client.startWorkflow(webhookId, data);

    // Start polling
    Timer.periodic(Duration(seconds: 2), (timer) async {
      try {
        final execution = await client.getExecutionStatus(executionId);
        _execution$.add(execution);

        if (execution.isFinished) {
          timer.cancel();
        }
      } catch (error) {
        timer.cancel();
        _execution$.addError(error);
      }
    });
  }

  void dispose() {
    _execution$.close();
    client.dispose();
  }
}
```

## 📚 API Reference

### Legacy N8nClient (Future-based)

| Method | Return Type | Description |
|--------|-------------|-------------|
| `startWorkflow(webhookId, data)` | `Future<String>` | Start a workflow execution |
| `getExecutionStatus(executionId)` | `Future<WorkflowExecution>` | Get current execution status |
| `resumeWorkflow(executionId, input)` | `Future<void>` | Resume paused workflow with input |
| `cancelWorkflow(executionId)` | `Future<void>` | Cancel running execution |
| `validateWebhook(webhookId)` | `Future<bool>` | Validate webhook exists |
| `testConnection()` | `Future<bool>` | Test server connectivity |
| `dispose()` | `void` | Clean up resources |

### ReactiveN8nClient (Stream-based - Recommended)

| Method | Return Type | Description |
|--------|-------------|-------------|
| `startWorkflow(webhookId, data)` | `Stream<WorkflowExecution>` | Start a workflow execution |
| `pollExecutionStatus(executionId)` | `Stream<WorkflowExecution>` | Poll status with auto-stop |
| `watchExecution(executionId)` | `Stream<WorkflowExecution>` | Watch with automatic retry |
| `watchMultipleExecutions(ids)` | `Stream<List<WorkflowExecution>>` | Watch multiple in parallel |
| `batchStartWorkflows(workflows)` | `Stream<List<WorkflowExecution>>` | Start all, wait for all |
| `startWorkflowsSequential(dataStream)` | `Stream<WorkflowExecution>` | Execute sequentially |
| `raceWorkflows(webhookIds, data)` | `Stream<WorkflowExecution>` | First to complete wins |
| `startWorkflowsThrottled(dataStream)` | `Stream<WorkflowExecution>` | Rate-limited execution |
| `zipWorkflows(webhookIds, data)` | `Stream<List<WorkflowExecution>>` | Combine results |
| `resumeWorkflow(executionId, input)` | `Stream<bool>` | Resume with confirmation |
| `cancelWorkflow(executionId)` | `Stream<bool>` | Cancel with confirmation |
| `dispose()` | `void` | Clean up resources |

**Reactive State Streams:**
- `executionState$` - `Stream<Map<String, WorkflowExecution>>` - Current executions
- `config$` - `Stream<N8nServiceConfig>` - Current configuration
- `connectionState$` - `Stream<ConnectionState>` - Connection status
- `metrics$` - `Stream<PerformanceMetrics>` - Performance metrics
- `workflowEvents$` - `Stream<WorkflowEvent>` - All lifecycle events
- `workflowStarted$` - `Stream<WorkflowStartedEvent>` - Started events only
- `workflowCompleted$` - `Stream<WorkflowCompletedEvent>` - Completed events only
- `workflowErrors$` - `Stream<WorkflowErrorEvent>` - Error events only
- `errors$` - `Stream<N8nException>` - All errors

### ReactiveErrorHandler

| Method/Property | Return Type | Description |
|-----------------|-------------|-------------|
| `handleError(error)` | `void` | Report an error |
| `withRetry<T>(stream)` | `Stream<T>` | Wrap stream with retry |
| `errors$` | `Stream<N8nException>` | All errors |
| `networkErrors$` | `Stream<N8nException>` | Network errors only |
| `serverErrors$` | `Stream<N8nException>` | Server errors only |
| `timeoutErrors$` | `Stream<N8nException>` | Timeout errors only |
| `authErrors$` | `Stream<N8nException>` | Auth errors only |
| `workflowErrors$` | `Stream<N8nException>` | Workflow errors only |
| `errorRate$` | `Stream<double>` | Error rate over time |
| `circuitState$` | `Stream<CircuitState>` | Circuit breaker state |
| `dispose()` | `void` | Clean up resources |

### ReactiveWorkflowQueue

| Method/Property | Return Type | Description |
|-----------------|-------------|-------------|
| `enqueue(webhookId, data)` | `void` | Add workflow to queue |
| `processQueue()` | `Stream<WorkflowExecution>` | Process queue items |
| `queue$` | `Stream<List<QueuedWorkflow>>` | Current queue state |
| `queueLength$` | `Stream<int>` | Queue size |
| `events$` | `Stream<QueueEvent>` | Queue events |
| `metrics$` | `Stream<QueueMetrics>` | Queue metrics |
| `dispose()` | `void` | Clean up resources |

### ReactiveExecutionCache

| Method/Property | Return Type | Description |
|-----------------|-------------|-------------|
| `watch(executionId)` | `Stream<WorkflowExecution?>` | Watch cached execution |
| `invalidate(executionId)` | `void` | Invalidate cache entry |
| `invalidateAll()` | `void` | Clear all cache |
| `invalidatePattern(matcher)` | `void` | Invalidate by pattern |
| `cache$` | `Stream<Map<String, CachedExecution>>` | Cache state |
| `metrics$` | `Stream<CacheMetrics>` | Cache metrics |
| `dispose()` | `void` | Clean up resources |

### ReactiveWorkflowBuilder

| Method/Property | Return Type | Description |
|-----------------|-------------|-------------|
| `webhookTrigger(...)` | `void` | Add webhook trigger |
| `setNode(...)` | `void` | Add/update node |
| `connect(from, to)` | `void` | Connect nodes |
| `nodes$` | `Stream<List<WorkflowNode>>` | Current nodes |
| `validationErrors$` | `Stream<List<String>>` | Validation errors |
| `isValid$` | `Stream<bool>` | Validation state |
| `workflow$` | `Stream<Workflow>` | Built workflow |
| `dispose()` | `void` | Clean up resources |

### Models

- `WorkflowExecution` - Execution state and metadata
- `WorkflowStatus` - Enum (new, running, waiting, success, error, canceled, crashed)
- `WaitNodeData` - Wait node configuration and fields
- `FormFieldConfig` - Dynamic form field definition
- `ValidationResult<T>` - Type-safe validation results
- `PerformanceMetrics` - Performance statistics
- `CircuitState` - Circuit breaker state (open, halfOpen, closed)
- `ConnectionState` - Connection status (disconnected, connecting, connected, error)

### Configuration

- `N8nServiceConfig` - Main configuration
- `N8nConfigBuilder` - Fluent configuration builder
- `N8nConfigProfiles` - Preset configurations
- `SecurityConfig` - Authentication and security
- `PollingConfig` - Polling strategies
- `RetryConfig` - Retry and circuit breaker
- `WebhookConfig` - Webhook timeouts and validation
- `ErrorHandlerConfig` - Error handler configuration
- `QueueConfig` - Queue configuration

## 🧪 Testing

The package includes comprehensive test coverage:

```bash
dart test
```

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 🤝 Contributing

Contributions welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📞 Support

- 📖 [Documentation](https://pub.dev/documentation/n8n_dart/latest/)
- 🐛 [Issue Tracker](https://github.com/yourusername/n8n_dart/issues)
- 💬 [Discussions](https://github.com/yourusername/n8n_dart/discussions)

## 🙏 Acknowledgments

- [n8n.io](https://n8n.io) - Workflow automation platform
- [n8nui/examples](https://github.com/n8nui/examples) - Architectural inspiration

---

**Made with ❤️ for the Dart and Flutter community**
