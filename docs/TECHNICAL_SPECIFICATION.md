# n8n_dart - Technical Specification

**Version:** 1.0.0
**Date:** October 2, 2025
**Project Type:** Dart Package (Flutter-compatible)
**Timeline:** 1 month (MVP: Week 1-2, Phase 2: Week 3-4)
**Development Methodology:** Test-Driven Development (TDD)

---

## Executive Summary

`n8n_dart` is a comprehensive Dart package that provides type-safe, production-ready integration with n8n workflow automation platform. It supports both pure Dart applications and Flutter mobile/web apps with reactive programming patterns, smart polling, resilient error handling, and dynamic form generation.

---

## 1. Project Overview

### 1.1 Purpose

Create a standalone Dart package that:
- Provides programmatic interaction with n8n workflows via webhooks
- Supports workflow lifecycle management (start, monitor, resume, cancel)
- Handles dynamic user input through Wait nodes
- Works seamlessly in both Dart CLI and Flutter applications
- Offers production-grade reliability with retry mechanisms and error recovery

### 1.2 Core Concepts (from n8nui/examples)

Based on the n8nui/examples repository analysis:

1. **Webhook-Triggered Workflows**: Workflows are initiated via webhook endpoints
2. **Execution Monitoring**: Real-time polling to track workflow execution status
3. **Wait Node Interaction**: Detection and handling of workflow pauses requiring user input
4. **Dynamic Form Generation**: UI-agnostic form field configuration for user inputs
5. **State Management**: Tracking execution states (new, running, waiting, success, error, canceled)

### 1.3 Key Features

- ✅ Reactive streams with RxDart for real-time updates
- ✅ Smart polling with activity-aware optimization
- ✅ Comprehensive error handling with 5 retry strategies
- ✅ Type-safe models with validation
- ✅ Configurable service profiles (development, production, resilient, etc.)
- ✅ Dynamic form field support (18 field types including password, hiddenField, html)
- ✅ Memory leak prevention with proper disposal
- ✅ Flutter-agnostic core (can be used in pure Dart)
- ✅ Optional Flutter integration layer
- ✅ Complete execution tracking (lastNodeExecuted, waitTill, stoppedAt, resumeUrl)

---

## 2. Architecture

### 2.1 Package Structure

```
n8n_dart/
├── lib/
│   ├── n8n_dart.dart                    # Main export (pure Dart core)
│   ├── n8n_dart_flutter.dart            # Flutter integration guidance
│   └── src/
│       └── core/                        # Core Dart implementation (no Flutter deps)
│           ├── models/
│           │   └── n8n_models.dart      # All models in single file (800 lines)
│           │       ├── ValidationResult<T>
│           │       ├── Validator mixin
│           │       ├── WorkflowStatus enum
│           │       ├── FormFieldType enum
│           │       ├── FormFieldConfig
│           │       ├── WaitNodeData
│           │       └── WorkflowExecution
│           ├── services/
│           │   ├── n8n_client.dart      # Core HTTP client (281 lines)
│           │   ├── polling_manager.dart # Smart polling (678 lines)
│           │   └── stream_recovery.dart # Stream resilience (559 lines)
│           ├── configuration/
│           │   └── n8n_configuration.dart  # All config in single file (667 lines)
│           │       ├── N8nEnvironment enum
│           │       ├── LogLevel enum
│           │       ├── PerformanceConfig
│           │       ├── SecurityConfig
│           │       ├── CacheConfig
│           │       ├── WebhookConfig
│           │       ├── N8nServiceConfig
│           │       ├── N8nConfigBuilder
│           │       └── N8nConfigProfiles (6 presets)
│           └── exceptions/
│               └── error_handling.dart  # All error handling (518 lines)
│                   ├── N8nErrorType enum
│                   ├── N8nException
│                   ├── RetryConfig
│                   ├── CircuitBreaker
│                   └── N8nErrorHandler
├── test/                                # Test directory (structure ready)
│   └── core/
│       ├── models_test.dart
│       ├── n8n_client_test.dart
│       └── polling_manager_test.dart
├── example/
│   ├── main.dart                        # Comprehensive Dart example (182 lines)
│   └── n8n_example                      # Compiled executable
├── pubspec.yaml                         # Package manifest
├── README.md                            # User documentation
├── CHANGELOG.md                         # Version history
├── LICENSE                              # MIT License
├── analysis_options.yaml                # Dart linter config
├── TECHNICAL_SPECIFICATION.md           # This file
├── PROJECT_SUMMARY.md                   # Project overview
└── PACKAGE_COMPLETE.md                  # Completion report
```

**Implementation Notes:**
- ✅ **Pure Dart Core**: Zero Flutter dependencies in `lib/src/core/`
- ✅ **Consolidated Files**: Models, config, and error handling in single files for simplicity
- ✅ **No Flutter Layer**: Users create their own Flutter integration (see Section 8)
- ✅ **Example Included**: Working Dart CLI example demonstrates all features
- ✅ **Documentation**: Comprehensive docs and integration guidance

### 2.2 Layered Architecture

