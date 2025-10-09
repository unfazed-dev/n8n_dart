/// Test helpers for integration tests
///
/// Provides shared utilities for:
/// - n8n client creation
/// - Workflow execution helpers
/// - Test data generators
/// - Cleanup utilities
library;

import 'dart:async';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import '../config/test_config.dart';

/// Creates a configured N8nClient for integration testing
///
/// Uses [TestConfig] to configure the client with proper base URL,
/// API key, and test-appropriate settings.
///
/// Usage:
/// ```dart
/// final client = createTestClient();
/// addTearDown(() => client.dispose());
/// ```
N8nClient createTestClient([TestConfig? config]) {
  config ??= TestConfig.load();

  // Use development profile if no API key, otherwise production
  final clientConfig = config.apiKey != null && config.apiKey!.isNotEmpty
      ? N8nConfigProfiles.production(
          baseUrl: config.baseUrl,
          apiKey: config.apiKey!,
        )
      : N8nConfigProfiles.development(baseUrl: config.baseUrl);

  return N8nClient(config: clientConfig);
}

/// Creates a reactive N8nClient for integration testing
///
/// Uses [TestConfig] to configure the reactive client with proper settings
/// for stream-based operations.
///
/// Usage:
/// ```dart
/// final client = createTestReactiveClient();
/// addTearDown(() => client.dispose());
/// ```
ReactiveN8nClient createTestReactiveClient([TestConfig? config]) {
  config ??= TestConfig.load();

  // Use development profile if no API key, otherwise production
  final clientConfig = config.apiKey != null && config.apiKey!.isNotEmpty
      ? N8nConfigProfiles.production(
          baseUrl: config.baseUrl,
          apiKey: config.apiKey!,
        )
      : N8nConfigProfiles.development(baseUrl: config.baseUrl);

  return ReactiveN8nClient(config: clientConfig);
}

/// Waits for a workflow execution to reach a specific status
///
/// Polls the execution status until it matches [expectedStatus] or times out.
///
/// Usage:
/// ```dart
/// await waitForExecutionStatus(
///   client,
///   executionId,
///   WorkflowStatus.success,
///   timeout: Duration(seconds: 30),
/// );
/// ```
Future<WorkflowExecution> waitForExecutionStatus(
  N8nClient client,
  String executionId,
  WorkflowStatus expectedStatus, {
  Duration timeout = const Duration(seconds: 60),
  Duration pollInterval = const Duration(seconds: 2),
}) async {
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    final execution = await client.getExecutionStatus(executionId);

    if (execution.status == expectedStatus) {
      return execution;
    }

    if (execution.isFinished && execution.status != expectedStatus) {
      throw StateError(
        'Execution finished with status ${execution.status}, '
        'expected $expectedStatus',
      );
    }

    await Future.delayed(pollInterval);
  }

  throw TimeoutException(
    'Timed out waiting for execution $executionId to reach $expectedStatus',
    timeout,
  );
}

/// Waits for a workflow execution to finish (success, error, or canceled)
///
/// Polls until the workflow reaches a terminal state.
///
/// Usage:
/// ```dart
/// final completed = await waitForExecutionCompletion(
///   client,
///   executionId,
/// );
/// expect(completed.isFinished, isTrue);
/// ```
Future<WorkflowExecution> waitForExecutionCompletion(
  N8nClient client,
  String executionId, {
  Duration timeout = const Duration(seconds: 60),
  Duration pollInterval = const Duration(seconds: 2),
}) async {
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    final execution = await client.getExecutionStatus(executionId);

    if (execution.isFinished) {
      return execution;
    }

    await Future.delayed(pollInterval);
  }

  throw TimeoutException(
    'Timed out waiting for execution $executionId to finish',
    timeout,
  );
}

/// Waits for a workflow execution to reach waiting state (wait node)
///
/// Polls until the workflow reaches waiting-for-input state or times out.
///
/// Usage:
/// ```dart
/// final waiting = await waitForWaitingState(
///   client,
///   executionId,
/// );
/// expect(waiting.waitingForInput, isTrue);
/// ```
Future<WorkflowExecution> waitForWaitingState(
  N8nClient client,
  String executionId, {
  Duration timeout = const Duration(seconds: 60),
  Duration pollInterval = const Duration(seconds: 2),
}) async {
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    final execution = await client.getExecutionStatus(executionId);

    if (execution.waitingForInput) {
      return execution;
    }

    if (execution.isFinished) {
      throw StateError(
        'Execution finished without reaching waiting state. '
        'Status: ${execution.status}',
      );
    }

    await Future.delayed(pollInterval);
  }

  throw TimeoutException(
    'Timed out waiting for execution $executionId to reach waiting state',
    timeout,
  );
}

/// Wait for an execution to reach completed state (success, error, or canceled)
///
/// Polls execution status until it reaches a terminal state or timeout occurs
Future<WorkflowExecution> waitForCompletedState(
  N8nClient client,
  String executionId, {
  Duration timeout = const Duration(seconds: 60),
  Duration pollInterval = const Duration(seconds: 2),
}) async {
  final stopwatch = Stopwatch()..start();

  while (stopwatch.elapsed < timeout) {
    final execution = await client.getExecutionStatus(executionId);

    if (execution.isFinished) {
      return execution;
    }

    await Future.delayed(pollInterval);
  }

  throw TimeoutException(
    'Timed out waiting for execution $executionId to complete',
    timeout,
  );
}

