@TestOn('vm')
@Tags(['integration', 'workflow'])
library;

import 'dart:io';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import 'config/test_config.dart';
import 'utils/test_helpers.dart';

/// Integration tests for workflow execution lifecycle
///
/// Tests the complete workflow execution lifecycle including:
/// - Starting workflows via webhooks
/// - Polling execution status
/// - Status transitions (new -> running -> success)
/// - Execution data retrieval
/// - Timeout handling
/// - Error handling
/// - Slow workflow execution
///
/// **Requirements:**
/// - .env.test file configured with n8n cloud credentials
/// - Test workflows deployed (simple, slow, error)
/// - n8n cloud instance accessible
/// - Internet connection
///
/// **Test Coverage:**
/// - Basic workflow execution
/// - Status polling and transitions
/// - Successful completion
/// - Error workflow handling
/// - Timeout scenarios
/// - Execution data retrieval
/// - Concurrent execution handling
///
/// **Performance:**
/// - Expected execution time: < 5 minutes total
/// - Individual tests timeout: 30-120 seconds
void main() {
  late TestConfig config;

  setUpAll(() {
    try {
      config = TestConfig.load();
    } on FileSystemException catch (e) {
      fail(
        'Integration test setup failed: ${e.message}\n\n'
        'To run integration tests:\n'
        '1. Copy .env.test.example to .env.test\n'
        '2. Configure your n8n cloud credentials\n'
        '3. See test/integration/README.md for detailed setup',
      );
    } catch (e) {
      fail('Failed to load test configuration: $e');
    }
  });

  group('Basic Workflow Execution', () {
    test('should start workflow and return execution ID', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'basic-execution-test');

      // Act
      final executionId =
          await client.startWorkflow(config.simpleWebhookId, testData);

      // Assert
      expect(executionId, isNotEmpty,
          reason: 'Should return non-empty execution ID');
      expect(executionId.length, greaterThan(10),
          reason: 'Execution ID should be a valid identifier');

      // Register for cleanup
      TestCleanup.registerExecution(executionId);
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('should retrieve execution status after starting workflow', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'status-retrieval-test');

      // Act
      final executionId =
          await client.startWorkflow(config.simpleWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      final execution = await client.getExecutionStatus(executionId);

      // Assert
      expect(execution.id, equals(executionId),
          reason: 'Execution ID should match');
      expect(
          execution.status,
          isIn([
            WorkflowStatus.new_,
            WorkflowStatus.running,
            WorkflowStatus.success,
          ]),
          reason: 'Status should be in valid active or completed state');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('should complete simple workflow successfully', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'complete-workflow-test');

      // Act
      final executionId =
          await client.startWorkflow(config.simpleWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      // Wait for completion
      final completed = await waitForExecutionCompletion(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert
      IntegrationAssertions.assertSuccessfulExecution(completed);
      expect(completed.id, equals(executionId));
      expect(completed.data, isNotNull, reason: 'Should have execution data');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('should track execution data correctly', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'data-tracking-test');

      // Act
      final executionId =
          await client.startWorkflow(config.simpleWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      final completed = await waitForExecutionCompletion(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert
      expect(completed.data, isNotNull, reason: 'Execution should have data');
      expect(completed.workflowId, isNotEmpty,
          reason: 'Should have workflow ID');
      expect(completed.startedAt, isNotNull, reason: 'Should have start time');
      expect(completed.finishedAt, isNotNull,
          reason: 'Should have finish time');
      expect(completed.duration.inMilliseconds, greaterThan(0),
          reason: 'Should have positive execution duration');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Status Transitions', () {
    test('should transition from new/running to success status', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'status-transition-test');

      // Act
      final executionId =
          await client.startWorkflow(config.simpleWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      // Track status transitions
      final statuses = <WorkflowStatus>[];
      var attempts = 0;
      const maxAttempts = 30;

      while (attempts < maxAttempts) {
        final execution = await client.getExecutionStatus(executionId);
        if (!statuses.contains(execution.status)) {
          statuses.add(execution.status);
        }

        if (execution.isFinished) {
          break;
        }

        await Future.delayed(config.pollingInterval);
        attempts++;
      }

      // Assert
      expect(statuses, isNotEmpty, reason: 'Should have at least one status');
      expect(statuses.last, equals(WorkflowStatus.success),
          reason: 'Final status should be success');
      expect(
          statuses,
          anyOf([
            containsAllInOrder([WorkflowStatus.new_, WorkflowStatus.success]),
            containsAllInOrder(
                [WorkflowStatus.running, WorkflowStatus.success]),
            containsAllInOrder([
              WorkflowStatus.new_,
              WorkflowStatus.running,
              WorkflowStatus.success,
            ]),
            equals([WorkflowStatus.success]), // Fast execution
          ]),
          reason: 'Status transitions should follow valid pattern');
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('should detect finished state correctly', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'finished-state-test');

      // Act
      final executionId =
          await client.startWorkflow(config.simpleWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      final completed = await waitForExecutionCompletion(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert
      expect(completed.isFinished, isTrue, reason: 'isFinished should be true');
      expect(completed.finished, isTrue,
          reason: 'finished getter should be true');
      expect(completed.status.isFinished, isTrue,
          reason: 'Status isFinished should be true');
      expect(completed.isActive, isFalse,
          reason: 'Should not be active when finished');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('should handle already completed workflow status check', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'completed-status-check');

      // Act
      final executionId =
          await client.startWorkflow(config.simpleWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      // Wait for completion
      await waitForExecutionCompletion(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Check status again after completion
      final execution = await client.getExecutionStatus(executionId);

      // Assert
      expect(execution.isFinished, isTrue,
          reason: 'Should still be finished on second check');
      expect(execution.status, equals(WorkflowStatus.success),
          reason: 'Status should remain success');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Slow Workflow Execution', () {
    test('should handle slow workflow execution with polling', () async {
      // Skip if configured to skip slow tests
      if (config.skipSlowTests) {
        markTestSkipped('Slow tests disabled in configuration');
        return;
      }

      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'slow-workflow-test');

      // Act
      final executionId =
          await client.startWorkflow(config.slowWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      final stopwatch = Stopwatch()..start();
      final completed = await waitForExecutionCompletion(
        client,
        executionId,
        timeout: Duration(seconds: config.timeoutSeconds),
        pollInterval: config.pollingInterval,
      );
      stopwatch.stop();

      // Assert
      IntegrationAssertions.assertSuccessfulExecution(completed);
      expect(stopwatch.elapsed.inSeconds, greaterThanOrEqualTo(8),
          reason: 'Slow workflow should take at least 8 seconds');
      expect(stopwatch.elapsed.inSeconds, lessThan(config.timeoutSeconds),
          reason: 'Should complete within timeout');
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('should poll multiple times for slow execution', () async {
      // Skip if configured to skip slow tests
      if (config.skipSlowTests) {
        markTestSkipped('Slow tests disabled in configuration');
        return;
      }

      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'polling-count-test');

      // Act
      final executionId =
          await client.startWorkflow(config.slowWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      // Count poll attempts
      var pollCount = 0;
      final stopwatch = Stopwatch()..start();

      while (stopwatch.elapsed < Duration(seconds: config.timeoutSeconds)) {
        final execution = await client.getExecutionStatus(executionId);
        pollCount++;

        if (execution.isFinished) {
          break;
        }

        await Future.delayed(config.pollingInterval);
      }

      // Assert
      expect(pollCount, greaterThanOrEqualTo(3),
          reason: 'Should poll multiple times for slow workflow');
      expect(pollCount, lessThan(60), reason: 'Should not poll excessively');
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('Error Handling', () {
    test('should detect failed workflow execution', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple(name: 'error-workflow-test');

      // Act
      final executionId =
          await client.startWorkflow(config.errorWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      final completed = await waitForExecutionCompletion(
        client,
        executionId,
        timeout: const Duration(seconds: 30),
        pollInterval: config.pollingInterval,
      );

      // Assert
      IntegrationAssertions.assertFailedExecution(completed);
      expect(completed.error, isNotNull,
          reason: 'Failed execution should have error message');
      expect(completed.isFailed, isTrue,
          reason: 'isFailed should be true for error status');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('should handle non-existent execution ID', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      const nonExistentId = 'non-existent-execution-id-12345';

      // Act & Assert
      expect(
        () async => client.getExecutionStatus(nonExistentId),
        throwsA(isA<N8nException>()),
        reason: 'Should throw N8nException for non-existent execution',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('should throw exception for empty webhook ID', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final testData = TestDataGenerator.simple();

      // Act & Assert
      expect(
        () async => client.startWorkflow('', testData),
        throwsA(isA<N8nException>()),
        reason: 'Should throw N8nException for empty webhook ID',
      );
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('should throw exception for empty execution ID', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      // Act & Assert
      expect(
        () async => client.getExecutionStatus(''),
        throwsA(isA<N8nException>()),
        reason: 'Should throw N8nException for empty execution ID',
      );
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('Concurrent Execution', () {
    test('should handle multiple concurrent workflow executions', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      const concurrentCount = 3;
      final testDataList = List.generate(
        concurrentCount,
        (i) => TestDataGenerator.simple(name: 'concurrent-test-$i'),
      );

      // Act - Start all workflows concurrently
      final executionIds = await Future.wait(
        testDataList.map(
          (data) => client.startWorkflow(config.simpleWebhookId, data),
        ),
      );

      // Register for cleanup
      for (final id in executionIds) {
        TestCleanup.registerExecution(id);
      }

      // Wait for all to complete
      final completedExecutions = await Future.wait(
        executionIds.map(
          (id) => waitForExecutionCompletion(
            client,
            id,
            timeout: config.timeout,
            pollInterval: config.pollingInterval,
          ),
        ),
      );

      // Assert
      expect(executionIds.length, equals(concurrentCount),
          reason: 'Should start all workflows');
      expect(completedExecutions.length, equals(concurrentCount),
          reason: 'All workflows should complete');

      for (final execution in completedExecutions) {
        IntegrationAssertions.assertSuccessfulExecution(execution);
      }

      // Verify all executions have unique IDs
      final uniqueIds = executionIds.toSet();
      expect(uniqueIds.length, equals(concurrentCount),
          reason: 'All execution IDs should be unique');
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('should track status for multiple executions independently', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      final data1 = TestDataGenerator.simple(name: 'multi-track-1');
      final data2 = TestDataGenerator.simple(name: 'multi-track-2');

      // Act
      final executionId1 =
          await client.startWorkflow(config.simpleWebhookId, data1);
      final executionId2 =
          await client.startWorkflow(config.simpleWebhookId, data2);

      TestCleanup.registerExecution(executionId1);
      TestCleanup.registerExecution(executionId2);

      // Get status for both
      final status1 = await client.getExecutionStatus(executionId1);
      final status2 = await client.getExecutionStatus(executionId2);

      // Assert
      expect(status1.id, equals(executionId1),
          reason: 'First execution should have correct ID');
      expect(status2.id, equals(executionId2),
          reason: 'Second execution should have correct ID');
      expect(status1.id, isNot(equals(status2.id)),
          reason: 'Executions should have different IDs');
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Cleanup', () {
    test('should cleanup registered executions', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(() async {
        await TestCleanup.cancelAllExecutions(client);
        client.dispose();
      });

      final testData = TestDataGenerator.simple(name: 'cleanup-test');

      // Act
      final executionId =
          await client.startWorkflow(config.simpleWebhookId, testData);
      TestCleanup.registerExecution(executionId);

      // Cleanup should be called by tearDown
      // Assert - Just verify the test completes without errors
      expect(executionId, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