```
┌─────────────────────────────────────────────────┐
│         Application Layer (Consumer)            │
│  (Flutter App / Dart CLI / Backend Service)     │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│         Flutter Integration Layer                │
│  • N8nService (Reactive BehaviorSubjects)       │
│  • Widgets (Form, Listener, Status)             │
│  • Stream Recovery Manager                      │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│              Core Dart Layer                     │
│  • N8nClient (HTTP operations)                  │
│  • Polling Manager (Smart polling)              │
│  • Error Handler (Retry logic)                  │
│  • Models (Type-safe data)                      │
│  • Configuration (Profiles & builders)          │
└─────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────┐
│              n8n Server                          │
│  • Webhook endpoints                            │
│  • Workflow execution engine                    │
│  • Wait nodes for user input                    │
└─────────────────────────────────────────────────┘
```

### 2.3 Core Components

#### 2.3.1 N8nClient (Pure Dart Core)

The main HTTP client for n8n operations (pure Dart, no Flutter dependencies):

```dart
class N8nClient {
  final N8nServiceConfig config;
  final http.Client httpClient;
  final N8nErrorHandler errorHandler;

  // Constructor
  N8nClient({
    required N8nServiceConfig config,
    http.Client? httpClient,
  });

  // Core workflow operations
  Future<String> startWorkflow(String webhookId, Map<String, dynamic>? data);
  Future<WorkflowExecution> getExecutionStatus(String executionId);
  Future<bool> resumeWorkflow(String executionId, Map<String, dynamic> input);
  Future<bool> cancelWorkflow(String executionId);

  // Validation and health
  Future<bool> validateWebhook(String webhookId);
  Future<bool> testConnection();

  // Cleanup
  void dispose();
}
```

**Implementation:** [`lib/src/core/services/n8n_client.dart`](lib/src/core/services/n8n_client.dart) (281 lines)

#### 2.3.2 SmartPollingManager

Activity-aware polling with multiple strategies:

```dart
class SmartPollingManager {
  final PollingConfig config;

  // Polling control
  void startPolling(String executionId, Future<void> Function() pollFunction);
  void stopPolling(String executionId);

  // Activity tracking
  void recordActivity(String executionId, String status);
  void recordError(String executionId);

  // Metrics
  PollingMetrics? getMetrics(String executionId);
  Map<String, dynamic> getOverallStats();

  // Cleanup
  void dispose();
}
```

**Implementation:** [`lib/src/core/services/polling_manager.dart`](lib/src/core/services/polling_manager.dart) (678 lines)

#### 2.3.3 N8nErrorHandler

Intelligent error handling with retry and circuit breaker:

```dart
class N8nErrorHandler {
  final RetryConfig config;
  final CircuitBreaker? circuitBreaker;

  // Retry execution
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    String? operationId,
  });

  // Error classification
  bool shouldRetry(N8nException error, [int? currentAttempt]);

  // State management
  Map<String, dynamic> getRetryStats(String operationId);
  void resetRetryState(String operationId);
  void resetCircuitBreaker();
}
```

**Implementation:** [`lib/src/core/exceptions/error_handling.dart`](lib/src/core/exceptions/error_handling.dart) (518 lines)

#### 2.3.4 ResilientStreamManager

Stream resilience with multiple recovery strategies:

```dart
class ResilientStreamManager<T> {
  final StreamErrorConfig config;
  final T? fallbackValue;

  // Stream management
  Stream<T> createResilientStream(Stream<T> sourceStream);

  // Health monitoring
  Stream<StreamHealth> get health$;
  StreamHealth get currentHealth;

  // Statistics
  Map<String, dynamic> getRecoveryStats();
  void resetRecoveryState();

  // Cleanup
  void dispose();
}
```

**Implementation:** [`lib/src/core/services/stream_recovery.dart`](lib/src/core/services/stream_recovery.dart) (559 lines)

#### 2.3.5 Flutter Integration (User-Created)

For Flutter apps, developers create their own reactive wrapper using RxDart:

```dart
class N8nFlutterService {
  final N8nClient client;
  final BehaviorSubject<WorkflowExecution?> _execution$;

  Stream<WorkflowExecution?> get execution$ => _execution$.stream;

  // Your custom implementation
  Future<void> startWorkflow(...);
  void dispose();
}
```

**See Section 8** for complete Flutter integration patterns and examples.

---

## 3. Data Models

### 3.1 Model Hierarchy

```
ValidationResult<T>
├── value: T?
├── errors: List<String>
└── isValid: bool

WorkflowStatus (enum)
├── new_
├── running
├── waiting
├── success
├── error
├── canceled
└── crashed

FormFieldType (enum) - 18 types
├── text
├── email
├── number
├── select
├── radio
├── checkbox
├── date
├── time
├── datetimeLocal
├── file
├── textarea
├── url
├── phone
├── slider
├── switch_
├── password       # NEW - Password input field
├── hiddenField    # NEW - Hidden form field with default value
└── html           # NEW - Custom HTML content

FormFieldConfig
├── name: String
├── label: String
├── type: FormFieldType
├── required: bool
├── placeholder: String?
├── defaultValue: String?
├── options: List<String>?
├── validation: String?
└── metadata: Map<String, dynamic>?

WaitNodeData
├── nodeId: String
├── nodeName: String
├── description: String?
├── fields: List<FormFieldConfig>
├── metadata: Map<String, dynamic>?
├── createdAt: DateTime
└── expiresAt: DateTime?

WorkflowExecution
├── id: String
├── workflowId: String
├── status: WorkflowStatus
├── startedAt: DateTime
├── finishedAt: DateTime?
├── stoppedAt: DateTime?           # NEW - When execution paused
├── waitTill: DateTime?             # NEW - When wait expires (for timeout handling)
├── lastNodeExecuted: String?       # NEW - Last executed node name (critical for n8nui compatibility)
├── resumeUrl: String?              # NEW - Resume webhook URL
├── data: Map<String, dynamic>?
├── error: String?
├── waitingForInput: bool
├── waitNodeData: WaitNodeData?
├── metadata: Map<String, dynamic>?
├── retryCount: int
└── executionTime: Duration?

Note: The `data` field may contain a nested `waitingExecution` structure with waiting webhook details when status is "waiting".
```

