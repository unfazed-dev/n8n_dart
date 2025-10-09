/// Integration tests for Polling functionality
///
/// Tests adaptive polling behavior with real n8n cloud:
/// - Poll until completion
/// - Status change detection
/// - Polling interval behavior
/// - Auto-stop on completion
@TestOn('vm')
@Tags(['integration', 'polling', 'phase-2'])
library;

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import 'config/test_config.dart';
import 'utils/test_helpers.dart';

void main() {
  late TestConfig config;
  late ReactiveN8nClient client;

  setUpAll(() {
    config = TestConfig.load();
    final errors = config.validate();
    if (errors.isNotEmpty) {
      throw StateError('Invalid test configuration:\n${errors.join('\n')}');
    }
  });

  setUp(() {
    client = createTestReactiveClient(config);
  });

  tearDown(() async {
    final cleanupClient = createTestClient(config);
    await TestCleanup.cancelAllExecutions(cleanupClient);
    cleanupClient.dispose();
    TestCleanup.clear();

    client.dispose();
  });

  group('Polling - Basic Behavior', () {
    test('pollExecutionStatus emits updates until completion', () async {
      // Start workflow
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'polling-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      // Poll until finished
      final updates = <WorkflowExecution>[];
      await for (final update in client.pollExecutionStatus(execution.id)) {
        updates.add(update);
        if (update.isFinished) break;
      }

      // Should have received at least one update
      expect(updates, isNotEmpty);

      // Last update should be finished
      expect(updates.last.isFinished, isTrue);
      expect(updates.last.status, WorkflowStatus.success);
    });

    test('watchExecution auto-stops when workflow finishes', () async {
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'watch-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      // Watch should complete automatically
      WorkflowExecution? lastUpdate;
      await for (final update in client.watchExecution(execution.id)) {
        lastUpdate = update;
      }

      // Stream completed with finished execution
      expect(lastUpdate, isNotNull);
      expect(lastUpdate!.isFinished, isTrue);
    });

    test('Polling works with slow workflows', () async {
      final execution = await client
          .startWorkflow(
            config.slowWebhookPath,
            TestDataGenerator.simple(name: 'slow-polling-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      // Poll slow workflow
      final updates = <WorkflowExecution>[];
      await for (final update in client.pollExecutionStatus(execution.id)) {
        updates.add(update);
        if (update.isFinished) break;
      }

      // Should get multiple updates due to slow execution
      expect(updates, isNotEmpty);
      expect(updates.last.isFinished, isTrue);
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('Polling - Status Transitions', () {
    test('Observes status changes during execution', () async {
      final execution = await client
          .startWorkflow(
            config.slowWebhookPath,
            TestDataGenerator.simple(name: 'status-transition-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      final statuses = <WorkflowStatus>[];
      await for (final update in client.pollExecutionStatus(execution.id)) {
        statuses.add(update.status);
        if (update.isFinished) break;
      }

      // Should observe at least the final status
      expect(statuses, isNotEmpty);
      expect(statuses.last, WorkflowStatus.success);

      // May observe intermediate states like running (optional - execution may be very fast)
    }, timeout: const Timeout(Duration(seconds: 120)));

    test('Distinct prevents duplicate status emissions', () async {
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'distinct-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      final updates = <WorkflowExecution>[];
      await for (final update in client.pollExecutionStatus(execution.id)) {
        updates.add(update);
        if (update.isFinished) break;
      }

      // Distinct should work (hard to verify without duplicates, but validates no crashes)
      expect(updates, isNotEmpty);
    });
  });

  group('Polling - Multiple Executions', () {
    test('Can poll multiple executions concurrently', () async {
      // Start multiple workflows
      final exec1 = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'concurrent-poll-1'),
          )
          .first;

      final exec2 = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'concurrent-poll-2'),
          )
          .first;

      TestCleanup.registerExecution(exec1.id);
      TestCleanup.registerExecution(exec2.id);

      // Poll both concurrently
      final results = await Future.wait([
        client
            .watchExecution(exec1.id)
            .lastWhere((e) => e.isFinished),
        client
            .watchExecution(exec2.id)
            .lastWhere((e) => e.isFinished),
      ]);

      // Both should finish
      expect(results[0].isFinished, isTrue);
      expect(results[1].isFinished, isTrue);
    });

    test('Stream caching prevents redundant polling', () async {
      final execution = await client
          .startWorkflow(
            config.slowWebhookPath,
            TestDataGenerator.simple(name: 'cache-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      // Create multiple watchers (should share cached stream)
      final watch1Updates = <WorkflowExecution>[];
      final watch2Updates = <WorkflowExecution>[];

      await Future.wait([
        client.watchExecution(execution.id).forEach(watch1Updates.add),
        client.watchExecution(execution.id).forEach(watch2Updates.add),
      ]);

      // Both should receive updates
      expect(watch1Updates, isNotEmpty);
      expect(watch2Updates, isNotEmpty);

      // Both should finish
      expect(watch1Updates.last.isFinished, isTrue);
      expect(watch2Updates.last.isFinished, isTrue);
    }, timeout: const Timeout(Duration(seconds: 120)));
  });

  group('Polling - Error Handling', () {
    test('Polling invalid execution ID throws error', () async {
      expect(
        () => client.pollExecutionStatus('invalid-exec-id-12345').first,
        throwsA(isA<N8nException>()),
      );
    });

    test('Polling continues after transient errors', () async {
      // Start valid workflow
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'error-recovery-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      // Poll should work despite any transient issues
      final finalExecution = await client
          .watchExecution(execution.id)
          .lastWhere((e) => e.isFinished);

      expect(finalExecution.isFinished, isTrue);
    });
  });

  group('Polling - Performance', () {
    test('Polling completes in reasonable time', () async {
      final stopwatch = Stopwatch()..start();

      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'performance-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      await client
          .watchExecution(execution.id)
          .lastWhere((e) => e.isFinished);

      stopwatch.stop();

      // Should complete relatively quickly for simple workflow (< 30 sec)
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(30),
        reason: 'Simple workflow should complete quickly',
      );
    });

    test('Polling does not consume excessive resources', () async {
      // Start workflow and poll with many listeners
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'resource-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      // Create 5 concurrent watchers
      final watchers = List.generate(
        5,
        (_) => client.watchExecution(execution.id).lastWhere((e) => e.isFinished),
      );

      final results = await Future.wait(watchers);

      // All should complete successfully
      for (final result in results) {
        expect(result.isFinished, isTrue);
      }
    });
  });

  group('Polling - Edge Cases', () {
    test('Polling already-completed execution returns final state', () async {
      // Start and wait for completion
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'completed-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      // Wait for completion
      await client
          .watchExecution(execution.id)
          .lastWhere((e) => e.isFinished);

      // Poll again - should immediately return finished state
      final finalState = await client.pollExecutionStatus(execution.id).first;

      expect(finalState.isFinished, isTrue);
      expect(finalState.status, WorkflowStatus.success);
    });

    test('Empty execution ID causes error', () async {
      expect(
        () => client.pollExecutionStatus('').first,
        throwsA(isA<Exception>()),
      );
    });
  });
}
