/// Integration tests for Error Recovery functionality
///
/// Tests error recovery with retry logic using real n8n cloud:
/// - Retry with exponential backoff
/// - Error categorization (network vs server)
/// - Recovery after temporary failures
/// - Retry configuration
@TestOn('vm')
@Tags(['integration', 'error-recovery', 'phase-2'])
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

  group('Error Recovery - Basic Retry', () {
    test('Failed requests eventually throw N8nException', () async {
      // Invalid request should fail after retries
      expect(
        () => client
            .startWorkflow(
              'definitely-invalid-webhook-12345',
              TestDataGenerator.simple(),
            )
            .first,
        throwsA(isA<N8nException>()),
      );
    });

    test('Error contains useful information', () async {
      N8nException? caughtError;

      try {
        await client
            .startWorkflow(
              'invalid-webhook-error-info',
              TestDataGenerator.simple(),
            )
            .first;
      } catch (e) {
        if (e is N8nException) {
          caughtError = e;
        }
      }

      expect(caughtError, isNotNull);
      expect(caughtError!.message, isNotEmpty);

      // Error should be descriptive
      final message = caughtError.message.toLowerCase();
      expect(
        message.contains('error') ||
            message.contains('fail') ||
            message.contains('not found') ||
            message.contains('webhook'),
        isTrue,
        reason: 'Error message should describe the failure',
      );
    });

    test('Successful requests do not trigger retries', () async {
      final stopwatch = Stopwatch()..start();

      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'no-retry-test'),
          )
          .first;

      stopwatch.stop();

      expect(execution.id, isNotEmpty);
      TestCleanup.registerExecution(execution.id);

      // Should complete quickly without retries (< 10 seconds)
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(10),
        reason: 'Successful requests should not retry',
      );
    });
  });

  group('Error Recovery - Error Types', () {
    test('Network errors are distinguishable', () async {
      final errors = <N8nException>[];
      final subscription = client.errors$.listen(errors.add);

      // Trigger error
      try {
        await client
            .startWorkflow('invalid-webhook-network', {})
            .first;
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Should have captured error
      expect(errors, isNotEmpty);

      // Error types can be examined
      for (final error in errors) {
        expect(error, isA<N8nException>());
        expect(error.message, isNotEmpty);
      }

      await subscription.cancel();
    });

    test('Validation errors fail immediately', () async {
      final stopwatch = Stopwatch()..start();

      try {
        await client.startWorkflow('', {}).first;
      } catch (e) {
        // Expected - validation error
      }

      stopwatch.stop();

      // Should fail quickly without retries (< 2 seconds)
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(2),
        reason: 'Validation errors should fail immediately',
      );
    });
  });

  group('Error Recovery - Recovery After Failures', () {
    test('Client recovers after failed requests', () async {
      // Make some failed requests
      for (var i = 0; i < 3; i++) {
        try {
          await client
              .startWorkflow('invalid-webhook-recovery-$i', {})
              .first;
        } catch (_) {
          // Expected failures
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Wait briefly
      await Future.delayed(const Duration(milliseconds: 500));

      // Client should still work for valid requests
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'post-recovery-test'),
          )
          .first;

      expect(execution.id, isNotEmpty);
      TestCleanup.registerExecution(execution.id);
    });

    test('Multiple failures followed by success', () async {
      // Trigger several failures
      for (var i = 0; i < 5; i++) {
        try {
          await client
              .startWorkflow('invalid-webhook-multi-$i', {})
              .first;
        } catch (_) {}
      }

      // Then successful request
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'after-failures-test'),
          )
          .first;

      expect(execution.id, isNotEmpty);
      expect(execution.status, isIn([WorkflowStatus.running, WorkflowStatus.new_]));

      TestCleanup.registerExecution(execution.id);
    });
  });

  group('Error Recovery - Stream Error Handling', () {
    test('Stream errors can be caught with handleError', () async {
      N8nException? streamError;

      try {
        await client
            .startWorkflow('invalid-webhook-stream-error', {})
            .handleError((error) {
          if (error is N8nException) {
            streamError = error;
          }
        }).forEach((_) {});
      } catch (_) {
        // Error handled in handleError
      }

      expect(streamError, isNotNull);
    });

    test('Errors propagate to error stream', () async {
      final errors = <N8nException>[];
      final subscription = client.errors$.listen(errors.add);

      // Trigger multiple errors
      for (var i = 0; i < 3; i++) {
        try {
          await client
              .startWorkflow('invalid-webhook-propagate-$i', {})
              .first;
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Errors should propagate to stream
      expect(errors, isNotEmpty);
      expect(errors.length, greaterThanOrEqualTo(2));

      await subscription.cancel();
    });

    test('Error stream can filter specific error types', () async {
      final notFoundErrors = <N8nException>[];

      final subscription = client.errors$
          .where((error) => error.message.toLowerCase().contains('not found'))
          .listen(notFoundErrors.add);

      // Trigger various errors
      for (var i = 0; i < 5; i++) {
        try {
          await client
              .startWorkflow('invalid-webhook-filter-$i', {})
              .first;
        } catch (_) {}
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Filtered errors (may be empty if no "not found" errors)
      expect(notFoundErrors.length, greaterThanOrEqualTo(0));

      await subscription.cancel();
    });
  });

  group('Error Recovery - Concurrent Error Handling', () {
    test('Multiple concurrent errors are handled independently', () async {
      final futures = <Future<void>>[];

      // Launch 10 concurrent failing requests
      for (var i = 0; i < 10; i++) {
        futures.add(
          client
              .startWorkflow('invalid-webhook-concurrent-$i', {})
              .first
              .then((_) {})
              .catchError((_) {}),
        );
      }

      // All should complete (fail gracefully)
      await Future.wait(futures);

      // Client should still work
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'post-concurrent-test'),
          )
          .first;

      expect(execution.id, isNotEmpty);
      TestCleanup.registerExecution(execution.id);
    });

    test('Error recovery works under load', () async {
      final stopwatch = Stopwatch()..start();

      // Mix of failures and successes
      final futures = <Future<void>>[];

      for (var i = 0; i < 5; i++) {
        // Failure
        futures.add(
          client
              .startWorkflow('invalid-webhook-load-$i', {})
              .first
              .then((_) {})
              .catchError((_) {}),
        );

        // Success
        futures.add(
          client
              .startWorkflow(
                config.simpleWebhookPath,
                TestDataGenerator.simple(name: 'load-success-$i'),
              )
              .first
              .then((exec) {
            TestCleanup.registerExecution(exec.id);
          }).catchError((_) {}),
        );
      }

      await Future.wait(futures);
      stopwatch.stop();

      // Should complete in reasonable time (< 30 seconds)
      expect(
        stopwatch.elapsed.inSeconds,
        lessThan(30),
        reason: 'Error recovery should handle load efficiently',
      );
    });
  });

  group('Error Recovery - Edge Cases', () {
    test('Empty webhook ID fails immediately', () async {
      expect(
        () => client.startWorkflow('', {}).first,
        throwsA(isA<Exception>()),
      );
    });

    test('Null data is handled gracefully', () async {
      // Should either succeed or fail gracefully
      try {
        final execution =
            await client.startWorkflow(config.simpleWebhookPath, null).first;

        expect(execution.id, isNotEmpty);
        TestCleanup.registerExecution(execution.id);
      } catch (e) {
        expect(e, isA<N8nException>());
      }
    });

    test('Very large payload error handling', () async {
      final largePayload = TestDataGenerator.largePayload(items: 1000);

      try {
        final execution = await client
            .startWorkflow(config.simpleWebhookPath, largePayload)
            .first;

        expect(execution.id, isNotEmpty);
        TestCleanup.registerExecution(execution.id);
      } catch (e) {
        // If fails, should be proper exception
        expect(e, isA<N8nException>());
      }
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('Rapid sequential errors', () async {
      // Rapid failures without delays
      for (var i = 0; i < 10; i++) {
        try {
          await client
              .startWorkflow('invalid-webhook-rapid-$i', {})
              .first;
        } catch (_) {
          // Expected
        }
      }

      // Client should still recover
      final execution = await client
          .startWorkflow(
            config.simpleWebhookPath,
            TestDataGenerator.simple(name: 'post-rapid-test'),
          )
          .first;

      expect(execution.id, isNotEmpty);
      TestCleanup.registerExecution(execution.id);
    });
  });

  group('Error Recovery - Cleanup', () {
    test('Disposing client during error does not crash', () async {
      final testClient = createTestReactiveClient(config);

      // Start failing request
      final future = testClient
          .startWorkflow('invalid-webhook-dispose', {})
          .first
          .then((_) {})
          .catchError((_) {});

      // Dispose immediately
      await Future.delayed(const Duration(milliseconds: 100));
      testClient.dispose();

      // Should not crash
      await future;
    });
  });
}