### 3.2 Complex Form Handling in Practice

#### Multi-Value Fields (Checkboxes)

When `FormFieldType.checkbox` is used with multiple options, the field returns `List<String>` instead of a single value:

```dart
// Example: Checkbox field with multiple selections
final field = FormFieldConfig(
  name: 'interests',
  label: 'Select your interests',
  type: FormFieldType.checkbox,
  options: ['coding', 'design', 'marketing'],
  required: true,
);

// User submits: ['coding', 'design']
final result = field.validate(['coding', 'design']); // ValidationResult<List<String>>
if (result.isValid) {
  print('Selected: ${result.value}'); // ['coding', 'design']
}
```

**Implementation Detail:** Single-value validation returns `ValidationResult<String>`, multi-value returns `ValidationResult<List<String>>`. The validation logic checks if all selected values are in the `options` list.

#### File Upload Handling

File uploads are encoded as base64 strings in the form data:

```dart
// Example: File upload field
final fileField = FormFieldConfig(
  name: 'document',
  label: 'Upload document',
  type: FormFieldType.file,
  required: true,
  metadata: {
    'maxSize': 5242880, // 5MB in bytes
    'acceptedTypes': ['application/pdf', 'image/jpeg', 'image/png'],
  },
);

// Client encodes file to base64
final base64File = base64Encode(fileBytes);
final fileData = {
  'filename': 'document.pdf',
  'mimeType': 'application/pdf',
  'data': base64File, // Base64-encoded file content
};

// Submit to n8n workflow
await client.resumeWorkflow(executionId, {'document': fileData});
```

**Implementation Detail:** Files are transmitted as JSON-compatible base64 strings. Size limits and MIME type checks are performed using `metadata` field. n8n server decodes base64 and processes the file.

#### Multi-Step Workflows with Forms

Each wait node represents a step in a multi-step workflow:

```dart
// Example: Multi-step approval workflow
// Step 1: Initial request form
final execution1 = await client.startWorkflow('approval-webhook', {
  'requestType': 'vacation',
  'days': 5,
});

// Poll until waiting for input
WorkflowExecution exec;
do {
  await Future.delayed(Duration(seconds: 2));
  exec = await client.getExecutionStatus(execution1);
} while (!exec.waitingForInput);

// Step 2: Manager approval form
final managerForm = exec.waitNodeData!; // Contains approval form fields
print('Manager needs to approve: ${managerForm.fields}');

// Manager submits approval
await client.resumeWorkflow(exec.id, {
  'approved': 'true',
  'managerComment': 'Approved for June',
});

// Step 3: HR confirmation form (workflow progresses to next wait node)
do {
  await Future.delayed(Duration(seconds: 2));
  exec = await client.getExecutionStatus(exec.id);
} while (!exec.waitingForInput && !exec.isFinished);

if (exec.waitingForInput) {
  final hrForm = exec.waitNodeData!; // Next form in the workflow
  // HR submits final confirmation...
}
```

**Implementation Detail:** Each `WaitNodeData` represents a form step. The workflow pauses at each wait node, collects user input via `resumeWorkflow()`, then progresses to the next wait node or completes. The `lastNodeExecuted` field tracks which node is currently waiting.

#### Conditional Field Validation

Field validation can check dependencies using the `metadata` field:

```dart
// Example: Conditional validation based on another field
final countryField = FormFieldConfig(
  name: 'country',
  label: 'Country',
  type: FormFieldType.select,
  options: ['US', 'UK', 'CA'],
  required: true,
);

final stateField = FormFieldConfig(
  name: 'state',
  label: 'State',
  type: FormFieldType.select,
  options: ['CA', 'NY', 'TX'],
  required: false,
  metadata: {
    'dependsOn': 'country',
    'showWhen': 'US', // Only required when country is US
  },
);

// Validation logic checks metadata for conditional requirements
bool isRequired(FormFieldConfig field, Map<String, dynamic> allValues) {
  if (field.metadata?['dependsOn'] != null) {
    final dependsOn = field.metadata!['dependsOn'] as String;
    final showWhen = field.metadata!['showWhen'];
    return allValues[dependsOn] == showWhen && field.required;
  }
  return field.required;
}
```

**Implementation Detail:** The `metadata` field provides extensibility for conditional logic. Client applications check `dependsOn` and `showWhen` to determine field visibility and requirements. Validation respects these conditions.

### 3.3 Validation Strategy

All models implement safe parsing with `fromJsonSafe()`:

```dart
static ValidationResult<T> fromJsonSafe(Map<String, dynamic> json) {
  // 1. Validate required fields
  // 2. Parse and validate nested objects
  // 3. Return ValidationResult.success(value) or ValidationResult.failure(errors)
}
```

