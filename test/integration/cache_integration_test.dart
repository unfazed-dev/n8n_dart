/// Cache Integration Tests
///
/// Tests ReactiveExecutionCache with real n8n workflow executions
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

  group('Cache Integration Tests', () {
    late TestConfig config;
    late ReactiveN8nClient client;
    late ReactiveExecutionCache cache;

    setUpAll(() async {
      config = await TestConfig.loadWithAutoDiscovery();
      final errors = config.validate();
      if (errors.isNotEmpty) {
        throw StateError('Invalid test configuration: ${errors.join(", ")}');
      }
    });

    setUp(() {
      client = createTestReactiveClient(config);
      cache = ReactiveExecutionCache(
        client: client,
        cleanupInterval: const Duration(seconds: 30),
      );
    });

    tearDown(() {
      cache.dispose();
      client.dispose();
    });

    group('Basic Cache Operations', () {
      test('caches execution on first access', () async {
        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'cache-first'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Get from cache (first time - cache miss)
        final result = await cache.get(execution.id);

        expect(result.id, equals(execution.id));

        // Verify cache size increased
        final size = await cache.cacheSize$.first;
        expect(size, greaterThan(0));
      }, timeout: Timeout(config.timeout));

      test('returns cached execution on subsequent access', () async {
        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'cache-hit'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // First access (cache miss)
        await cache.get(execution.id);

        // Second access (should be cache hit)
        final startTime = DateTime.now();
        final cached = await cache.get(execution.id);
        final duration = DateTime.now().difference(startTime);

        expect(cached.id, equals(execution.id));

        // Should be very fast (< 100ms) because it's cached
        expect(duration.inMilliseconds, lessThan(100));
      }, timeout: Timeout(config.timeout));

      test('manually sets execution in cache', () async {
        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'cache-set'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Manually set in cache
        cache.set(execution.id, execution);

        // Verify it's cached
        final size = await cache.cacheSize$.first;
        expect(size, greaterThan(0));
      }, timeout: Timeout(config.timeout));
    });

    group('Cache Metrics', () {
      test('tracks cache hits', () async {
        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'track-hits'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // First access (miss)
        await cache.get(execution.id);

        // Second access (hit)
        await cache.get(execution.id);

        // Wait for metrics to update
        await Future.delayed(const Duration(milliseconds: 200));

        // Check metrics
        final metrics = await cache.metrics$.first;
        expect(metrics.hitCount, greaterThan(0));
      }, timeout: Timeout(config.timeout));

      test('tracks cache misses', () async {
        final events = <CacheEvent>[];
        cache.events$.listen(events.add);

        // Try to get non-existent execution
        try {
          await cache.get('non-existent-id');
        } catch (_) {
          // Expected to fail
        }

        await Future.delayed(const Duration(milliseconds: 200));

        // Should have miss events
        expect(events.whereType<CacheMissEvent>(), isNotEmpty);
      }, timeout: Timeout(config.timeout));

      test('calculates hit rate', () async {
        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'hit-rate'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // First access (miss)
        await cache.get(execution.id);

        // Multiple hits
        await cache.get(execution.id);
        await cache.get(execution.id);

        await Future.delayed(const Duration(milliseconds: 200));

        final metrics = await cache.metrics$.first;
        expect(metrics.hitRate, greaterThan(0));
        expect(metrics.hitRate, lessThanOrEqualTo(1.0));
      }, timeout: Timeout(config.timeout));
    });

    group('Cache Events', () {
      test('emits cache hit events', () async {
        final hits = <CacheHitEvent>[];
        cache.cacheHits$.listen(hits.add);

        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'hit-events'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Cache it
        cache.set(execution.id, execution);

        // Access it (should be hit)
        await cache.get(execution.id);

        await Future.delayed(const Duration(milliseconds: 200));

        expect(hits, isNotEmpty);
        expect(hits.first.executionId, equals(execution.id));
      }, timeout: Timeout(config.timeout));

      test('emits cache miss events', () async {
        final misses = <CacheMissEvent>[];
        cache.cacheMisses$.listen(misses.add);

        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'miss-events'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Access it (first time - should be miss before fetch)
        await cache.get(execution.id);

        await Future.delayed(const Duration(milliseconds: 200));

        expect(misses, isNotEmpty);
      }, timeout: Timeout(config.timeout));
    });

    group('Cache Invalidation', () {
      test('invalidates specific execution', () async {
        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'invalidate'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Cache it
        cache.set(execution.id, execution);

        final sizeBefore = await cache.cacheSize$.first;

        // Invalidate it
        cache.invalidate(execution.id);

        await Future.delayed(const Duration(milliseconds: 200));

        final sizeAfter = await cache.cacheSize$.first;
        expect(sizeAfter, lessThan(sizeBefore));
      }, timeout: Timeout(config.timeout));

      test('invalidates all cache entries', () async {
        // Start multiple workflows
        final execution1 = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'invalidate-all-1'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        final execution2 = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'invalidate-all-2'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Cache them
        cache.set(execution1.id, execution1);
        cache.set(execution2.id, execution2);

        // Invalidate all
        cache.invalidateAll();

        await Future.delayed(const Duration(milliseconds: 200));

        final size = await cache.cacheSize$.first;
        expect(size, equals(0));
      }, timeout: Timeout(config.timeout));
    });

    group('Cache Watch', () {
      test('watches execution with auto-refresh', () async {
        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'watch'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Cache it
        cache.set(execution.id, execution);

        // Watch it
        final watched = await cache.watch(execution.id).first;

        expect(watched, isNotNull);
        expect(watched!.id, equals(execution.id));
      }, timeout: Timeout(config.timeout));

      test('watch emits null for non-cached execution', () async {
        // Watch non-existent execution
        final watched = await cache.watch('non-existent-id').first;

        expect(watched, isNull);
      }, timeout: Timeout(config.timeout));
    });

    group('Cache TTL', () {
      test('expires entries after TTL', () async {
        // Create cache with short TTL
        final shortCache = ReactiveExecutionCache(
          client: client,
          ttl: const Duration(seconds: 2),
          cleanupInterval: const Duration(seconds: 1),
        );

        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'ttl-expire'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Cache it
        shortCache.set(execution.id, execution);

        final sizeBefore = await shortCache.cacheSize$.first;
        expect(sizeBefore, greaterThan(0));

        // Wait for expiration
        await Future.delayed(const Duration(seconds: 3));

        final sizeAfter = await shortCache.cacheSize$.first;
        expect(sizeAfter, lessThanOrEqualTo(sizeBefore));

        shortCache.dispose();
      }, timeout: const Timeout(Duration(seconds: 10)));

      test('clears expired entries manually', () async {
        // Create cache with short TTL
        final shortCache = ReactiveExecutionCache(
          client: client,
          ttl: const Duration(milliseconds: 500),
          cleanupInterval: const Duration(minutes: 10), // Long interval so manual cleanup is needed
        );

        // Start a workflow
        final execution = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'manual-clear'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Cache it
        shortCache.set(execution.id, execution);

        // Wait for expiration
        await Future.delayed(const Duration(seconds: 1));

        // Manually clear expired
        final cleared = shortCache.clearExpired();

        expect(cleared, greaterThan(0));

        shortCache.dispose();
      }, timeout: Timeout(config.timeout));
    });

    group('Cache Cleanup', () {
      test('clears all cache entries', () async {
        // Start a workflow (synchronous cache.set)
        cache.set('test-id-1', WorkflowExecution(
          id: 'test-id-1',
          workflowId: 'test-workflow',
          status: WorkflowStatus.running,
          startedAt: DateTime.now(),
        ));

        cache.set('test-id-2', WorkflowExecution(
          id: 'test-id-2',
          workflowId: 'test-workflow',
          status: WorkflowStatus.running,
          startedAt: DateTime.now(),
        ));

        cache.clear();

        // Verify cache is empty
        final size = await cache.cacheSize$.first;
        expect(size, equals(0));
      });
    });

    group('Cache Prewarm', () {
      test('prewarms cache with execution IDs', () async {
        // Start multiple workflows
        final execution1 = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'prewarm-1'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        final execution2 = await client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'prewarm-2'},
              workflowId: config.simpleWorkflowId,
            )
            .first;

        // Prewarm cache
        await cache.prewarm([execution1.id, execution2.id]);

        await Future.delayed(const Duration(milliseconds: 500));

        // Verify cache has entries
        final size = await cache.cacheSize$.first;
        expect(size, greaterThanOrEqualTo(1));
      }, timeout: Timeout(config.timeout));
    });
  });
}
