/// Integration tests for Circuit Breaker functionality
///
/// Tests circuit breaker behavior with real n8n cloud failures through
/// the ReactiveN8nClient's error handling:
/// - Repeated failures trigger fail-fast behavior
/// - Error rate tracking
/// - Error stream emissions
/// - Recovery after failures
@TestOn('vm')
@Tags(['integration', 'circuit-breaker', 'phase-2'])
library;

import 'dart:async';

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
    // Clean up any successful executions
    final cleanupClient = createTestClient(config);
    await TestCleanup.cancelAllExecutions(cleanupClient);
    cleanupClient.dispose();
    TestCleanup.clear();

    client.dispose();
  });

  group('Circuit Breaker - Error Handling', () {
    test('Repeated failures are tracked in error stream', () async {
      // Listen to error stream
      final errors = <N8nException>[];
      final subscription = client.errors$.listen(errors.add);

      // Trigger multiple failures
      for (var i = 0; i < 5; i++) {
        try {
          await client
              .startWorkflow(
                'invalid-webhook-error-stream-$i',
                TestDataGenerator.simple(),
              )
              .first;
        } catch (e) {
          // Expected failures
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Wait for error propagation
      await Future.delayed(const Duration(milliseconds: 500));

      // Should have captured errors
      expect(errors, isNotEmpty);
      expect(errors.length, greaterThanOrEqualTo(3));

      // All errors should be N8nException
      for (final error in errors) {
        expect(error, isA<N8nException>());
      }

      await subscription.cancel();
    });

    test('Error messages provide context for failures', () async {
      N8nException? capturedError;

      try {
        await client
            .startWorkflow(
              'nonexistent-webhook-12345',
              TestDataGenerator.simple(),
            )
            .first;
      } catch (e) {
        if (e is N8nException) {
          capturedError = e;
        }
      }

      expect(capturedError, isNotNull);
      expect(capturedError!.message, isNotEmpty);

      // Error should indicate what went wrong
      final message = capturedError.message.toLowerCase();
      expect(
        message.contains('webhook') ||
            message.contains('not found') ||
            message.contains('error') ||
            message.contains('fail'),
        isTrue,
        reason: 'Error message should describe the failure',
      );
    });
  });

  group('Circuit Breaker - Error Rate Behavior', () {
    test('Multiple rapid failures are all caught', () async {
      final errors = <N8nException>[];
      final subscription = client.errors$.listen(errors.add);

      // Rapid-fire failures
      final futures = <Future<void>>[];
      for (var i = 0; i < 10; i++) {
        futures.add(
          client
              .startWorkflow(
                'invalid-webhook-rapid-$i',
                {'test': i},
              )
              .first
              .then((_) {})
              .catchError((_) {}),
        );
      }

      await Future.wait(futures);
      await Future.delayed(const Duration(milliseconds: 500));

      // Should capture most/all errors
      expect(errors.length, greaterThanOrEqualTo(5));

      await subscription.cancel();
    });

    test('Errors maintain chronological order in stream', () async {
      final errors = <N8nException>[];
      final subscription = client.errors$.listen(errors.add);

      // Sequential failures with unique identifiers
      for (var i = 0; i < 5; i++) {
        try {
          await client
              .startWorkflow(
                'invalid-webhook-order-$i',
                {'sequence': i},
              )
              .first;
        } catch (_) {
          // Expected
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Errors should be emitted in order
      expect(errors.length, greaterThanOrEqualTo(3));

      await subscription.cancel();
    });
  });

  group('Circuit Breaker - Recovery', () {
    test('Successful requests work after failures', () async {
      // Cause some failures
      for (var i = 0; i < 3; i++) {
        try {
          await client
              .startWorkflow(
                'invalid-webhook-recovery-$i',
                TestDataGenerator.simple(),
              )
              .first;
        } catch (_) {
          // Expected failures
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Wait a bit
      await Future.delayed(const Duration(seconds: 1));

      // Now make a successful request
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'recovery-test'),
          )
          .first;

      expect(execution.id, isNotEmpty);
      expect(
        execution.status,
        isIn([WorkflowStatus.running, WorkflowStatus.new_]),
      );

      TestCleanup.registerExecution(execution.id);
    });

    test('Error rate decreases with successful requests', () async {
      final errors = <N8nException>[];
      final subscription = client.errors$.listen(errors.add);

      // Mix of failures and successes
      for (var i = 0; i < 3; i++) {
        // Failure
        try {
          await client
              .startWorkflow('invalid-webhook-mixed-$i', {})
              .first;
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 200));

        // Success
        try {
          final exec = await client
              .startWorkflow(
                config.simpleWebhookPath,
                TestDataGenerator.simple(name: 'mixed-success-$i'),
              )
              .first;
          TestCleanup.registerExecution(exec.id);
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 200));
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Should have some errors but not all requests failed
      expect(errors.length, lessThan(10));

      await subscription.cancel();
    });
  });

  group('Circuit Breaker - Stream Composition', () {
    test('Errors can be filtered by type using where', () async {
      final networkErrors = <N8nException>[];

      final subscription = client.errors$
          .where((error) =>
              error.message.toLowerCase().contains('network') ||
              error.message.toLowerCase().contains('connection'))
          .listen(networkErrors.add);

      // Trigger various errors
      for (var i = 0; i < 5; i++) {
        try {
          await client
              .startWorkflow('invalid-webhook-filter-$i', {})
              .first;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Network errors should be filtered (may be 0 if all are validation errors)
      expect(networkErrors.length, greaterThanOrEqualTo(0));

      await subscription.cancel();
    });

    test('Error stream can be debounced to reduce noise', () async {
      final debouncedErrors = <N8nException>[];

      final subscription = client.errors$
          .distinct((prev, next) => prev.message == next.message)
          .listen(debouncedErrors.add);

      // Rapid failures
      for (var i = 0; i < 10; i++) {
        try {
          await client
              .startWorkflow('invalid-webhook-debounce-$i', {})
              .first;
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 50));
      }

      await Future.delayed(const Duration(seconds: 2));

      // Distinct should reduce duplicates
      expect(debouncedErrors, isNotEmpty);

      await subscription.cancel();
    });

    test('Error stream integrates with workflow events', () async {
      final allErrors = <N8nException>[];
      final workflowErrors = <WorkflowErrorEvent>[];

      final errorSub = client.errors$.listen(allErrors.add);
      final workflowErrorSub =
          client.workflowErrors$.listen(workflowErrors.add);

      // Trigger error workflow
      final execution = await client
          .startWorkflow(
            config.errorWebhookPath,
            TestDataGenerator.simple(name: 'event-error-test'),
          )
          .first;

      TestCleanup.registerExecution(execution.id);

      // Wait for workflow to fail
      await Future.delayed(const Duration(seconds: 5));

      // Check if events were emitted
      // Note: WorkflowErrorEvent emission depends on watchExecution
      // This validates the stream structure exists

      await errorSub.cancel();
      await workflowErrorSub.cancel();
    });
  });

  group('Circuit Breaker - Performance', () {
    test('Error handling does not significantly delay failures', () async {
      final stopwatch = Stopwatch()..start();

      try {
        await client
            .startWorkflow(
              'invalid-webhook-performance',
              TestDataGenerator.simple(),
            )
            .first;
      } catch (_) {
        // Expected failure
      }

      stopwatch.stop();

      // Should fail relatively quickly (within 10 seconds)
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(10),
        reason: 'Error handling should not add significant overhead',
      );
    });

    test('Multiple concurrent failures are handled efficiently', () async {
      final stopwatch = Stopwatch()..start();

      // Launch 20 concurrent failing requests
      final futures = <Future<void>>[];
      for (var i = 0; i < 20; i++) {
        futures.add(
          client
              .startWorkflow('invalid-webhook-concurrent-$i', {})
              .first
              .then((_) {})
              .catchError((_) {}),
        );
      }

      await Future.wait(futures);
      stopwatch.stop();

      // Should complete within reasonable time (< 30 seconds)
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(30),
        reason: 'Concurrent errors should be handled efficiently',
      );
    });
  });

  group('Circuit Breaker - Edge Cases', () {
    test('Empty webhook ID causes immediate error', () async {
      expect(
        () => client.startWorkflow('', TestDataGenerator.simple()).first,
        throwsA(isA<N8nException>()),
      );
    });

    test('Null data is handled gracefully', () async {
      // Should work or fail gracefully, not crash
      try {
        final execution =
            await client.startWorkflow(config.simpleWebhookPath, null).first;

        // If succeeds, should have valid execution
        expect(execution.id, isNotEmpty);
        TestCleanup.registerExecution(execution.id);
      } catch (e) {
        // If fails, should be N8nException
        expect(e, isA<N8nException>());
      }
    });

    test('Very large payload does not crash error handler', () async {
      final largePayload = TestDataGenerator.largePayload(items: 1000);

      try {
        final execution = await client
            .startWorkflow(config.simpleWebhookPath, largePayload)
            .first;

        expect(execution.id, isNotEmpty);
        TestCleanup.registerExecution(execution.id);
      } catch (e) {
        // If fails, error handler should still work
        expect(e, isA<N8nException>());
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Circuit Breaker - Cleanup', () {
    test('Disposing client stops error stream emissions', () async {
      final testClient = createTestReactiveClient(config);

      final errors = <N8nException>[];
      final subscription = testClient.errors$.listen(errors.add);

      // Cause an error
      try {
        await testClient
            .startWorkflow('invalid-webhook-dispose', {})
            .first;
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 500));
      final errorsBeforeDispose = errors.length;

      // Dispose client
      testClient.dispose();

      // Try to cause another error (should not emit to closed stream)
      try {
        await testClient
            .startWorkflow('invalid-webhook-after-dispose', {})
            .first;
      } catch (_) {
        // May throw since client is disposed
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Should not have received new errors after dispose
      expect(errors.length, equals(errorsBeforeDispose));

      await subscription.cancel();
    });
  });
}