---

## 4. Configuration System

### 4.1 Configuration Components

```dart
// Environment-aware base configuration
enum N8nEnvironment {
  development,
  staging,
  production
}

// Main configuration
class N8nConfig {
  final String baseUrl;
  final N8nEnvironment environment;
  final LogLevel logLevel;
  final SecurityConfig security;
  final PollingConfig polling;
  final RetryConfig retry;
  final CacheConfig cache;
  final WebhookConfig webhook;
}

// Security configuration
class SecurityConfig {
  final String? apiKey;
  final bool validateSsl;
  final Map<String, String> customHeaders;
  final Duration rateLimitWindow;
  final int rateLimitRequests;
}

// Polling configuration
class PollingConfig {
  final Duration minInterval;
  final Duration maxInterval;
  final Duration inactivityThreshold;
  final bool enableAdaptivePolling;
  final bool enableBackgroundPolling;
}

// Retry configuration
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;
  final List<N8nErrorType> retryableErrors;
}
```

### 4.2 Configuration Profiles

Pre-configured profiles for common use cases:

```dart
class N8nConfigProfiles {
  // Minimal configuration for basic usage
  static N8nConfig minimal({String? baseUrl});

  // High-performance configuration
  static N8nConfig highPerformance({String? baseUrl, String? apiKey});

  // Resilient configuration for unreliable networks
  static N8nConfig resilient({String? baseUrl, String? apiKey});

  // Development configuration with extensive logging
  static N8nConfig development({String? baseUrl});

  // Production configuration with security
  static N8nConfig production({
    required String baseUrl,
    required String apiKey,
    String? signingSecret,
  });

  // Battery-optimized for mobile devices
  static N8nConfig batteryOptimized({String? baseUrl, String? apiKey});
}
```

### 4.3 Builder Pattern

Fluent configuration builder:

```dart
final config = N8nConfigBuilder()
  .baseUrl('https://n8n.example.com')
  .environment(N8nEnvironment.production)
  .logLevel(LogLevel.warning)
  .security(SecurityConfig.production(apiKey: 'key'))
  .polling(PollingConfig.balanced())
  .retry(RetryConfig.aggressive())
  .build();
```

---

## 5. Polling & Monitoring

### 5.1 Smart Polling Manager

```dart
class SmartPollingManager {
  // Activity-aware adaptive polling
  void startPolling(String executionId, Future<void> Function() pollFn);
  void stopPolling(String executionId);
  void recordActivity(String executionId, String activityType);

  // Strategies
  Duration calculateInterval(String executionId);
  bool shouldThrottle(String executionId);
  void adjustPollingFrequency(String executionId, PollingActivity activity);
}
```

### 5.2 Polling Strategies

| Strategy | Min Interval | Max Interval | Use Case |
|----------|--------------|--------------|----------|
| **Minimal** | 10s | 60s | Battery-optimized |
| **Balanced** | 2s | 30s | General purpose |
| **High Frequency** | 500ms | 10s | Real-time apps |
| **Battery Optimized** | 30s | 5min | Mobile apps |

### 5.3 Activity Detection

```dart
enum PollingActivity {
  statusChange,    // Workflow status changed
  dataUpdate,      // Execution data updated
  waitNodeTrigger, // Wait node activated
  noChange,        // No changes detected
  error            // Error occurred
}
```

---

## 6. Error Handling

### 6.1 Error Types

```dart
enum N8nErrorType {
  network,      // Connection failures
  timeout,      // Request timeouts
  serverError,  // 5xx responses
  clientError,  // 4xx responses
  workflow,     // Workflow-specific errors
  validation,   // Data validation errors
  unknown       // Unclassified errors
}
```

### 6.2 N8nException

```dart
class N8nException implements Exception {
  final String message;
  final N8nErrorType type;
  final int? statusCode;
  final Map<String, dynamic>? metadata;
  final bool isRetryable;
  final DateTime timestamp;
}
```

### 6.3 Retry Strategies

| Strategy | Max Retries | Initial Delay | Backoff | Use Case |
|----------|-------------|---------------|---------|----------|
| **Minimal** | 1 | 500ms | 1.5x | Fast-fail |
| **Conservative** | 2 | 1s | 2.0x | Stable networks |
| **Balanced** | 3 | 1s | 2.0x | General purpose |
| **Aggressive** | 5 | 2s | 2.5x | Unreliable networks |

### 6.4 Error Handler

```dart
class N8nErrorHandler {
  Future<T> executeWithRetry<T>(Future<T> Function() operation);
  bool shouldRetry(N8nException error);
  Duration calculateRetryDelay(int attemptNumber);
  void recordError(N8nException error);
  List<N8nException> getErrorHistory();
}
```

---

## 7. Stream Recovery

### 7.1 Resilient Stream Manager

```dart
class ResilientStreamManager<T> {
  final StreamErrorConfig config;
  final T fallbackValue;

  Stream<T> createResilientStream(Stream<T> source);
  void recover(StreamError error);
  void dispose();
}
```

### 7.2 Recovery Strategies

1. **Retry**: Attempt to re-establish stream connection
2. **Fallback**: Emit fallback value and continue
3. **Buffer**: Buffer events during temporary failures
4. **Circuit Breaker**: Stop after consecutive failures, retry later
5. **Graceful Degradation**: Continue with reduced functionality

---

