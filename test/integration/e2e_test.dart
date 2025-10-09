@TestOn('vm')
@Tags(['integration', 'e2e'])
library;

import 'package:n8n_dart/n8n_dart.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import 'config/test_config.dart';
import 'utils/test_helpers.dart';

/// End-to-End Integration Tests
///
/// Comprehensive scenarios that combine multiple Phase 3 features:
/// - Complete workflow lifecycle (wait nodes + resumption)
/// - Queue + Cache integration
/// - Multi-execution patterns
/// - Real n8n cloud workflows
void main() {
  group('E2E Integration Tests', () {
    late TestConfig config;
    late ReactiveN8nClient client;

    setUpAll(() async {
      config = await TestConfig.loadWithAutoDiscovery();
      print('✓ E2E test configuration loaded');
    });

    setUp(() {
      client = createTestReactiveClient(config);
    });

    tearDown(() {
      client.dispose();
    });

    test('E2E: Queue + Cache + Multi-execution integration', () async {
      print('\n🧪 E2E Test: Full stack integration');

      // Create queue and cache
      final queue = ReactiveWorkflowQueue(
        client: client,
        config: const ReactiveQueueConfig(
          throttleDuration: Duration(milliseconds: 100),
          maxConcurrent: 2,
          waitForCompletion: false,
          retryFailedItems: false,
          maxRetries: 0,
        ),
      );

      final cache = ReactiveExecutionCache(
        client: client,
        ttl: const Duration(minutes: 1),
      );

      try {
        // Step 1: Enqueue workflows
        print('  Step 1: Enqueueing 3 workflows...');
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'e2e-full-stack-1'},
        );
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'e2e-full-stack-2'},
        );
        queue.enqueue(
          webhookId: config.simpleWebhookPath,
          data: {'test': 'e2e-full-stack-3'},
        );

        // Step 2: Process queue
        print('  Step 2: Processing queue...');
        final executions = await queue.processQueue().take(3).toList();

        expect(executions.length, equals(3));
        print('  ✓ Processed ${executions.length} workflows');

        // Step 3: Cache results
        print('  Step 3: Caching executions...');
        for (var exec in executions) {
          cache.set(exec.id, exec);
        }

        await Future.delayed(const Duration(milliseconds: 200));
        final cacheSize = await cache.cacheSize$.first;
        expect(cacheSize, equals(3));
        print('  ✓ Cached $cacheSize executions');

        // Step 4: Retrieve from cache (cache hits)
        print('  Step 4: Retrieving from cache...');
        final cached = await cache.get(executions[0].id);
        expect(cached.id, equals(executions[0].id));
        print('  ✓ Cache hit confirmed');

        // Step 5: Multi-execution pattern (parallel retrieval)
        print('  Step 5: Parallel cache retrieval...');
        final cachedStreams = executions.map((e) =>
            Stream.fromFuture(cache.get(e.id))).toList();

        final allCached = await Rx.forkJoin(
          cachedStreams,
          (values) => values,
        ).first;

        expect(allCached.length, equals(3));
        print('  ✓ Retrieved ${allCached.length} from cache in parallel');

        // Step 6: Verify cache metrics
        await Future.delayed(const Duration(milliseconds: 100));
        final metrics = await cache.metrics$.first;
        expect(metrics.hitCount, greaterThan(0));
        expect(metrics.cacheSize, equals(3));
        print('  ✓ Cache metrics: ${metrics.hitCount} hits, size: ${metrics.cacheSize}');

        print('✅ E2E full stack integration test completed successfully\n');
      } finally {
        queue.dispose();
        cache.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('E2E: Multi-execution patterns with error handling', () async {
      print('\n🧪 E2E Test: Multi-execution patterns');

      // Test 1: Parallel execution with forkJoin
      print('  Test 1: Parallel execution (forkJoin)...');
      final parallel = await Rx.forkJoin3(
        client.startWorkflow(config.simpleWebhookPath, {'test': 'e2e-parallel-1'}),
        client.startWorkflow(config.simpleWebhookPath, {'test': 'e2e-parallel-2'}),
        client.startWorkflow(config.simpleWebhookPath, {'test': 'e2e-parallel-3'}),
        (a, b, c) => [a, b, c],
      ).first;

      expect(parallel.length, equals(3));
      print('  ✓ Parallel execution: ${parallel.length} workflows');

      // Test 2: Race condition
      print('  Test 2: Race execution...');
      final race = await Rx.race([
        client.startWorkflow(config.simpleWebhookPath, {'test': 'e2e-race-1'}),
        client.startWorkflow(config.simpleWebhookPath, {'test': 'e2e-race-2'}),
      ]).first;

      expect(race.id, isNotEmpty);
      print('  ✓ Race winner: ${race.id}');

      // Test 3: Sequential execution
      print('  Test 3: Sequential execution...');
      var count = 0;
      await Stream.fromIterable([1, 2])
          .asyncExpand((i) => client.startWorkflow(
                config.simpleWebhookPath,
                {'test': 'e2e-seq-$i'},
              ))
          .map((exec) {
            count++;
            return exec;
          })
          .toList();

      expect(count, equals(2));
      print('  ✓ Sequential execution: $count workflows');

      print('✅ E2E multi-execution test completed successfully\n');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('E2E: Queue metrics and state management', () async {
      print('\n🧪 E2E Test: Queue metrics');

      final queue = ReactiveWorkflowQueue(
        client: client,
        config: const ReactiveQueueConfig(
          throttleDuration: Duration(milliseconds: 100),
          maxConcurrent: 2,
          waitForCompletion: false,
          retryFailedItems: false,
          maxRetries: 0,
        ),
      );

      try {
        // Enqueue workflows
        print('  Step 1: Enqueueing workflows...');
        for (var i = 1; i <= 5; i++) {
          queue.enqueue(
            webhookId: config.simpleWebhookPath,
            data: {'test': 'e2e-queue-metrics-$i'},
          );
        }

        // Process queue and track metrics
        print('  Step 2: Processing queue with metrics tracking...');
        final results = await queue.processQueue().take(5).toList();

        expect(results.length, equals(5));
        print('  ✓ Processed ${results.length} workflows');

        // Verify metrics
        await Future.delayed(const Duration(milliseconds: 200));
        final metrics = await queue.metrics$.first;
        expect(metrics.completedCount, equals(5));
        print('  ✓ Queue metrics: ${metrics.completedCount} completed');

        print('✅ E2E queue metrics test completed successfully\n');
      } finally {
        queue.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('E2E: Cache invalidation and TTL', () async {
      print('\n🧪 E2E Test: Cache invalidation');

      final cache = ReactiveExecutionCache(
        client: client,
        ttl: const Duration(seconds: 2),
      );

      try {
        // Start and cache workflow
        print('  Step 1: Starting and caching workflow...');
        final exec = await client
            .startWorkflow(config.simpleWebhookPath, {'test': 'e2e-cache-ttl'})
            .first;

        cache.set(exec.id, exec);
        await Future.delayed(const Duration(milliseconds: 100));

        var size = await cache.cacheSize$.first;
        expect(size, equals(1));
        print('  ✓ Cached 1 execution');

        // Invalidate
        print('  Step 2: Invalidating cache...');
        cache.invalidate(exec.id);
        await Future.delayed(const Duration(milliseconds: 100));

        size = await cache.cacheSize$.first;
        expect(size, equals(0));
        print('  ✓ Cache invalidated successfully');

        // Test invalidateAll
        print('  Step 3: Testing invalidateAll...');
        final exec2 = await client
            .startWorkflow(config.simpleWebhookPath, {'test': 'e2e-cache-invalidate-all'})
            .first;
        cache.set(exec2.id, exec2);

        await Future.delayed(const Duration(milliseconds: 100));
        cache.invalidateAll();
        await Future.delayed(const Duration(milliseconds: 100));

        size = await cache.cacheSize$.first;
        expect(size, equals(0));
        print('  ✓ InvalidateAll successful');

        print('✅ E2E cache invalidation test completed successfully\n');
      } finally {
        cache.dispose();
      }
    }, timeout: const Timeout(Duration(minutes: 2)));

    // SKIPPED: Wait node E2E tests - n8n cloud API limitation
    // n8n API bug: GET /executions does not return "waiting" status executions
    // See: https://github.com/n8n-io/n8n/issues/14748
    //
    // Without execution ID from API, cannot test:
    // - Complete workflow lifecycle with wait node (Start → Poll → Wait → Resume → Complete)
    // - Queue + Wait nodes integration
    // - Cache + Wait nodes + Resume workflow
    //
    // These tests require the ability to discover execution IDs via API after triggering
    // wait node workflows, but the n8n cloud API filters out "waiting" status executions
    // from the /executions endpoint. This is a known limitation of the platform.
  });
}
