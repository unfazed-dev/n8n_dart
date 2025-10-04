import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:n8n_dart/src/core/services/polling_manager.dart';
import 'package:n8n_dart/src/core/services/reactive_polling_manager.dart';
import 'package:test/test.dart';

/// Fixed polling manager tests using fake_async for deterministic time control
/// This solves the Stream.periodic timeout issues
void main() {
  group('ReactivePollingManager - Phase 4 (FakeAsync)', () {
    test('should create manager with initial state', () {
      final manager = ReactivePollingManager(PollingConfig.balanced());

      expect(manager.activeExecutions, isEmpty);
      expect(manager.getMetrics('test'), isNull);

      manager.dispose();
    });

    test('should emit from metrics stream', () async {
      final manager = ReactivePollingManager(PollingConfig.balanced());

      final metrics = await manager.metrics$.first;
      expect(metrics, isA<Map<String, PollingMetrics>>());
      expect(metrics, isEmpty);

      manager.dispose();
    });

    test('should emit from health stream', () async {
      final manager = ReactivePollingManager(PollingConfig.balanced());

      final health = await manager.health$.first;
      expect(health.isHealthy, isTrue);
      expect(health.successRate, equals(1.0));
      expect(health.errorRate, equals(0.0));

      manager.dispose();
    });

    test('startPolling with FakeAsync should poll at specified intervals', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 100),
        ));

        var pollCount = 0;
        Future<String> poll() async {
          pollCount++;
          return 'result-$pollCount';
        }

        final results = <String>[];
        final stream = manager.startPolling('exec-1', poll, shouldStop: (r) => pollCount >= 3);

        // Subscribe to stream
        final sub = stream.listen(results.add);

        // Initial poll happens immediately
        async.flushMicrotasks();
        expect(pollCount, equals(1));
        expect(results, hasLength(1));

        // Elapse time for second poll
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(pollCount, equals(2));

        // Elapse time for third poll
        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();
        expect(pollCount, equals(3));

        sub.cancel();
        manager.dispose();
      });
    });

    test('distinct should filter duplicate poll results', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        var count = 0;
        Future<String> poll() async {
          count++;
          return count < 5 ? 'same' : 'different';
        }

        final results = <String>[];
        final stream = manager.startPolling('exec-1', poll, shouldStop: (r) => count >= 6);
        final sub = stream.listen(results.add);

        // Flush initial poll
        async.flushMicrotasks();

        // Elapse enough time for 6 polls
        for (var i = 0; i < 6; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        // distinct should filter duplicates
        expect(results, equals(['same', 'different']));

        sub.cancel();
        manager.dispose();
      });
    });

    test('shouldStop should terminate polling when condition met', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        var count = 0;
        Future<Map<String, String>> poll() async {
          count++;
          return {'status': count >= 3 ? 'done' : 'running'};
        }

        final results = <Map<String, String>>[];
        final stream = manager.startPolling(
          'exec-1',
          poll,
          shouldStop: (r) => r['status'] == 'done',
        );

        final sub = stream.listen(results.add);

        // Flush microtasks and elapse time until done
        async.flushMicrotasks();
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
          if (count >= 3) break;
        }

        expect(results.last['status'], equals('done'));
        expect(count, greaterThanOrEqualTo(3));

        sub.cancel();
        manager.dispose();
      });
    });

    test('should track metrics after polling', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        Future<String> poll() async => 'result';

        final stream = manager.startPolling('exec-test', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {});

        // Do 3 polls
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        final metrics = manager.getMetrics('exec-test');
        expect(metrics, isNotNull);
        expect(metrics!.executionId, equals('exec-test'));
        expect(metrics.totalPolls, greaterThanOrEqualTo(2));

        sub.cancel();
        manager.dispose();
      });
    });

    test('should track successful polls in metrics', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        Future<String> poll() async => 'success';

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {});

        // Do 5 polls
        async.flushMicrotasks();
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        final metrics = manager.getMetrics('exec-1');
        expect(metrics!.successfulPolls, greaterThanOrEqualTo(5));
        expect(metrics.errorCount, equals(0));

        sub.cancel();
        manager.dispose();
      });
    });

    test('should emit success events on successful polls', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        final events = <PollSuccessEvent>[];
        final eventSub = manager.successEvents$.listen(events.add);

        Future<String> poll() async => 'success';

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {});

        // Do 3 polls
        async.flushMicrotasks();
        for (var i = 0; i < 3; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        expect(events.length, greaterThanOrEqualTo(3));
        expect(events.every((e) => e.executionId == 'exec-1'), isTrue);

        sub.cancel();
        eventSub.cancel();
        manager.dispose();
      });
    });

    test('stopPolling should cancel active polling', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        var count = 0;
        Future<String> poll() async {
          count++;
          return 'result';
        }

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {});

        // Do a few polls
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        final countBefore = count;

        // Stop polling
        manager.stopPolling('exec-1');
        sub.cancel();

        // Elapse more time - should not poll
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        expect(count, equals(countBefore));

        manager.dispose();
      });
    });

    test('dispose should close all subjects', () async {
      final manager = ReactivePollingManager(PollingConfig.balanced());
      manager.dispose();

      // Subjects should be closed - trying to emit should fail
      await expectLater(
        manager.metrics$.first,
        throwsA(isA<StateError>()),
      );
    });

    test('activeExecutions should track polling sessions', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        Future<String> poll1() async => 'result1';
        Future<String> poll2() async => 'result2';

        final sub1 = manager.startPolling('exec-1', poll1, shouldStop: (_) => false).listen((_) {});
        final sub2 = manager.startPolling('exec-2', poll2, shouldStop: (_) => false).listen((_) {});

        async.flushMicrotasks();

        final active = manager.activeExecutions;
        expect(active.length, greaterThanOrEqualTo(1));

        sub1.cancel();
        sub2.cancel();
        manager.dispose();
      });
    });

    test('getMetrics should return null for non-existent execution', () {
      final manager = ReactivePollingManager(PollingConfig.balanced());

      final metrics = manager.getMetrics('does-not-exist');
      expect(metrics, isNull);

      manager.dispose();
    });
  });
}