## 8. Flutter Integration

### 8.1 Design Philosophy

The `n8n_dart` package follows a **pure Dart core** design philosophy:

- ✅ **Core Package is Flutter-Agnostic**: Zero Flutter dependencies in core
- ✅ **Maximum Flexibility**: Works with any state management solution
- ✅ **User-Controlled UI**: Developers create their own widgets and UI components
- ✅ **Integration Guidance**: Documentation and examples provided for Flutter integration
- ✅ **RxDart Included**: Reactive streams available for Flutter apps

### 8.2 Flutter Compatibility

The core `N8nClient` works perfectly in Flutter applications:

```dart
import 'package:flutter/material.dart';
import 'package:n8n_dart/n8n_dart.dart';

class WorkflowScreen extends StatefulWidget {
  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  late N8nClient _client;
  WorkflowExecution? _execution;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _client = N8nClient(
      config: N8nConfigProfiles.production(
        baseUrl: 'https://n8n.example.com',
        apiKey: 'your-api-key',
      ),
    );
  }

  Future<void> _startWorkflow() async {
    setState(() => _isLoading = true);

    try {
      final executionId = await _client.startWorkflow(
        'webhook-id',
        {'data': 'value'},
      );

      final execution = await _client.getExecutionStatus(executionId);
      setState(() {
        _execution = execution;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Handle error
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? CircularProgressIndicator()
          : Column(
              children: [
                ElevatedButton(
                  onPressed: _startWorkflow,
                  child: Text('Start Workflow'),
                ),
                if (_execution != null)
                  Text('Status: ${_execution!.status}'),
              ],
            ),
    );
  }
}
```

### 8.3 Reactive Flutter Service (Optional Pattern)

Developers can create their own reactive wrapper using RxDart:

```dart
import 'dart:async';
import 'package:n8n_dart/n8n_dart.dart';
import 'package:rxdart/rxdart.dart';

/// Custom reactive service for Flutter integration
class N8nFlutterService {
  final N8nClient client;
  final BehaviorSubject<WorkflowExecution?> _execution$ =
      BehaviorSubject.seeded(null);
  final BehaviorSubject<bool> _loading$ =
      BehaviorSubject.seeded(false);

  // Public streams
  Stream<WorkflowExecution?> get execution$ => _execution$.stream;
  Stream<bool> get loading$ => _loading$.stream;

  N8nFlutterService({required N8nServiceConfig config})
      : client = N8nClient(config: config);

  Future<void> startWorkflow(
    String webhookId,
    Map<String, dynamic>? data,
  ) async {
    _loading$.add(true);

    try {
      final executionId = await client.startWorkflow(webhookId, data);

      // Start polling for updates
      Timer.periodic(Duration(seconds: 2), (timer) async {
        try {
          final execution = await client.getExecutionStatus(executionId);
          _execution$.add(execution);

          if (execution.isFinished) {
            timer.cancel();
            _loading$.add(false);
          }
        } catch (error) {
          timer.cancel();
          _loading$.add(false);
          _execution$.addError(error);
        }
      });
    } catch (error) {
      _loading$.add(false);
      _execution$.addError(error);
    }
  }

  void dispose() {
    _execution$.close();
    _loading$.close();
    client.dispose();
  }
}
```

### 8.4 Using with StreamBuilder

```dart
class WorkflowWidget extends StatefulWidget {
  @override
  State<WorkflowWidget> createState() => _WorkflowWidgetState();
}

class _WorkflowWidgetState extends State<WorkflowWidget> {
  late N8nFlutterService _service;

  @override
  void initState() {
    super.initState();
    _service = N8nFlutterService(
      config: N8nConfigProfiles.production(
        baseUrl: 'https://n8n.example.com',
        apiKey: 'your-api-key',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<WorkflowExecution?>(
      stream: _service.execution$,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        final execution = snapshot.data!;

        // Handle wait nodes
        if (execution.waitingForInput && execution.waitNodeData != null) {
          return _buildDynamicForm(execution.waitNodeData!);
        }

        // Show status
        return Column(
          children: [
            _StatusIndicator(status: execution.status),
            Text('Duration: ${execution.duration.inSeconds}s'),
          ],
        );
      },
    );
  }

  Widget _buildDynamicForm(WaitNodeData waitNodeData) {
    // Build your custom form using waitNodeData.fields
    return Form(
      child: Column(
        children: waitNodeData.fields.map((field) {
          switch (field.type) {
            case FormFieldType.text:
              return TextFormField(
                decoration: InputDecoration(labelText: field.label),
                validator: (value) {
                  final result = field.validateValue(value);
                  return result.isValid ? null : result.errors.first;
                },
              );
            case FormFieldType.email:
              return TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: field.label),
                validator: (value) {
                  final result = field.validateValue(value);
                  return result.isValid ? null : result.errors.first;
                },
              );
            // Add more field types as needed
            default:
              return TextFormField(
                decoration: InputDecoration(labelText: field.label),
              );
          }
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
```

### 8.5 State Management Integration

The pure Dart core integrates with **any** Flutter state management solution:

#### With Provider

