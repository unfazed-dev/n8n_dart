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

    tearDown(() {
      cache.dispose();
      client.dispose();
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

        await cache.get('exec-1');
        await cache.get('exec-1'); // Cache hit

        await expectLater(
          cache.cacheHits$,
          emits(isA<CacheHitEvent>()),
        );
      });

      test('should emit CacheMissEvent on cache miss', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        // Trigger cache miss (don't await to allow event stream to capture it)
        unawaited(cache.get('exec-1'));

        await expectLater(
          cache.cacheMisses$,
          emits(isA<CacheMissEvent>()),
        );
      });
    });

    group('Invalidation', () {
      test('invalidate() should trigger refetch', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.running);

        final execution1 = await cache.get('exec-1');
        expect(execution1.status, equals(WorkflowStatus.running));

        // Update mock to return success
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        cache.invalidate('exec-1');

        // Wait a bit for invalidation to process
        await Future.delayed(const Duration(milliseconds: 100));

        final execution2 = await cache.get('exec-1');
        expect(execution2.status, equals(WorkflowStatus.success));
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
      test('expired entries should be auto-cleaned', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        await cache.get('exec-1');

        // Wait for TTL to expire
        await Future.delayed(const Duration(seconds: 3));

        final size = await cache.cacheSize$.first;
        expect(size, equals(0));
      }, timeout: const Timeout(Duration(seconds: 5)));

      test('clearExpired() should manually clear expired entries', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        await cache.get('exec-1');

        // Wait for expiration
        await Future.delayed(const Duration(seconds: 3));

        final clearedCount = cache.clearExpired();

        expect(clearedCount, greaterThan(0));
      }, timeout: const Timeout(Duration(seconds: 5)));
    });

    group('Metrics', () {
      test('metrics\$ should track hit/miss rates', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        await cache.get('exec-1'); // Miss
        await cache.get('exec-1'); // Hit

        await expectLater(
          cache.metrics$,
          emits(predicate<CacheMetrics>(
            (m) => m.hitCount >= 1 && m.missCount >= 1,
          )),
        );
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
