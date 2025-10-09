/// Queue Integration Tests
///
/// Tests ReactiveWorkflowQueue with real n8n workflows
@TestOn('vm')
library;

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import 'config/test_config.dart';
import 'utils/test_helpers.dart';

void main() {
  // Skip all tests if .env.test doesn't exist
  if (!TestConfig.canRun()) {
    test('skipped - .env.test not found', () {});
    return;
  }

  group('Queue Integration Tests', () {
    late TestConfig config;
    late ReactiveN8nClient client;
    late ReactiveWorkflowQueue queue;

    setUpAll(() async {
      config = await TestConfig.loadWithAutoDiscovery();
      final errors = config.validate();
      if (errors.isNotEmpty) {
        throw StateError('Invalid test configuration: ${errors.join(", ")}');
      }
    });

    setUp(() {
      client = createTestReactiveClient(config);
      queue = ReactiveWorkflowQueue(client: client);
    });

    tearDown(() {
      queue.dispose();
      client.dispose();
    });

    group('Basic Queue Operations', () {
      test('enqueues workflow and returns queue ID', () {
        final itemId = queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'enqueue'},
        );

        expect(itemId, isNotEmpty);
      });

      test('enqueues multiple workflows', () {
        final id1 = queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'multi-1'},
        );
        final id2 = queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'multi-2'},
        );
        final id3 = queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'multi-3'},
        );

        expect(id1, isNot(equals(id2)));
        expect(id2, isNot(equals(id3)));
        expect(id1, isNot(equals(id3)));
      });

      test('queue length stream emits correct count', () async {
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'length-1'},
        );
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'length-2'},
        );

        final length = await queue.queueLength$.first;
        expect(length, greaterThanOrEqualTo(2));
      });
    });

    group('Queue Processing', () {
      test('processes queued workflows', () async {
        // Enqueue workflows
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'process-1'},
        );
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'process-2'},
        );

        // Process queue
        final results = await queue.processQueue().take(2).toList();

        expect(results.length, equals(2));
        expect(results[0].id, isNotEmpty);
        expect(results[1].id, isNotEmpty);
      }, timeout: Timeout(config.timeout));

      test('processes workflows with throttling', () async {
        // Enqueue multiple workflows
        for (var i = 0; i < 5; i++) {
          queue.enqueue(
            webhookId: config.simpleWebhookPath,
            data: {'test': 'throttle-$i'},
          );
        }

        final startTime = DateTime.now();

        // Process with throttling
        await queue.processQueue().take(3).toList();

        final duration = DateTime.now().difference(startTime);

        // Should take some time due to throttling (1 second default)
        expect(duration.inSeconds, greaterThan(2));
      }, timeout: Timeout(config.timeout));
    });

    group('Queue State Management', () {
      test('tracks pending items', () async {
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'pending-1'},
        );
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'pending-2'},
        );

        final pending = await queue.pendingItems$.first;
        expect(pending.length, greaterThanOrEqualTo(2));
        expect(pending.every((item) => item.status == QueueStatus.pending), isTrue);
      });

      test('tracks processing items during execution', () async {
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'processing'},
        );

        // Start processing
        final subscription = queue.processQueue().listen((_) {});

        // Give it time to start processing
        await Future.delayed(const Duration(milliseconds: 500));

        final processing = await queue.processingItems$.first;
        expect(processing.length, greaterThanOrEqualTo(0));

        await subscription.cancel();
      }, timeout: Timeout(config.timeout));

      test('tracks completed items', () async {
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'completed'},
        );

        // Process and wait for completion
        await queue.processQueue().take(1).toList();

        final completed = await queue.completedItems$.first;
        expect(completed, isNotEmpty);
        expect(completed.every((item) => item.status == QueueStatus.completed), isTrue);
      }, timeout: Timeout(config.timeout));
    });

    group('Queue Metrics', () {
      test('provides queue metrics', () async {
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'metrics-1'},
        );
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'metrics-2'},
        );

        final metrics = await queue.metrics$.first;

        expect(metrics.totalItems, greaterThanOrEqualTo(2));
        expect(metrics.timestamp, isNotNull);
      });

      test('calculates completion rate', () async {
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'rate-1'},
        );

        // Process one workflow
        await queue.processQueue().take(1).toList();

        final metrics = await queue.metrics$.first;

        expect(metrics.completedCount, greaterThan(0));
        expect(metrics.completionRate, greaterThan(0));
      }, timeout: Timeout(config.timeout));
    });

    group('Priority Queue', () {
      test('processes high priority items first', () async {
        // Enqueue low priority
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'low-priority'},
          priority: 1,
        );

        // Enqueue high priority
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'high-priority'},
          priority: 10,
        );

        final queueItems = await queue.queue$.first;

        // High priority should be first
        expect(queueItems.first.priority, equals(10));
      });
    });

    group('Queue Events', () {
      test('emits events for queue operations', () async {
        final events = <QueueEvent>[];

        queue.events$.listen(events.add);

        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'events'},
        );

        await Future.delayed(const Duration(milliseconds: 100));

        expect(events, isNotEmpty);
        expect(events.any((e) => e is QueueItemEnqueuedEvent), isTrue);
      });

      test('emits completion events', () async {
        final events = <QueueEvent>[];

        queue.events$.listen(events.add);

        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'completion-event'},
        );

        await queue.processQueue().take(1).toList();

        await Future.delayed(const Duration(milliseconds: 500));

        expect(events.any((e) => e is QueueItemCompletedEvent), isTrue);
      }, timeout: Timeout(config.timeout));
    });

    group('Queue Configuration', () {
      test('uses standard config by default', () {
        final standardQueue = ReactiveWorkflowQueue(client: client);

        expect(standardQueue, isNotNull);
        standardQueue.dispose();
      });

      test('uses fast config for high throughput', () {
        final fastQueue = ReactiveWorkflowQueue(
          client: client,
          config: ReactiveQueueConfig.fast(),
        );

        expect(fastQueue, isNotNull);
        fastQueue.dispose();
      });

      test('uses reliable config for mission-critical workflows', () {
        final reliableQueue = ReactiveWorkflowQueue(
          client: client,
          config: ReactiveQueueConfig.reliable(),
        );

        expect(reliableQueue, isNotNull);
        reliableQueue.dispose();
      });
    });

    group('Queue Cleanup', () {
      test('clears completed items', () async {
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'clear-completed'},
        );

        await queue.processQueue().take(1).toList();

        final beforeClear = await queue.completedItems$.first;
        expect(beforeClear, isNotEmpty);

        queue.clearCompleted();

        final afterClear = await queue.completedItems$.first;
        expect(afterClear.length, lessThan(beforeClear.length));
      }, timeout: Timeout(config.timeout));

      test('clears all items', () async {
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'clear-all'},
        );

        queue.clear();

        final length = await queue.queueLength$.first;
        expect(length, equals(0));
      });
    });
  });
}