```dart
class N8nProvider extends ChangeNotifier {
  final N8nClient client;
  WorkflowExecution? _execution;
  bool _isLoading = false;

  WorkflowExecution? get execution => _execution;
  bool get isLoading => _isLoading;

  N8nProvider({required N8nServiceConfig config})
      : client = N8nClient(config: config);

  Future<void> startWorkflow(String webhookId, Map<String, dynamic>? data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final executionId = await client.startWorkflow(webhookId, data);
      _execution = await client.getExecutionStatus(executionId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    client.dispose();
    super.dispose();
  }
}
```

#### With Riverpod

```dart
final n8nClientProvider = Provider<N8nClient>((ref) {
  final client = N8nClient(
    config: N8nConfigProfiles.production(
      baseUrl: 'https://n8n.example.com',
      apiKey: 'your-api-key',
    ),
  );
  ref.onDispose(() => client.dispose());
  return client;
});

final workflowExecutionProvider = StreamProvider.autoDispose<WorkflowExecution?>((ref) async* {
  // Your reactive logic here
});
```

#### With BLoC

```dart
class N8nBloc extends Bloc<N8nEvent, N8nState> {
  final N8nClient client;

  N8nBloc({required N8nServiceConfig config})
      : client = N8nClient(config: config),
        super(N8nInitial()) {
    on<StartWorkflowEvent>(_onStartWorkflow);
    on<GetStatusEvent>(_onGetStatus);
  }

  Future<void> _onStartWorkflow(
    StartWorkflowEvent event,
    Emitter<N8nState> emit,
  ) async {
    emit(N8nLoading());
    try {
      final executionId = await client.startWorkflow(
        event.webhookId,
        event.data,
      );
      emit(N8nSuccess(executionId: executionId));
    } catch (e) {
      emit(N8nError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    client.dispose();
    return super.close();
  }
}
```

### 8.6 Why No Built-in Widgets?

**Design Decision Rationale:**

1. **Flexibility** - Developers use different UI frameworks and design systems
2. **Separation of Concerns** - Core logic separate from presentation
3. **No Dependencies** - Avoids coupling with specific UI libraries
4. **State Management Agnostic** - Works with Provider, Riverpod, BLoC, GetX, etc.
5. **Customization** - Every app has unique UI requirements
6. **Package Size** - Keeps core package lightweight
7. **Portability** - Core works in Dart CLI, backend, and Flutter

### 8.7 Integration Summary

| Aspect | Implementation |
|--------|----------------|
| **Core Client** | ✅ Pure Dart, works everywhere |
| **Reactive Streams** | ✅ RxDart included, optional to use |
| **State Management** | ✅ Compatible with all (Provider, Riverpod, BLoC, GetX) |
| **UI Components** | 📝 User creates custom widgets |
| **Example Code** | ✅ Comprehensive examples provided |
| **Documentation** | ✅ Flutter integration guide included |
| **Dynamic Forms** | ✅ FormFieldConfig models provided |
| **Validation** | ✅ Built-in validation helpers |

---

## 9. API Endpoints

Based on n8nui/examples and existing implementation:

| Endpoint | Method | Purpose | Response |
|----------|--------|---------|----------|
| `/api/health` | GET | Health check | `{"status": "ok", "timestamp": "..."}` |
| `/api/validate-webhook/:webhookId` | GET | Validate webhook exists | `{"valid": true/false}` |
| `/api/start-workflow/:webhookId` | POST | Start workflow execution | `{"executionId": "exec_..."}` |
| `/api/execution/:executionId` | GET | Get execution status | `WorkflowExecution` JSON |
| `/api/resume-workflow/:executionId` | POST | Resume paused workflow | `{"success": true}` |
| `/api/cancel-workflow/:executionId` | DELETE | Cancel execution | `{"success": true}` |

---

## 10. Dependencies

### 10.1 Core Dependencies (Dart)

```yaml
dependencies:
  http: ^1.1.0           # HTTP client
  meta: ^1.10.0          # Annotations

dev_dependencies:
  test: ^1.24.0          # Testing
  mockito: ^5.4.0        # Mocking
  build_runner: ^2.4.0   # Code generation
```

### 10.2 Flutter Dependencies

```yaml
dependencies:
  rxdart: ^0.27.7        # Reactive streams
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

---

## 11. Testing Strategy

### 11.1 Test Coverage

- **Unit Tests**: 80%+ coverage for core logic
- **Integration Tests**: API interactions with mock server
- **Widget Tests**: Flutter widgets and forms
- **E2E Tests**: Complete workflow scenarios

### 11.2 Test Structure

```dart
// Model tests
group('WorkflowExecution', () {
  test('fromJsonSafe validates required fields', () {});
  test('isFinished returns true for terminal states', () {});
  test('copyWith creates new instance', () {});
});

// Service tests
group('N8nClient', () {
  late MockHttpClient mockClient;
  late N8nClient client;

  setUp(() {
    mockClient = MockHttpClient();
    client = N8nClient(config, httpClient: mockClient);
  });

  test('startWorkflow returns execution ID', () async {});
  test('getExecutionStatus polls correctly', () async {});
  test('resumeWorkflow sends input data', () async {});
});

// Widget tests
testWidgets('N8nDynamicForm renders fields', (tester) async {});
```

---

## 12. Usage Examples

### 12.1 Pure Dart Example

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  // Initialize client
  final client = N8nClient(
    config: N8nConfigProfiles.development(
      baseUrl: 'http://localhost:5678',
    ),
  );

  // Start workflow
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

    if (execution.waitingForInput) {
      // Handle wait node
      final input = {'userChoice': 'approve'};
      await client.resumeWorkflow(executionId, input);
    }
  }
}
```

