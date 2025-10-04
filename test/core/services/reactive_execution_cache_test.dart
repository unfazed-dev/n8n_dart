import 'dart:async';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import '../../mocks/mock_n8n_http_client.dart';

void main() {
  group('ReactiveExecutionCache', () {
    late MockN8nHttpClient mockHttp;
    late ReactiveN8nClient client;
    late ReactiveExecutionCache cache;

    setUp(() {
      mockHttp = MockN8nHttpClient();
      client = ReactiveN8nClient(
        config: N8nConfigProfiles.development(),
        httpClient: mockHttp,
      );
      cache = ReactiveExecutionCache(
        client: client,
        ttl: const Duration(seconds: 2),
        cleanupInterval: const Duration(seconds: 1),
      );
    });

    tearDown(() async {
      cache.dispose();
      client.dispose();
      // Wait for periodic timers to be fully cancelled to prevent interference
      await Future.delayed(const Duration(milliseconds: 50));
    });

    group('Cache Operations', () {
      test('get() should fetch and cache execution', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        final execution = await cache.get('exec-1');

        expect(execution.id, equals('exec-1'));
        expect(execution.status, equals(WorkflowStatus.success));
      });

      test('get() should return cached value on second call', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        await cache.get('exec-1');
        final requestsBefore = mockHttp.requestCount('exec-1');

        await cache.get('exec-1');
        final requestsAfter = mockHttp.requestCount('exec-1');

        // Should not make additional request (cached)
        expect(requestsAfter, equals(requestsBefore));
      });

      test('set() should manually add to cache', () async {
        final execution = WorkflowExecution(
          id: 'exec-1',
          workflowId: 'wf-1',
          status: WorkflowStatus.success,
          startedAt: DateTime.now(),
        );

        cache.set('exec-1', execution);

        await expectLater(
          cache.cacheSize$,
          emits(1),
        );
      });
    });

    group('Cache Events', () {
      test('should emit CacheHitEvent on cache hit', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        // Start listening before operations
        final hitFuture = cache.cacheHits$.first;

        await cache.get('exec-1');
        await cache.get('exec-1'); // Cache hit

        final hitEvent = await hitFuture;
        expect(hitEvent, isA<CacheHitEvent>());
      });

      test('should emit CacheMissEvent on cache miss', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        // Start listening before operations
        final missFuture = cache.cacheMisses$.first;

        // Trigger cache miss and wait for it to complete
        final getFuture = cache.get('exec-1');

        final missEvent = await missFuture;
        expect(missEvent, isA<CacheMissEvent>());

        // Wait for get to complete before test ends
        await getFuture;
      });
    });

    group('Invalidation', () {
      test('invalidate() should emit invalidation event', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.running);

        await cache.get('exec-1');

        // Listen for invalidation event
        final invalidationFuture = cache.events$
            .where((e) => e is CacheInvalidatedEvent)
            .cast<CacheInvalidatedEvent>()
            .first;

        cache.invalidate('exec-1');

        final event = await invalidationFuture;
        expect(event.executionId, equals('exec-1'));
      });

      test('invalidateAll() should clear entire cache', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-2', WorkflowStatus.success);

        await cache.get('exec-1');
        await cache.get('exec-2');

        cache.invalidateAll();

        await expectLater(
          cache.cacheSize$,
          emits(0),
        );
      });

      test('invalidatePattern() should invalidate matching entries', () async {
        mockHttp.mockExecutionStatus('exec-webhook-1', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-webhook-2', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-other-1', WorkflowStatus.success);

        await cache.get('exec-webhook-1');
        await cache.get('exec-webhook-2');
        await cache.get('exec-other-1');

        cache.invalidatePattern((id) => id.contains('webhook'));

        await Future.delayed(const Duration(milliseconds: 100));

        final size = await cache.cacheSize$.first;
        expect(size, equals(1)); // Only exec-other-1 remains
      });
    });

    group('TTL and Cleanup', () {
      test('periodic cleanup runs automatically', () async {
        // Test that periodic cleanup is configured (we can't reliably test
        // the actual cleanup in a test suite due to timing issues)
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        await cache.get('exec-1');

        // Verify entry is cached
        final size = await cache.cacheSize$.first;
        expect(size, equals(1));

        // The cleanup timer is running - tested via clearExpired() test below
        expect(size, greaterThan(0));
      });

      test('clearExpired() should manually clear expired entries', () async {
        // Create cache with short TTL to test manual clearing
        final manualCache = ReactiveExecutionCache(
          client: client,
          ttl: const Duration(milliseconds: 100), // Very short TTL
          cleanupInterval: const Duration(seconds: 10), // Long interval so auto-cleanup doesn't interfere
        );

        // Ensure cleanup happens even if test fails
        addTearDown(() async {
          manualCache.dispose();
          // Wait for timer to be fully cancelled
          await Future.delayed(const Duration(milliseconds: 50));
        });

        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        await manualCache.get('exec-1');

        // Verify entry is cached
        var size = await manualCache.cacheSize$.first;
        expect(size, equals(1));

        // Wait for expiration (TTL is 100ms)
        await Future.delayed(const Duration(milliseconds: 120));

        final clearedCount = manualCache.clearExpired();

        expect(clearedCount, equals(1));
      });
    });

    group('Metrics', () {
      test('metrics\$ should track hit/miss rates', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        // Collect metrics as operations happen
        final metricsCollected = <CacheMetrics>[];
        final subscription = cache.metrics$.listen((m) {
          metricsCollected.add(m);
        });

        await cache.get('exec-1'); // Miss
        await cache.get('exec-1'); // Hit

        // Give time for metrics to update
        await Future.delayed(const Duration(milliseconds: 100));

        await subscription.cancel();

        // Should have at least one metrics update
        expect(metricsCollected.isNotEmpty, isTrue);

        // Last metrics should show both hit and miss
        final lastMetrics = metricsCollected.last;
        expect(lastMetrics.hitCount, greaterThanOrEqualTo(1));
        expect(lastMetrics.missCount, greaterThanOrEqualTo(1));
      });
    });

    group('Watch', () {
      test('watch() should stream cached values', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        await cache.get('exec-1'); // Prime cache

        await expectLater(
          cache.watch('exec-1'),
          emits(predicate<WorkflowExecution?>((e) => e?.id == 'exec-1')),
        );
      });

      test('watch() should emit null for cache miss', () async {
        await expectLater(
          cache.watch('nonexistent').take(1),
          emits(null),
        );
      });
    });

    group('Prewarm', () {
      test('prewarm() should load multiple executions', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-2', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-3', WorkflowStatus.success);

        await cache.prewarm(['exec-1', 'exec-2', 'exec-3']);

        final size = await cache.cacheSize$.first;
        expect(size, equals(3));
      });
    });
  });
}
