# n8n_dart

[![Pub Version](https://img.shields.io/pub/v/n8n_dart)](https://pub.dev/packages/n8n_dart)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Production-ready Dart package for **n8n workflow automation** integration. Works with both pure Dart applications and Flutter mobile/web apps.

## ✨ Features

- ✅ **Pure Dart Core** - No Flutter dependencies in core package
- ✅ **Type-Safe Models** - Comprehensive validation with `ValidationResult<T>`
- ✅ **Smart Polling** - 6 polling strategies (minimal, balanced, high-frequency, battery-optimized, etc.)
- ✅ **Error Handling** - Intelligent retry with exponential backoff and circuit breaker
- ✅ **Stream Resilience** - 5 recovery strategies for robust stream management
- ✅ **Dynamic Forms** - 15+ form field types for wait node interactions
- ✅ **Configuration Profiles** - Pre-configured profiles for common use cases
- ✅ **Webhook Support** - Full webhook lifecycle management
- ✅ **Health Checks** - Connection monitoring and validation

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

## 🔧 Advanced Features

### Smart Polling

The package includes a smart polling manager with multiple strategies:

```dart
final pollingManager = SmartPollingManager(PollingConfig.balanced());

pollingManager.startPolling(executionId, () async {
  final execution = await client.getExecutionStatus(executionId);

  // Record activity for adaptive polling
  pollingManager.recordActivity(executionId, execution.status.toString());

  // Stop polling when finished
  if (execution.isFinished) {
    pollingManager.stopPolling(executionId);
  }
});

// Get metrics
final metrics = pollingManager.getMetrics(executionId);
print('Polling efficiency: ${metrics?.successRate}');
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

### N8nClient

| Method | Description |
|--------|-------------|
| `startWorkflow(webhookId, data)` | Start a workflow execution |
| `getExecutionStatus(executionId)` | Get current execution status |
| `resumeWorkflow(executionId, input)` | Resume paused workflow with input |
| `cancelWorkflow(executionId)` | Cancel running execution |
| `validateWebhook(webhookId)` | Validate webhook exists |
| `testConnection()` | Test server connectivity |
| `dispose()` | Clean up resources |

### Models

- `WorkflowExecution` - Execution state and metadata
- `WorkflowStatus` - Enum (new, running, waiting, success, error, canceled, crashed)
- `WaitNodeData` - Wait node configuration and fields
- `FormFieldConfig` - Dynamic form field definition
- `ValidationResult<T>` - Type-safe validation results

### Configuration

- `N8nServiceConfig` - Main configuration
- `N8nConfigBuilder` - Fluent configuration builder
- `N8nConfigProfiles` - Preset configurations
- `SecurityConfig` - Authentication and security
- `PollingConfig` - Polling strategies
- `RetryConfig` - Retry and circuit breaker
- `WebhookConfig` - Webhook timeouts and validation

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