### 12.2 Flutter Example

```dart
import 'package:flutter/material.dart';
import 'package:n8n_dart/n8n_dart_flutter.dart';

class WorkflowScreen extends StatefulWidget {
  @override
  State<WorkflowScreen> createState() => _WorkflowScreenState();
}

class _WorkflowScreenState extends State<WorkflowScreen> {
  final _n8nService = locator<N8nService>();
  String? _executionId;

  @override
  void initState() {
    super.initState();
    _startWorkflow();
  }

  Future<void> _startWorkflow() async {
    _executionId = await _n8nService.startWorkflow(
      'onboarding-flow',
      {'userId': '123'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Workflow Monitor')),
      body: StreamBuilder<WorkflowExecution?>(
        stream: _n8nService.execution$,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final execution = snapshot.data!;

          // Show dynamic form for wait nodes
          if (execution.waitingForInput && execution.waitNodeData != null) {
            return N8nDynamicForm(
              waitNodeData: execution.waitNodeData!,
              onSubmit: (data) async {
                await _n8nService.resumeWorkflow(_executionId!, data);
              },
            );
          }

          // Show status
          return Column(
            children: [
              N8nStatusIndicator(status: execution.status),
              Text('Execution ID: ${execution.id}'),
              Text('Duration: ${execution.duration}'),
            ],
          );
        },
      ),
    );
  }
}
```

---

## 13. Implementation Roadmap

### Phase 1: Core Foundation (Week 1-2)
- ✅ Project setup and structure
- ✅ Core models with validation
- ✅ N8nClient implementation
- ✅ Configuration system
- ✅ Unit tests for models

### Phase 2: Advanced Features (Week 3-4)
- ✅ Polling manager with smart strategies
- ✅ Error handler with retry logic
- ✅ Stream recovery manager
- ✅ Integration tests

### Phase 3: Flutter Integration (Week 5-6)
- ⏳ N8nService with reactive streams
- ⏳ Flutter widgets (Form, Listener, Status)
- ⏳ Widget tests
- ⏳ Example Flutter app

### Phase 4: Polish & Documentation (Week 7-8)
- ⏳ Comprehensive documentation
- ⏳ API reference
- ⏳ Tutorial videos
- ⏳ Pub.dev publishing

---

## 14. Performance Considerations

### 14.1 Memory Management

- Dispose streams and timers properly
- Limit polling manager cache size
- Clear completed execution data
- Use weak references for callbacks

### 14.2 Network Optimization

- Connection pooling with http.Client reuse
- Request batching where possible
- Compression for large payloads
- Adaptive polling based on activity

### 14.3 Battery Optimization (Mobile)

- Exponential backoff polling
- Pause polling on app background
- Reduce polling frequency for inactive executions
- Use WorkManager for background tasks

---

## 15. Security Considerations

### 15.1 Authentication

- API key authentication via Bearer token
- Custom header support for advanced auth
- Request signing for sensitive operations
- Token refresh mechanism

### 15.2 Data Protection

- SSL/TLS validation (configurable)
- Sensitive data sanitization in logs
- Secure storage for API keys
- Rate limiting to prevent abuse

### 15.3 Validation

- Input validation for all user data
- JSON schema validation
- Webhook ID format validation
- Execution ID verification

---

## 16. Monitoring & Observability

### 16.1 Metrics

- Execution success/failure rates
- Average execution duration
- Polling efficiency metrics
- Error rates by type
- Network latency tracking

### 16.2 Health Checks

```dart
class N8nServiceHealth {
  final bool isHealthy;
  final String? message;
  final DateTime timestamp;
  final Map<String, dynamic>? metrics;
}
```

### 16.3 Logging Levels

```dart
enum LogLevel {
  none,     // No logging
  error,    // Errors only
  warning,  // Warnings and errors
  info,     // General info
  debug,    // Debug information
  verbose   // Everything
}
```

---

## 17. Migration Guide

### From Existing Implementation to n8n_dart

```dart
// Before (sidegig implementation)
final n8nService = N8nService();
await n8nService.initialize(config);

// After (n8n_dart package)
final n8nClient = N8nClient(config);
// Or for Flutter
final n8nService = N8nService(config);
```

---

## 18. Contributing Guidelines

### 18.1 Code Style

- Follow Dart style guide
- Use effective Dart practices
- Document public APIs
- Write tests for new features

### 18.2 Pull Request Process

1. Fork repository
2. Create feature branch
3. Write tests
4. Update documentation
5. Submit PR with description

### 18.3 Versioning

Follow Semantic Versioning 2.0.0:
- **Major**: Breaking changes
- **Minor**: New features (backward compatible)
- **Patch**: Bug fixes

---

## 19. Future Enhancements

### 19.1 Planned Features

- [ ] WebSocket support for real-time updates
- [ ] Offline execution queue
- [ ] GraphQL API support
- [ ] Webhook registration API
- [ ] Execution history management
- [ ] Multi-workflow orchestration
- [ ] Custom node type support
- [ ] Visual workflow builder (Flutter)

### 19.2 Community Requests

- OpenTelemetry integration
- gRPC transport option
- Desktop app support (macOS, Windows, Linux)
- CLI tool for workflow management

---

## 20. Development Methodology

### Test-Driven Development (TDD) Approach

