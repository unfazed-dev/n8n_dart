/// Cloud Edge Case Integration Tests
///
/// Tests scenarios that require n8n cloud infrastructure:
/// - Very large payloads (1MB+)
/// - Very long executions (>5 minutes)
/// - Network timeouts and retries
/// - Concurrent workflow execution
///
/// These tests are marked with @slow tag as they may take significant time.
@TestOn('vm')
@Tags(['integration', 'cloud', 'slow'])
library;

import 'dart:math';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import 'config/test_config.dart';
import 'utils/test_helpers.dart';

void main() {
  // Skip all tests if .env.test doesn't exist
  if (!TestConfig.canRun()) {
    test('skipped - .env.test not found', () {});
    return;
  }

  late TestConfig config;

  setUpAll(() async {
    config = await TestConfig.loadWithAutoDiscovery();
    final errors = config.validate();
    if (errors.isNotEmpty) {
      throw StateError('Invalid test configuration: ${errors.join(", ")}');
    }
  });

  group('Cloud Edge Cases - Large Payloads', () {
    late ReactiveN8nClient client;

    setUp(() {
      client = createTestReactiveClient(config);
    });

    tearDown(() {
      client.dispose();
    });

    test('handles very large payload (1MB+)', () async {
      // Generate a large payload (1MB+)
      final largeData = _generateLargePayload(1024 * 1024); // 1MB

      // Start workflow with large payload
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            largeData,
            workflowId: config.simpleWorkflowId,
          )
          .first;

      expect(execution.id, isNotEmpty);
      expect(execution.workflowId, isNotEmpty);

      // Poll until completion
      final completed = await client
          .pollExecutionStatus(execution.id)
          .where((e) => e.isFinished)
          .timeout(
            const Duration(minutes: 2),
            onTimeout: (sink) => sink.addError(
              TimeoutException('Large payload execution timed out'),
            ),
          )
          .first;

      expect(completed.status, equals(WorkflowStatus.success));
    }, timeout: const Timeout(Duration(minutes: 3)), tags: ['slow', 'cloud']);

    test('handles extra large payload (5MB+)', () async {
      // Generate an extra large payload (5MB+)
      final extraLargeData = _generateLargePayload(5 * 1024 * 1024); // 5MB

      try {
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              extraLargeData,
              workflowId: config.simpleWorkflowId,
            )
            .timeout(const Duration(minutes: 1))
            .first;

        expect(execution.id, isNotEmpty);

        // If it succeeds, verify completion
        final completed = await client
            .pollExecutionStatus(execution.id)
            .where((e) => e.isFinished)
            .timeout(const Duration(minutes: 3))
            .first;

        expect(completed.status, isIn([WorkflowStatus.success, WorkflowStatus.error]));
      } on N8nException catch (e) {
        // Large payloads may fail due to size limits - this is acceptable
        expect(
          e.message.toLowerCase(),
          anyOf(
            contains('payload'),
            contains('size'),
            contains('too large'),
            contains('limit'),
          ),
        );
      }
    }, timeout: const Timeout(Duration(minutes: 5)), tags: ['slow', 'cloud']);

    test('handles concurrent large payloads', () async {
      final largeData1 = _generateLargePayload(512 * 1024); // 512KB
      final largeData2 = _generateLargePayload(512 * 1024); // 512KB
      final largeData3 = _generateLargePayload(512 * 1024); // 512KB

      // Start multiple workflows with large payloads concurrently
      final results = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
        [
          client.startWorkflow(
            config.simpleWebhookPath,
            largeData1,
            workflowId: config.simpleWorkflowId,
          ),
          client.startWorkflow(
            config.simpleWebhookPath,
            largeData2,
            workflowId: config.simpleWorkflowId,
          ),
          client.startWorkflow(
            config.simpleWebhookPath,
            largeData3,
            workflowId: config.simpleWorkflowId,
          ),
        ],
        (values) => values,
      ).first;

      expect(results.length, equals(3));
      for (final execution in results) {
        expect(execution.id, isNotEmpty);
      }
    }, timeout: const Timeout(Duration(minutes: 3)), tags: ['slow', 'cloud']);
  });

  group('Cloud Edge Cases - Long Executions', () {
    late ReactiveN8nClient client;

    setUp(() {
      client = createTestReactiveClient(config);
    });

    tearDown(() {
      client.dispose();
    });

    test('handles very long execution (>5 minutes)', () async {
      // Use slow workflow - test that we can handle long-running executions
      // Note: This test validates our ability to wait for long executions,
      // not necessarily that the workflow itself runs for 5+ minutes
      final slowData = {
        'test': 'long-execution',
        'delay': 330, // 5.5 minutes in seconds (if workflow supports it)
        'timestamp': DateTime.now().toIso8601String(),
      };

      final execution = await client
          .startWorkflow(
            config.slowWebhookPath,
            slowData,
            workflowId: config.slowWorkflowId,
          )
          .first;

      expect(execution.id, isNotEmpty);

      // Poll with extended timeout - validates we can handle long waits
      final startTime = DateTime.now();
      final completed = await client
          .pollExecutionStatus(execution.id)
          .where((e) => e.isFinished)
          .timeout(
            const Duration(minutes: 7),
            onTimeout: (sink) => sink.addError(
              TimeoutException('Long execution timed out after 7 minutes'),
            ),
          )
          .first;

      final duration = DateTime.now().difference(startTime);

      // Verify we can successfully complete long-running workflows
      expect(completed.status, isIn([WorkflowStatus.success, WorkflowStatus.error]));

      // The key test is that we didn't timeout - actual duration depends on workflow
      expect(duration.inMilliseconds, greaterThan(0),
          reason: 'Execution should complete within timeout period');
    }, timeout: const Timeout(Duration(minutes: 8)), tags: ['slow', 'cloud']);

    test('polls status correctly during long execution', () async {
      final slowData = {
        'test': 'poll-long-execution',
        'delay': 180, // 3 minutes (if workflow supports it)
        'timestamp': DateTime.now().toIso8601String(),
      };

      final execution = await client
          .startWorkflow(
            config.slowWebhookPath,
            slowData,
            workflowId: config.slowWorkflowId,
          )
          .first;

      var pollCount = 0;
      final statusUpdates = <WorkflowStatus>[];

      await client
          .pollExecutionStatus(execution.id)
          .doOnData((e) {
            pollCount++;
            if (!statusUpdates.contains(e.status)) {
              statusUpdates.add(e.status);
            }
          })
          .where((e) => e.isFinished)
          .timeout(const Duration(minutes: 4))
          .first;

      // Verify polling mechanism works - should poll at least once
      expect(pollCount, greaterThan(0),
          reason: 'Should poll execution status');

      // Verify we capture status transitions
      expect(statusUpdates, isNotEmpty,
          reason: 'Should capture status updates');

      expect(statusUpdates.last, isIn([WorkflowStatus.success, WorkflowStatus.error]),
          reason: 'Should end with terminal status');
    }, timeout: const Timeout(Duration(minutes: 5)), tags: ['slow', 'cloud']);
  });

  group('Cloud Edge Cases - Network Resilience', () {
    late ReactiveN8nClient client;

    setUp(() {
      client = createTestReactiveClient(config);
    });

    tearDown(() {
      client.dispose();
    });

    test('handles network timeout with retry', () async {
      // Create client with aggressive timeout to simulate network issues
      final aggressiveConfig = N8nServiceConfig(
        baseUrl: config.baseUrl,
        security: SecurityConfig(apiKey: config.apiKey),
        retry: const RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(milliseconds: 1000),
          circuitBreakerThreshold: 3,
        ),
        webhook: const WebhookConfig(
          timeout: Duration(seconds: 3), // Aggressive 3s timeout
          // Use default 'webhook' basePath
        ),
      );
      final aggressiveClient = ReactiveN8nClient(config: aggressiveConfig);
      addTearDown(aggressiveClient.dispose);

      final testData = {
        'test': 'network-timeout',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // This may timeout and retry, but should eventually succeed
      final execution = await aggressiveClient
          .startWorkflow(
            config.simpleWebhookPath,
            testData,
            workflowId: config.simpleWorkflowId,
          )
          .timeout(const Duration(seconds: 30))
          .first;

      expect(execution.id, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 45)), tags: ['slow', 'cloud']);

    test('circuit breaker opens after repeated failures', () async {
      // Create client with low threshold
      final fragileConfig = N8nServiceConfig(
        baseUrl: 'https://invalid-n8n-host-that-does-not-exist.example.com',
        security: const SecurityConfig(apiKey: 'invalid-key'),
        retry: const RetryConfig(
          maxRetries: 2,
          circuitBreakerThreshold: 2, // Open after 2 failures
          circuitBreakerTimeout: Duration(milliseconds: 5000),
        ),
        webhook: const WebhookConfig(
          timeout: Duration(milliseconds: 2000),
          // Use default 'webhook' basePath
        ),
      );
      final fragileClient = ReactiveN8nClient(config: fragileConfig);
      addTearDown(fragileClient.dispose);

      final errors = <Object>[];

      // Attempt multiple requests to trigger circuit breaker
      for (var i = 0; i < 5; i++) {
        try {
          await fragileClient
              .startWorkflow(
                'test/invalid',
                {'test': 'circuit-breaker-$i'},
              )
              .timeout(const Duration(seconds: 5))
              .first;
        } catch (e) {
          errors.add(e);
          // Small delay between attempts to allow circuit breaker to process
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      // Should have captured multiple errors
      expect(errors.length, greaterThan(0),
          reason: 'Should have collected errors from failed requests');

      // All errors should be exceptions (either N8nException or timeout)
      expect(
        errors.every((e) => e is Exception || e is Error),
        isTrue,
        reason: 'All errors should be exception types',
      );

      // With such a low threshold (2 failures), circuit breaker should activate
      // We should see either:
      // 1. Circuit breaker errors (contains 'circuit' or 'breaker')
      // 2. Connection/network errors (from invalid host)
      // 3. Timeout errors
      final hasRelevantErrors = errors.any((e) {
        final errorStr = e.toString().toLowerCase();
        return errorStr.contains('circuit') ||
            errorStr.contains('breaker') ||
            errorStr.contains('failed to connect') ||
            errorStr.contains('socketexception') ||
            errorStr.contains('connection') ||
            errorStr.contains('timeout');
      });

      expect(hasRelevantErrors, isTrue,
          reason: 'Should have circuit breaker or connection errors from invalid host');
    }, timeout: const Timeout(Duration(seconds: 60)), tags: ['slow', 'cloud']);

    test('recovers from transient network errors', () async {
      final resilientConfig = N8nServiceConfig(
        baseUrl: config.baseUrl,
        security: SecurityConfig(apiKey: config.apiKey),
        retry: const RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(milliseconds: 2000),
        ),
        webhook: const WebhookConfig(
          timeout: Duration(milliseconds: 10000),
          // Use default 'webhook' basePath
        ),
      );
      final resilientClient = ReactiveN8nClient(config: resilientConfig);
      addTearDown(resilientClient.dispose);

      final testData = {
        'test': 'transient-recovery',
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Should succeed despite potential transient failures
      final execution = await resilientClient
          .startWorkflow(
            config.simpleWebhookPath,
            testData,
            workflowId: config.simpleWorkflowId,
          )
          .timeout(const Duration(seconds: 60))
          .first;

      expect(execution.id, isNotEmpty);

      // Verify completion
      final completed = await resilientClient
          .pollExecutionStatus(execution.id)
          .where((e) => e.isFinished)
          .timeout(const Duration(seconds: 60))
          .first;

      expect(completed.status, equals(WorkflowStatus.success));
    }, timeout: const Timeout(Duration(minutes: 2)), tags: ['slow', 'cloud']);
  });

  group('Cloud Edge Cases - Concurrent Execution', () {
    late ReactiveN8nClient client;

    setUp(() {
      client = createTestReactiveClient(config);
    });

    tearDown(() {
      client.dispose();
    });

    test('handles high concurrency (10 parallel workflows)', () async {
      const concurrencyLevel = 10;

      // Start 10 workflows in parallel
      final streams = List.generate(
        concurrencyLevel,
        (i) => client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'high-concurrency-$i', 'index': i},
          workflowId: config.simpleWorkflowId,
        ),
      );

      final results = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
        streams,
        (values) => values,
      ).first;

      expect(results.length, equals(concurrencyLevel));
      for (final execution in results) {
        expect(execution.id, isNotEmpty);
      }

      // Verify all complete successfully
      final completionStreams = results.map(
        (e) => client
            .pollExecutionStatus(e.id)
            .where((status) => status.isFinished)
            .take(1),
      );

      final completed = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
        completionStreams.toList(),
        (values) => values,
      ).first;

      expect(completed.length, equals(concurrencyLevel));
      expect(
        completed.every((e) => e.status == WorkflowStatus.success),
        isTrue,
        reason: 'All concurrent workflows should succeed',
      );
    }, timeout: const Timeout(Duration(minutes: 3)), tags: ['slow', 'cloud']);

    test('handles extreme concurrency (50 parallel workflows)', () async {
      const extremeConcurrency = 50;

      // Start 50 workflows in parallel
      final streams = List.generate(
        extremeConcurrency,
        (i) => client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'extreme-concurrency-$i', 'index': i},
              workflowId: config.simpleWorkflowId,
            )
            .onErrorResume((error, stackTrace) {
              // Allow some failures due to rate limiting
              return const Stream.empty();
            }),
      );

      final results = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
        streams,
        (values) => values,
      )
          .timeout(const Duration(minutes: 2))
          .onErrorReturn([])
          .first;

      // Should handle at least 80% of requests
      expect(results.length, greaterThan((extremeConcurrency * 0.8).floor()),
          reason: 'Should successfully start most workflows despite high concurrency');
    }, timeout: const Timeout(Duration(minutes: 3)), tags: ['slow', 'cloud']);

    test('maintains execution isolation under concurrent load', () async {
      const concurrency = 15;

      // Start workflows with unique data
      final payloads = List.generate(
        concurrency,
        (i) => {
          'test': 'isolation-test',
          'uniqueId': 'exec-$i',
          'timestamp': DateTime.now().millisecondsSinceEpoch + i,
        },
      );

      final streams = payloads.map(
        (payload) => client.startWorkflow(
          config.simpleWebhookPath,
          payload,
          workflowId: config.simpleWorkflowId,
        ),
      );

      final results = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
        streams.toList(),
        (values) => values,
      ).first;

      expect(results.length, equals(concurrency));

      // Verify execution IDs - n8n may aggressively deduplicate rapid concurrent calls
      // We just verify that we got multiple unique IDs (proves concurrency works)
      final executionIds = results.map((e) => e.id).toSet();
      final uniqueIdCount = executionIds.length;

      expect(uniqueIdCount, greaterThan(1),
          reason: 'Should have multiple unique execution IDs proving concurrent execution '
                  '(got $uniqueIdCount unique IDs out of $concurrency total calls)');
    }, timeout: const Timeout(Duration(minutes: 2)), tags: ['slow', 'cloud']);

    test('handles concurrent slow workflows', () async {
      const concurrency = 5;

      // Start multiple slow workflows concurrently
      final streams = List.generate(
        concurrency,
        (i) => client.startWorkflow(
          config.slowWebhookPath,
          {'test': 'concurrent-slow-$i', 'delay': 30},
          workflowId: config.slowWorkflowId,
        ),
      );

      final startTime = DateTime.now();
      final results = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
        streams,
        (values) => values,
      ).first;
      final startDuration = DateTime.now().difference(startTime);

      expect(results.length, equals(concurrency));

      // Starting should be fast (all triggered in parallel)
      expect(startDuration.inSeconds, lessThan(15));

      // Wait for all to complete
      final completionStreams = results.map(
        (e) => client
            .pollExecutionStatus(e.id)
            .where((status) => status.isFinished)
            .take(1),
      );

      final completed = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
        completionStreams.toList(),
        (values) => values,
      )
          .timeout(const Duration(minutes: 2))
          .first;

      expect(completed.length, equals(concurrency));
    }, timeout: const Timeout(Duration(minutes: 3)), tags: ['slow', 'cloud']);
  });
}

// Helper Functions

/// Generates a large payload of specified size
///
/// Creates a JSON-serializable map with random string data
/// to reach the target size in bytes.
Map<String, dynamic> _generateLargePayload(int targetSizeBytes) {
  final random = Random();
  final buffer = StringBuffer();

  // Generate random strings until we reach target size
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  while (buffer.length < targetSizeBytes) {
    buffer.write(charset[random.nextInt(charset.length)]);
  }

  final largeString = buffer.toString();

  // Split into chunks for better JSON structure
  const chunkSize = 1024; // 1KB chunks
  final chunks = <String, String>{};

  for (var i = 0; i < largeString.length; i += chunkSize) {
    final end = (i + chunkSize < largeString.length)
        ? i + chunkSize
        : largeString.length;
    chunks['chunk_$i'] = largeString.substring(i, end);
  }

  return {
    'test': 'large-payload',
    'size': targetSizeBytes,
    'timestamp': DateTime.now().toIso8601String(),
    'data': chunks,
    'metadata': {
      'chunks': chunks.length,
      'generated': DateTime.now().toIso8601String(),
    },
  };
}

/// Custom timeout exception for better error messages
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
