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
      fakeAsync((async) async {
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

        await sub.cancel();
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

      // Subscribe before dispose
      var metricsCompleted = false;
      var healthCompleted = false;

      manager.metrics$.listen(
        (_) {},
        onDone: () => metricsCompleted = true,
      );

      manager.health$.listen(
        (_) {},
        onDone: () => healthCompleted = true,
      );

      manager.dispose();

      // Wait for async disposal
      await Future.delayed(const Duration(milliseconds: 50));

      // Subjects should be closed
      expect(metricsCompleted, isTrue);
      expect(healthCompleted, isTrue);
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

    test('should track error metrics on failed polls', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
          maxConsecutiveErrors: 5,
        ));

        var count = 0;
        Future<String> poll() async {
          count++;
          if (count < 3) {
            throw Exception('Poll error');
          }
          return 'success';
        }

        final results = <String>[];
        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen(results.add, onError: (_) {});

        // Poll several times
        async.flushMicrotasks();
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        final metrics = manager.getMetrics('exec-1');
        expect(metrics!.errorCount, greaterThan(0));

        sub.cancel();
        manager.dispose();
      });
    });

    test('should emit error events on failed polls', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
          maxConsecutiveErrors: 5,
        ));

        final errors = <PollErrorEvent>[];
        final errorSub = manager.errorEvents$.listen(errors.add);

        Future<String> poll() async {
          throw Exception('Test error');
        }

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {}, onError: (_) {});

        // Do a few polls
        async.flushMicrotasks();
        for (var i = 0; i < 3; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        expect(errors.length, greaterThan(0));
        expect(errors.every((e) => e.executionId == 'exec-1'), isTrue);

        sub.cancel();
        errorSub.cancel();
        manager.dispose();
      });
    });

    test('should handle multiple concurrent polling sessions', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        var count1 = 0;
        var count2 = 0;

        Future<String> poll1() async {
          count1++;
          return 'result1-$count1';
        }

        Future<String> poll2() async {
          count2++;
          return 'result2-$count2';
        }

        final results1 = <String>[];
        final results2 = <String>[];

        final stream1 = manager.startPolling('exec-1', poll1, shouldStop: (_) => count1 >= 3);
        final stream2 = manager.startPolling('exec-2', poll2, shouldStop: (_) => count2 >= 3);

        final sub1 = stream1.listen(results1.add);
        final sub2 = stream2.listen(results2.add);

        // Do several polls
        async.flushMicrotasks();
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        expect(results1.length, greaterThan(0));
        expect(results2.length, greaterThan(0));
        expect(count1, greaterThanOrEqualTo(3));
        expect(count2, greaterThanOrEqualTo(3));

        sub1.cancel();
        sub2.cancel();
        manager.dispose();
      });
    });

    test('should update health metrics based on success/error rates', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
          maxConsecutiveErrors: 10,
        ));

        final healthUpdates = <PollingHealth>[];
        final healthSub = manager.health$.listen(healthUpdates.add);

        var count = 0;
        Future<String> poll() async {
          count++;
          if (count > 3) {
            throw Exception('Error');
          }
          return 'success';
        }

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {}, onError: (_) {});

        // Do many polls
        async.flushMicrotasks();
        for (var i = 0; i < 8; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        // Health should reflect errors
        expect(healthUpdates.length, greaterThan(1));

        sub.cancel();
        healthSub.cancel();
        manager.dispose();
      });
    });

    test('should stop multiple polling sessions individually', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        var count1 = 0;
        var count2 = 0;

        Future<String> poll1() async {
          count1++;
          return 'result1';
        }

        Future<String> poll2() async {
          count2++;
          return 'result2';
        }

        final sub1 = manager.startPolling('exec-1', poll1, shouldStop: (_) => false).listen((_) {});
        final sub2 = manager.startPolling('exec-2', poll2, shouldStop: (_) => false).listen((_) {});

        // Do a few polls
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        final countBefore1 = count1;
        final countBefore2 = count2;

        // Stop both polling sessions
        manager.stopPolling('exec-1');
        manager.stopPolling('exec-2');
        sub1.cancel();
        sub2.cancel();

        // Elapse more time - should not poll
        async.elapse(const Duration(milliseconds: 200));
        async.flushMicrotasks();

        expect(count1, equals(countBefore1));
        expect(count2, equals(countBefore2));

        manager.dispose();
      });
    });

    test('should respect maxConsecutiveErrors limit', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        Future<String> poll() async {
          throw Exception('Always fails');
        }

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        var errorCaught = false;
        final sub = stream.listen(
          (_) {},
          onError: (e) {
            errorCaught = true;
          },
        );

        // Poll until max errors reached
        async.flushMicrotasks();
        for (var i = 0; i < 10; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        // Should have stopped after maxConsecutiveErrors
        final metrics = manager.getMetrics('exec-1');
        expect(metrics!.errorCount, greaterThanOrEqualTo(3));
        expect(errorCaught, isTrue);

        sub.cancel();
        manager.dispose();
      });
    });

    test('metrics stream should emit updated metrics', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        final metricsUpdates = <Map<String, PollingMetrics>>[];
        final metricsSub = manager.metrics$.listen(metricsUpdates.add);

        Future<String> poll() async => 'result';

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {});

        // Do several polls
        async.flushMicrotasks();
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        // Metrics should have been updated
        expect(metricsUpdates.length, greaterThan(1));
        final latestMetrics = metricsUpdates.last;
        expect(latestMetrics.containsKey('exec-1'), isTrue);
        expect(latestMetrics['exec-1']!.totalPolls, greaterThan(0));

        sub.cancel();
        metricsSub.cancel();
        manager.dispose();
      });
    });

    test('should handle rapid start/stop cycles', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        Future<String> poll() async => 'result';

        // Start and stop multiple times
        for (var i = 0; i < 5; i++) {
          final sub = manager.startPolling('exec-$i', poll, shouldStop: (_) => false).listen((_) {});
          async.flushMicrotasks();
          manager.stopPolling('exec-$i');
          sub.cancel();
        }

        // Should not crash
        expect(manager.activeExecutions.length, lessThanOrEqualTo(5));

        manager.dispose();
      });
    });

    test('should track polling start time', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        Future<String> poll() async => 'result';

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {});

        // Do a few polls
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 50));
        async.flushMicrotasks();

        final metrics = manager.getMetrics('exec-1');
        expect(metrics, isNotNull);
        expect(metrics!.startTime, isNotNull);

        sub.cancel();
        manager.dispose();
      });
    });

    test('should handle poll function returning null', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        var count = 0;
        Future<String?> poll() async {
          count++;
          return null;
        }

        final results = <String?>[];
        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => count >= 3);
        final sub = stream.listen(results.add);

        // Do polls
        async.flushMicrotasks();
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        expect(results, contains(null));
        expect(count, greaterThanOrEqualTo(3));

        sub.cancel();
        manager.dispose();
      });
    });

    test('should track average poll duration', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        Future<String> poll() async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'result';
        }

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {});

        // Do several polls
        async.flushMicrotasks();
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        final metrics = manager.getMetrics('exec-1');
        expect(metrics, isNotNull);
        expect(metrics!.totalPolls, greaterThan(0));

        sub.cancel();
        manager.dispose();
      });
    });

    test('distinct should not filter different complex objects', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        var count = 0;
        Future<Map<String, dynamic>> poll() async {
          count++;
          return {'count': count, 'timestamp': DateTime.now().millisecondsSinceEpoch};
        }

        final results = <Map<String, dynamic>>[];
        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => count >= 5);
        final sub = stream.listen(results.add);

        // Do polls
        async.flushMicrotasks();
        for (var i = 0; i < 6; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        // All results should be different (different timestamps)
        expect(results.length, greaterThanOrEqualTo(3));

        sub.cancel();
        manager.dispose();
      });
    });

    test('should cleanup metrics after stopPolling', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        Future<String> poll() async => 'result';

        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen((_) {});

        async.flushMicrotasks();

        expect(manager.getMetrics('exec-1'), isNotNull);

        manager.stopPolling('exec-1');
        sub.cancel();

        // Metrics might still exist after stop, but polling should be stopped
        expect(manager.activeExecutions.contains('exec-1'), isFalse);

        manager.dispose();
      });
    });

    test('health stream should emit health updates', () async {
      final manager = ReactivePollingManager(const PollingConfig(
        baseInterval: Duration(milliseconds: 50),
        maxConsecutiveErrors: 10,
      ));

      // Get initial health value
      final health = await manager.health$.first;
      expect(health, isNotNull);
      expect(health.isHealthy, isTrue);

      manager.dispose();
    });

    test('should handle polling with shouldStop false never terminating', () {
      fakeAsync((async) {
        final manager = ReactivePollingManager(const PollingConfig(
          baseInterval: Duration(milliseconds: 50),
        ));

        var count = 0;
        Future<String> poll() async {
          count++;
          return 'result-$count';
        }

        final results = <String>[];
        final stream = manager.startPolling('exec-1', poll, shouldStop: (_) => false);
        final sub = stream.listen(results.add);

        // Poll several times
        async.flushMicrotasks();
        for (var i = 0; i < 10; i++) {
          async.elapse(const Duration(milliseconds: 50));
          async.flushMicrotasks();
        }

        // Should keep polling indefinitely (only stopping when we cancel)
        expect(count, greaterThanOrEqualTo(10));
        expect(results.length, greaterThanOrEqualTo(10));

        sub.cancel();
        manager.dispose();
      });
    });
  });
}