This project follows strict TDD methodology to ensure code quality, reliability, and maintainability.

#### Red-Green-Refactor Cycle
1. **Red:** Write failing tests first that define expected behavior
2. **Green:** Write minimal code to make tests pass
3. **Refactor:** Improve code quality while keeping tests green

#### Test Coverage Requirements
- **Minimum:** 80% overall code coverage (enforced in CI/CD)
- **Target:** 90%+ coverage for core services (N8nClient, SmartPollingManager, N8nErrorHandler)
- **Critical Paths:** 100% coverage for error handling, validation, and security logic

#### Testing Pyramid
- **Unit Tests (70%):** Fast, isolated tests for individual classes and methods
- **Integration Tests (20%):** Test component interactions (client + polling + error handling)
- **End-to-End Tests (10%):** Full workflow scenarios with mock n8n server

#### Test Organization
```
/test
├── unit/
│   ├── models/          # Model validation, serialization tests
│   ├── services/        # Service logic tests (mocked dependencies)
│   └── configuration/   # Config builder and profile tests
├── integration/
│   ├── client_integration_test.dart
│   └── polling_integration_test.dart
└── e2e/
    └── workflow_lifecycle_test.dart
```

#### Testing Tools & Practices
- **Framework:** `test` package (official Dart testing framework)
- **Mocking:** `mockito` with code generation for clean, type-safe mocks
- **Coverage:** `coverage` package with lcov reports
- **CI/CD:** GitHub Actions running tests on every PR
- **Pre-commit Hooks:** Run tests and linting before commits

#### Quality Gates
- No PR merged without passing tests
- No coverage decrease allowed (ratcheting)
- All public APIs must have comprehensive test coverage
- Edge cases and error paths explicitly tested

#### Benefits of TDD for n8n_dart
- **Reliability:** Catch bugs before users encounter them
- **Refactoring Confidence:** Change code safely with test safety net
- **Documentation:** Tests serve as executable specifications
- **Design Quality:** TDD encourages modular, testable architecture
- **Community Trust:** High test coverage signals production-readiness

---

## 21. License & Acknowledgments

**License**: MIT

**Acknowledgments**:
- n8n.io team for the workflow platform
- n8nui/examples for architectural inspiration
- Flutter and Dart teams
- Open source community

---

## Appendix A: Complete Model Reference

See [n8n_models.dart](lib/src/core/models/) for complete model definitions with:
- ValidationResult<T>
- WorkflowStatus
- FormFieldType
- FormFieldConfig
- WaitNodeData
- WorkflowExecution

## Appendix B: Configuration Reference

See [n8n_configuration.dart](lib/src/core/configuration/) for complete configuration options.

## Appendix C: API Facade

The n8n Flutter facade workflow (from sidegig) provides these endpoints:
- Health check
- Webhook validation
- Workflow start/execution tracking
- Execution status polling
- Workflow resume with input
- Workflow cancellation

This specification aligns with that facade design.

---

## Appendix D: Known n8n API Issues & Workarounds

Based on Gap Analysis Report validation against n8n official API and n8nui/examples:

### Issue 1: Waiting Status Bug (n8n v1.86.1+)
**Problem:** GET `/executions` endpoint doesn't return executions with status "waiting"

**Impact:** Cannot list all waiting executions via standard API

**Workaround:**
- Poll individual execution IDs directly via GET `/execution/{id}`
- Track execution IDs client-side when workflows start
- Monitor for status transition to "waiting" through polling

### Issue 2: Sub-workflow Wait Node Data
**Problem:** Wait nodes in sub-workflows return incorrect data (returns data from node before Wait instead of last node)

**Impact:** Affects workflows that use Execute Workflow node with Wait nodes

**Workaround:**
- Avoid using Wait nodes in sub-workflows when possible
- Use parent workflow Wait nodes instead
- Document limitation for users

### Issue 3: 65-Second Persistence Threshold
**Problem:** Wait times < 65 seconds don't save execution data to database (data stays in memory)

**Impact:** Server restart loses execution state for short waits

**Mitigation:**
- Document behavior for users
- Recommend wait times ≥ 65s for production reliability
- n8n server-side behavior; no client-side fix needed

### Issue 4: "When Last Node Finishes" Response Timing
**Problem:** May not return expected output with Wait nodes in some configurations

**Impact:** Webhook responses may be inconsistent

**Workaround:**
- Use "Respond to Webhook" node for explicit control
- Test response timing in development
- Document recommended response mode for Wait node scenarios

### Priority 1 Implementation Gaps (To Be Addressed)

Per Gap Analysis Report Priority 1 (confirmed by n8nui validation):

1. Add missing FormFieldType values: `password`, `hiddenField`, `html`
2. Add `data.waitingExecution` structure for wait webhook details
3. Add `lastNodeExecuted` to WorkflowExecution model (n8nui uses this)
4. Document known n8n bugs and workarounds (✅ Completed - see Issues 1-4 above)

### Priority 2 Implementation Gaps (High Priority)

Per Gap Analysis Report Priority 2:

5. Add `waitTill` and `stoppedAt` fields for timeout handling
6. Add `resumeUrl` extraction from execution response
7. Handle "waiting" status bug workaround (✅ Documented - see Issue 1 above)
8. Add form field validation aligned with n8n JSON schema

---

**End of Technical Specification**