/// Test data generator for workflow inputs
class TestDataGenerator {
  /// Generate simple test data
  static Map<String, dynamic> simple({String? name}) {
    return {
      'test': true,
      'timestamp': DateTime.now().toIso8601String(),
      'name': name ?? 'integration-test',
      'data': {
        'value': 42,
        'message': 'Hello from integration test',
      },
    };
  }

  /// Generate form submission data
  static Map<String, dynamic> formData({
    required String name,
    required String email,
    int? age,
  }) {
    return {
      'name': name,
      'email': email,
      if (age != null) 'age': age,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Generate large payload data (for performance testing)
  static Map<String, dynamic> largePayload({int items = 100}) {
    return {
      'items': List.generate(
        items,
        (i) => {
          'id': i,
          'name': 'Item $i',
          'value': i * 10,
          'timestamp': DateTime.now().toIso8601String(),
        },
      ),
    };
  }
}

/// Cleanup utilities for integration tests
class TestCleanup {
  /// List of execution IDs to cleanup
  static final List<String> _executionIds = [];

  /// Register an execution ID for cleanup
  static void registerExecution(String executionId) {
    _executionIds.add(executionId);
  }

  /// Cancel all registered executions
  static Future<void> cancelAllExecutions(N8nClient client) async {
    for (final executionId in _executionIds) {
      try {
        await client.cancelWorkflow(executionId);
      } catch (e) {
        // Ignore errors during cleanup (execution may already be finished)
      }
    }
    _executionIds.clear();
  }

  /// Clear all registered executions without canceling
  static void clear() {
    _executionIds.clear();
  }
}

/// Integration test base class
///
/// Provides common setup/teardown for integration tests.
///
/// Usage:
/// ```dart
/// class MyIntegrationTest extends IntegrationTestBase {
///   @override
///   void defineTests() {
///     test('my test', () async {
///       final execution = await client.startWorkflow(
///         config.simpleWebhookPath,
///         TestDataGenerator.simple(),
///       );
///       registerExecution(execution.id);
///       // ... test logic
///     });
///   }
/// }
/// ```
abstract class IntegrationTestBase {
  late TestConfig config;
  late N8nClient client;

  /// Set up test configuration and client
  void setUp() {
    config = TestConfig.load();

    // Validate configuration
    final errors = config.validate();
    if (errors.isNotEmpty) {
      throw StateError('Invalid test configuration:\n${errors.join('\n')}');
    }

    client = createTestClient(config);
  }

  /// Clean up resources
  Future<void> tearDown() async {
    await TestCleanup.cancelAllExecutions(client);
    client.dispose();
  }

  /// Register execution for cleanup
  void registerExecution(String executionId) {
    TestCleanup.registerExecution(executionId);
  }

  /// Define tests (to be implemented by subclasses)
  void defineTests();

  /// Run all tests
  void run() {
    group(runtimeType.toString(), () {
      setUpAll(setUp);
      tearDownAll(tearDown);
      defineTests();
    });
  }
}

/// Stream matchers for integration tests
class StreamMatchers {
  /// Matcher that checks if a stream emits a value matching [matcher]
  static Matcher emitsValue(Matcher matcher) => emits(matcher);

  /// Matcher that checks if a stream emits in order
  static Matcher emitsInOrderMatcher(List<Matcher> matchers) =>
      emitsInOrder(matchers);

  /// Matcher that checks if a stream emits and then completes
  static Matcher emitsThenDone(Matcher matcher) =>
      emitsInOrder([matcher, emitsDone]);
}

/// Assertion helpers for integration tests
class IntegrationAssertions {
  /// Assert that a workflow execution completed successfully
  static void assertSuccessfulExecution(WorkflowExecution execution) {
    expect(execution.isFinished, isTrue,
        reason: 'Execution should be finished');
    expect(execution.status, WorkflowStatus.success,
        reason: 'Execution should have success status');
    expect(execution.finished, isTrue,
        reason: 'Execution finished flag should be true');
  }

  /// Assert that a workflow execution failed
  static void assertFailedExecution(WorkflowExecution execution) {
    expect(execution.isFinished, isTrue,
        reason: 'Execution should be finished');
    expect(execution.status, WorkflowStatus.error,
        reason: 'Execution should have error status');
    expect(execution.finished, isTrue,
        reason: 'Execution finished flag should be true');
  }

  /// Assert that a workflow execution is waiting for input
  static void assertWaitingForInput(WorkflowExecution execution) {
    expect(execution.waitingForInput, isTrue,
        reason: 'Execution should be waiting for input');
    expect(execution.isFinished, isFalse,
        reason: 'Execution should not be finished while waiting');
  }

  /// Assert that form fields are valid
  static void assertValidFormFields(List<FormFieldConfig> fields) {
    expect(fields, isNotEmpty, reason: 'Form fields should not be empty');

    for (final field in fields) {
      expect(field.name, isNotEmpty,
          reason: 'Field name should not be empty');
      expect(field.type, isNotNull,
          reason: 'Field type should not be null');
    }
  }
}
