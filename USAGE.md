# n8n_dart Usage Guide

**Version:** 1.0.0
**Date:** October 4, 2025

---

## 📖 Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Quick Start](#quick-start)
4. [Core Features](#core-features)
5. [Workflow Generator](#workflow-generator)
6. [Configuration](#configuration)
7. [Advanced Usage](#advanced-usage)
8. [Examples](#examples)
9. [API Reference](#api-reference)

---

## 🎯 Introduction

**n8n_dart** is a comprehensive Dart package that provides two main capabilities:

1. **Runtime Integration**: Execute and monitor n8n workflows programmatically
2. **Workflow Generation**: Create n8n workflow JSON files using Dart code

### Key Features

- ✅ Type-safe workflow execution and monitoring
- ✅ Reactive streams with RxDart for real-time updates
- ✅ Smart polling with adaptive intervals
- ✅ Comprehensive error handling and retry strategies
- ✅ Dynamic form handling for Wait nodes
- ✅ Workflow generator with fluent API
- ✅ 8 pre-built workflow templates
- ✅ 16 example workflows covering diverse use cases
- ✅ 99.7% test coverage
- ✅ Works with pure Dart and Flutter applications

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  n8n_dart: ^1.0.0
```

Then run:

```bash
dart pub get
# or for Flutter
flutter pub get
```

---

## 🚀 Quick Start

### 1. Runtime Integration - Execute Workflows

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  // Configure client
  final config = N8nServiceConfig(
    baseUrl: 'https://your-n8n-instance.com',
    webhookId: 'your-webhook-id',
  );

  // Create client
  final client = N8nClient(config);

  try {
    // Start a workflow
    final executionId = await client.startWorkflow({
      'name': 'John Doe',
      'email': 'john@example.com',
    });

    print('Workflow started: $executionId');

    // Monitor execution status
    final execution = await client.getExecutionStatus(executionId);
    print('Status: ${execution.status}');

    // Handle wait nodes (if workflow pauses for input)
    if (execution.waitingForInput) {
      print('Workflow is waiting for input');
      // Resume with user input
      await client.resumeWorkflow(executionId, {
        'userChoice': 'approved',
      });
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

### 2. Workflow Generator - Create Workflows

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  // Build a workflow using fluent API
  final workflow = WorkflowBuilder.create()
      .name('User Registration')
      .tags(['auth', 'users'])
      .active(true)
      .webhookTrigger(
        name: 'Register Webhook',
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
        toEmail: r'={{$json.email}}',
        subject: 'Welcome!',
        message: 'Thanks for registering!',
      )
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 201,
        responseBody: {'status': 'success'},
      )
      .connectSequence([
        'Register Webhook',
        'Save User',
        'Welcome Email',
        'Return Success',
      ])
      .build();

  // Export to JSON file
  await workflow.saveToFile('user_registration.json');

  print('Workflow generated! Import into n8n.');
}
```

---

## 🎨 Core Features

### 1. Workflow Execution

Start and monitor n8n workflows:

```dart
final client = N8nClient(config);

// Start workflow with data
final executionId = await client.startWorkflow({
  'orderId': '12345',
  'items': ['item1', 'item2'],
  'total': 99.99,
});

// Get execution status
final execution = await client.getExecutionStatus(executionId);

print('Status: ${execution.status}');
print('Finished: ${execution.finished}');
print('Waiting: ${execution.waitingForInput}');
```

### 2. Reactive Monitoring with Streams

Monitor workflow execution in real-time:

```dart
final manager = N8nStreamManager(client, config);

// Create a reactive stream
final stream = manager.createExecutionStream(
  executionId,
  onWaitDetected: (waitData) {
    print('Workflow paused - waiting for input');
    print('Form fields: ${waitData.formFields}');
  },
);

// Listen to status updates
stream.listen(
  (execution) {
    print('Status: ${execution.status}');
    if (execution.finished) {
      print('Workflow completed!');
    }
  },
  onError: (error) => print('Error: $error'),
  onDone: () => print('Stream closed'),
);
```

### 3. Smart Polling

Adaptive polling that adjusts intervals based on workflow activity:

```dart
final config = N8nServiceConfig(
  baseUrl: 'https://your-n8n.com',
  webhookId: 'webhook-id',
  pollingConfig: PollingConfig(
    strategy: PollingStrategy.smart,
    baseInterval: Duration(seconds: 2),
    maxInterval: Duration(seconds: 30),
    timeout: Duration(minutes: 10),
  ),
);
```

**Polling Strategies:**
- `fixed`: Consistent interval
- `adaptive`: Slows down for idle workflows
- `smart`: Activity-aware with throttling
- `hybrid`: Best of adaptive + smart

### 4. Error Handling

Robust error handling with retry strategies:

```dart
final errorHandler = N8nErrorHandler(
  retryConfig: RetryConfig(
    maxRetries: 3,
    strategy: RetryStrategy.exponentialBackoff,
    baseDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
  ),
);

// Wrap API calls with error handling
final result = await errorHandler.executeWithRetry(
  () => client.startWorkflow(data),
  operation: 'startWorkflow',
);
```

**Retry Strategies:**
- `noRetry`: Fail immediately
- `fixed`: Fixed delay between retries
- `exponentialBackoff`: Exponentially increasing delays
- `linearBackoff`: Linearly increasing delays
- `jitterBackoff`: Random jitter to prevent thundering herd

### 5. Wait Node Handling

Handle workflows that pause for user input:

```dart
final execution = await client.getExecutionStatus(executionId);

if (execution.waitingForInput) {
  // Get form fields
  final formFields = execution.waitNodeData?.formFields ?? [];

  // Display form to user and collect input
  final userInput = {
    'name': 'John Doe',
    'email': 'john@example.com',
    'approve': true,
  };

  // Resume workflow with user input
  await client.resumeWorkflow(executionId, userInput);
}
```

**Supported Form Field Types (18 total):**
- Text, Email, Number, Date
- Dropdown, Checkbox, Radio, Toggle
- Textarea, Password, Hidden
- File Upload, Color Picker
- DateTime, Time, HTML
- Custom Fields

---

## 🔧 Workflow Generator

Create n8n workflows programmatically using a fluent API.

### Basic Workflow

```dart
final workflow = WorkflowBuilder.create()
    .name('Simple API')
    .webhookTrigger(name: 'Start', path: 'api/endpoint')
    .httpRequest(
      name: 'Call API',
      url: 'https://api.example.com/data',
      method: 'GET',
    )
    .postgres(
      name: 'Save to DB',
      operation: 'insert',
      table: 'api_responses',
    )
    .respondToWebhook(name: 'Response', responseCode: 200)
    .connectSequence(['Start', 'Call API', 'Save to DB', 'Response'])
    .build();

await workflow.saveToFile('simple_api.json');
```

### Pre-built Templates

Use ready-made templates for common patterns:

```dart
// CRUD API
final crudWorkflow = WorkflowTemplates.crudApi(
  resourceName: 'users',
  tableName: 'users',
);

// Order Processing
final orderWorkflow = WorkflowTemplates.orderProcessing(
  notificationEmail: 'orders@example.com',
);

// File Upload
final uploadWorkflow = WorkflowTemplates.fileUpload(
  s3Bucket: 'my-bucket',
);

// User Registration
final registrationWorkflow = WorkflowTemplates.userRegistration(
  fromEmail: 'noreply@example.com',
);

// Scheduled Report
final reportWorkflow = WorkflowTemplates.scheduledReport(
  reportName: 'Sales',
  recipients: 'team@example.com',
  schedule: '0 9 * * 1', // Every Monday at 9 AM
);

// Data Sync
final syncWorkflow = WorkflowTemplates.dataSync(
  sourceName: 'PostgreSQL',
  targetName: 'MongoDB',
);

// Multi-step Form
final formWorkflow = WorkflowTemplates.multiStepForm(
  tableName: 'onboarding',
);

// Webhook Logger
final loggerWorkflow = WorkflowTemplates.webhookLogger(
  spreadsheetId: 'spreadsheet-123',
);
```

### Available Node Types

```dart
// Triggers
.webhookTrigger()      // HTTP webhook trigger
.scheduleTrigger()     // Cron-based trigger

// Actions
.httpRequest()         // HTTP API calls
.postgres()           // PostgreSQL operations
.mongodb()            // MongoDB operations
.emailSend()          // Send emails
.slack()              // Slack notifications
.stripe()             // Stripe payments
.googleSheets()       // Google Sheets operations
.awsS3()              // AWS S3 file operations

// Logic
.function()           // JavaScript/TypeScript code
.ifNode()             // Conditional branching
.setNode()            // Set variables
.waitNode()           // Pause for duration or input

// Response
.respondToWebhook()   // Return HTTP response
```

### Complex Workflows with Branching

```dart
final workflow = WorkflowBuilder.create()
    .name('Order Validation')
    .webhookTrigger(name: 'Order', path: 'orders')
    .function(
      name: 'Validate',
      code: r'''
        const order = $input.item.json;
        return {
          ...order,
          isValid: order.total > 0 && order.items.length > 0
        };
      ''',
    )
    .ifNode(
      name: 'Is Valid?',
      conditions: [
        {
          'leftValue': r'={{$json.isValid}}',
          'operation': 'equals',
          'rightValue': true,
        }
      ],
    )
    // Valid path
    .postgres(name: 'Save Order', operation: 'insert', table: 'orders')
    .emailSend(
      name: 'Confirm',
      fromEmail: 'orders@example.com',
      toEmail: r'={{$json.email}}',
      subject: 'Order Confirmed',
    )
    // Invalid path
    .newRow()
    .respondToWebhook(
      name: 'Error Response',
      responseCode: 400,
      responseBody: {'error': 'Invalid order'},
    )
    // Connect nodes
    .connect('Order', 'Validate')
    .connect('Validate', 'Is Valid?')
    .connect('Is Valid?', 'Save Order', sourceIndex: 0)
    .connect('Save Order', 'Confirm')
    .connect('Is Valid?', 'Error Response', sourceIndex: 1)
    .build();
```

---

## ⚙️ Configuration

### Service Profiles

Use pre-configured profiles for different environments:

```dart
// Development - Fast polling, verbose logging
final devConfig = N8nConfigProfiles.development(
  baseUrl: 'http://localhost:5678',
  webhookId: 'dev-webhook',
);

// Production - Conservative, resilient
final prodConfig = N8nConfigProfiles.production(
  baseUrl: 'https://n8n.example.com',
  webhookId: 'prod-webhook',
);

// Resilient - Maximum reliability
final resilientConfig = N8nConfigProfiles.resilient(
  baseUrl: 'https://n8n.example.com',
  webhookId: 'webhook-id',
);

// Performance - Fast, aggressive
final perfConfig = N8nConfigProfiles.performance(
  baseUrl: 'https://n8n.example.com',
  webhookId: 'webhook-id',
);

// Testing - Minimal timeouts
final testConfig = N8nConfigProfiles.testing(
  baseUrl: 'http://localhost:5678',
  webhookId: 'test-webhook',
);

// Debugging - Maximum logging
final debugConfig = N8nConfigProfiles.debugging(
  baseUrl: 'http://localhost:5678',
  webhookId: 'debug-webhook',
);
```

### Custom Configuration

```dart
final config = N8nConfigBuilder()
    .environment(N8nEnvironment.production)
    .baseUrl('https://your-n8n.com')
    .webhookId('webhook-id')
    .apiKey('your-api-key')
    .timeout(Duration(minutes: 10))
    .pollingInterval(Duration(seconds: 5))
    .maxRetries(3)
    .logLevel(LogLevel.info)
    .enableCaching(true)
    .enableCircuitBreaker(true)
    .build();
```

---

## 🎯 Advanced Usage

### 1. Canceling Workflows

```dart
// Cancel a running workflow
final success = await client.cancelWorkflow(executionId);
if (success) {
  print('Workflow canceled');
}
```

### 2. Polling Metrics

Track polling performance:

```dart
final pollingManager = PollingManager(PollingConfig());

pollingManager.startPolling(executionId, () async {
  final execution = await client.getExecutionStatus(executionId);
  pollingManager.recordActivity(executionId, execution.status);
});

// Get metrics
final metrics = pollingManager.getMetrics(executionId);
print('Total polls: ${metrics?.totalPolls}');
print('Success rate: ${metrics?.successRate}');
print('Avg interval: ${metrics?.averageInterval}');
```

### 3. Stream Recovery

Automatic recovery from stream interruptions:

```dart
final manager = N8nStreamManager(
  client,
  config,
  enableRecovery: true,
  maxRecoveryAttempts: 3,
);

final stream = manager.createExecutionStream(executionId);

// Stream automatically recovers from network issues
stream.listen((execution) {
  print('Status: ${execution.status}');
});
```

### 4. Circuit Breaker

Prevent cascading failures:

```dart
final circuitBreaker = CircuitBreaker(
  failureThreshold: 5,
  recoveryTimeout: Duration(seconds: 30),
);

// Wrap operations
await circuitBreaker.execute(() async {
  return await client.startWorkflow(data);
});
```

### 5. Batch Workflow Generation

Generate multiple workflows programmatically:

```dart
final tenants = [
  {'name': 'TenantA', 'table': 'tenant_a_users'},
  {'name': 'TenantB', 'table': 'tenant_b_users'},
  {'name': 'TenantC', 'table': 'tenant_c_users'},
];

for (final tenant in tenants) {
  final workflow = WorkflowTemplates.crudApi(
    resourceName: tenant['name']!,
    tableName: tenant['table']!,
  );

  await workflow.saveToFile('workflows/${tenant['name']}_api.json');
  print('Generated workflow for ${tenant['name']}');
}
```

---

## 📚 Examples

### Example 1: IoT Sensor Data Processing

```dart
final workflow = WorkflowBuilder.create()
    .name('IoT Sensor Pipeline')
    .tags(['iot', 'sensors'])
    .webhookTrigger(name: 'Sensor Data', path: 'iot/data')
    .function(
      name: 'Validate',
      code: r'''
        const data = $input.item.json;
        return {
          ...data,
          isValid: data.temperature !== undefined && data.humidity !== undefined
        };
      ''',
    )
    .postgres(name: 'Store Reading', operation: 'insert', table: 'sensor_data')
    .ifNode(
      name: 'Alert Threshold?',
      conditions: [
        {
          'leftValue': r'={{$json.temperature}}',
          'operation': 'larger',
          'rightValue': 30,
        }
      ],
    )
    .slack(
      name: 'Send Alert',
      channel: '#iot-alerts',
      text: r'🚨 High temperature: {{$json.temperature}}°C',
    )
    .respondToWebhook(name: 'Response')
    .connectSequence(['Sensor Data', 'Validate', 'Store Reading', 'Alert Threshold?'])
    .connect('Alert Threshold?', 'Send Alert', sourceIndex: 0)
    .connect('Alert Threshold?', 'Response', sourceIndex: 1)
    .build();
```

### Example 2: Booking System with Invoicing

```dart
// Create booking workflow
final bookingWorkflow = WorkflowBuilder.create()
    .name('Appointment Booking')
    .webhookTrigger(name: 'Book', path: 'bookings/create')
    .postgres(name: 'Check Availability', operation: 'select', table: 'appointments')
    .ifNode(name: 'Slot Available?', conditions: [...])
    .postgres(name: 'Save Booking', operation: 'insert', table: 'appointments')
    .emailSend(name: 'Confirmation', fromEmail: 'bookings@example.com')
    .build();

// Create invoice workflow (triggered after booking)
final invoiceWorkflow = WorkflowBuilder.create()
    .name('Invoice Generation')
    .webhookTrigger(name: 'Generate Invoice', path: 'invoices/generate')
    .postgres(name: 'Get Booking', operation: 'select', table: 'appointments')
    .function(name: 'Calculate Total', code: r'...')
    .postgres(name: 'Save Invoice', operation: 'insert', table: 'invoices')
    .emailSend(name: 'Send Invoice', fromEmail: 'billing@example.com')
    .slack(name: 'Notify Team', channel: '#billing')
    .build();
```

### Example 3: Real-time Chat with Moderation

```dart
final chatWorkflow = WorkflowBuilder.create()
    .name('Chat Message Handler')
    .webhookTrigger(name: 'New Message', path: 'chat/message')
    .postgres(name: 'Save Message', operation: 'insert', table: 'messages')
    .function(
      name: 'Content Moderation',
      code: r'''
        const msg = $input.item.json;
        const badWords = ['spam', 'abuse'];
        return {
          ...msg,
          flagged: badWords.some(word => msg.content.toLowerCase().includes(word))
        };
      ''',
    )
    .ifNode(
      name: 'Needs Review?',
      conditions: [
        {'leftValue': r'={{$json.flagged}}', 'operation': 'equals', 'rightValue': true}
      ],
    )
    .slack(name: 'Alert Moderators', channel: '#moderation')
    .respondToWebhook(name: 'Broadcast')
    .build();
```

---

## 📖 API Reference

### N8nClient

Main client for workflow execution:

```dart
// Constructor
N8nClient(N8nServiceConfig config)

// Methods
Future<String> startWorkflow(Map<String, dynamic> data)
Future<WorkflowExecution> getExecutionStatus(String executionId)
Future<bool> resumeWorkflow(String executionId, Map<String, dynamic> data)
Future<bool> cancelWorkflow(String executionId)
```

### WorkflowBuilder

Fluent API for building workflows:

```dart
// Basic
WorkflowBuilder.create()
.name(String name)
.active([bool isActive = true])
.tags(List<String> tags)
.version(double version)

// Nodes
.node({required String name, required String type, Map<String, dynamic> parameters})
.webhookTrigger({required String name, required String path, String method = 'POST'})
.httpRequest({required String name, required String url, String method = 'GET'})
.postgres({required String name, required String operation, String? table})
.emailSend({required String name, String? fromEmail, String? toEmail})
.function({required String name, required String code})
.ifNode({required String name, required List<Map> conditions})
.slack({required String name, required String channel, required String text})

// Connections
.connect(String source, String target, {int sourceIndex = 0, int targetIndex = 0})
.connectSequence(List<String> nodeNames)

// Build
N8nWorkflow build()
String buildJson()
Future<void> buildAndSave(String filePath)
```

### WorkflowTemplates

Pre-built workflow templates:

```dart
static N8nWorkflow crudApi({required String resourceName, required String tableName})
static N8nWorkflow userRegistration({required String fromEmail})
static N8nWorkflow fileUpload({required String s3Bucket})
static N8nWorkflow orderProcessing({required String notificationEmail})
static N8nWorkflow multiStepForm({required String tableName})
static N8nWorkflow scheduledReport({required String reportName, required String recipients, String? schedule})
static N8nWorkflow dataSync({required String sourceName, required String targetName})
static N8nWorkflow webhookLogger({required String spreadsheetId})
```

---

## 🆘 Support

- **Documentation**: See `/docs` folder
- **Examples**: See `/example` folder
- **Issues**: [GitHub Issues](https://github.com/yourusername/n8n_dart/issues)
- **n8n Docs**: [n8n.io/docs](https://docs.n8n.io)

---

## 📄 License

MIT License - see LICENSE file for details.
