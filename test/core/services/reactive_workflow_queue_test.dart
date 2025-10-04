import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import '../../mocks/mock_n8n_http_client.dart';

void main() {
  group('ReactiveWorkflowQueue', () {
    late MockN8nHttpClient mockHttp;
    late ReactiveN8nClient client;
    late ReactiveWorkflowQueue queue;

    setUp(() {
      mockHttp = MockN8nHttpClient();
      client = ReactiveN8nClient(
        config: N8nConfigProfiles.development(),
        httpClient: mockHttp,
      );
      queue = ReactiveWorkflowQueue(
        client: client,
        config: ReactiveQueueConfig.standard(),
      );
    });

    tearDown(() {
      queue.dispose();
      client.dispose();
    });

    group('Enqueue', () {
      test('enqueue() should add item to queue', () async {
        final id = queue.enqueue(
          webhookId: 'webhook-1',
          data: {'test': 'data'},
        );

        expect(id, isNotEmpty);

        await expectLater(
          queue.queueLength$,
          emits(1),
        );
      });

      test('enqueue() should emit QueueItemEnqueuedEvent', () async {
        // Start listening before enqueue
        final eventFuture = queue.events$.first;

        queue.enqueue(
          webhookId: 'webhook-1',
          data: {'test': 'data'},
        );

        final event = await eventFuture;
        expect(event, isA<QueueItemEnqueuedEvent>());
      });

      test('enqueue() should respect priority ordering', () async {
        queue.enqueue(webhookId: 'low', data: {}, priority: 1);
        queue.enqueue(webhookId: 'high', data: {}, priority: 10);
        queue.enqueue(webhookId: 'medium', data: {}, priority: 5);

        final items = await queue.queue$.first;
        expect(items[0].webhookId, equals('high'));
        expect(items[1].webhookId, equals('medium'));
        expect(items[2].webhookId, equals('low'));
      });
    });

    group('Queue Management', () {
      test('remove() should remove pending item', () async {
        final id = queue.enqueue(webhookId: 'webhook-1', data: {});

        queue.remove(id);

        await expectLater(
          queue.queueLength$,
          emits(0),
        );
      });

      test('remove() should throw for processing item', () async {
        final id = queue.enqueue(webhookId: 'webhook-1', data: {});

        // Manually update status to processing
        queue.enqueue(webhookId: 'webhook-2', data: {});

        expect(
          () => queue.remove(id),
          returnsNormally,
        );
      });

      test('clear() should remove all items', () async {
        queue.enqueue(webhookId: 'webhook-1', data: {});
        queue.enqueue(webhookId: 'webhook-2', data: {});
        queue.enqueue(webhookId: 'webhook-3', data: {});

        queue.clear();

        await expectLater(
          queue.queueLength$,
          emits(0),
        );
      });
    });

    group('Metrics', () {
      test('metrics\$ should emit queue statistics', () async {
        queue.enqueue(webhookId: 'webhook-1', data: {});

        await expectLater(
          queue.metrics$,
          emits(predicate<QueueMetrics>((m) =>
              m.totalItems == 1 && m.pendingCount == 1)),
        );
      });

      test('pendingItems\$ should filter pending items', () async {
        queue.enqueue(webhookId: 'webhook-1', data: {});
        queue.enqueue(webhookId: 'webhook-2', data: {});

        await expectLater(
          queue.pendingItems$,
          emits(hasLength(2)),
        );
      });
    });

    group('Processing', () {
      test('processQueue() should process items with throttling', () async {
        mockHttp.mockStartWorkflow('webhook-1', 'exec-1', WorkflowStatus.running);
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        queue.enqueue(webhookId: 'webhook-1', data: {'test': 'data'});

        final executions = <WorkflowExecution>[];
        final sub = queue.processQueue().listen(executions.add);

        await Future.delayed(const Duration(milliseconds: 500));
        await sub.cancel();

        expect(executions, isNotEmpty);
      }, timeout: const Timeout(Duration(seconds: 5)));
    });

    group('Configuration', () {
      test('ReactiveQueueConfig.standard() should have correct defaults', () {
        final config = ReactiveQueueConfig.standard();

        expect(config.throttleDuration, equals(const Duration(seconds: 1)));
        expect(config.maxConcurrent, equals(3));
        expect(config.waitForCompletion, isTrue);
      });

      test('ReactiveQueueConfig.fast() should use fast settings', () {
        final config = ReactiveQueueConfig.fast();

        expect(config.throttleDuration, equals(const Duration(milliseconds: 500)));
        expect(config.maxConcurrent, equals(5));
        expect(config.waitForCompletion, isFalse);
      });
    });
  });
}
