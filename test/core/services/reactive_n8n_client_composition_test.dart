import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import '../../mocks/mock_n8n_http_client.dart';

void main() {
  group('ReactiveN8nClient - Composition & Combination (Phase 6.1)', () {
    late MockN8nHttpClient mockHttp;
    late ReactiveN8nClient client;

    setUp(() {
      mockHttp = MockN8nHttpClient();
      client = ReactiveN8nClient(
        config: N8nConfigProfiles.development(),
        httpClient: mockHttp,
      );
    });

    tearDown(() {
      client.dispose();
    });

    group('zipWorkflows', () {
      test('should combine executions when all have emitted', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.running);
        mockHttp.mockExecutionStatus('exec-2', WorkflowStatus.running);

        final stream = client.zipWorkflows(['exec-1', 'exec-2']);

        await expectLater(
          stream,
          emits(predicate<List<WorkflowExecution>>(
            (list) => list.length == 2 &&
                      list[0].id == 'exec-1' &&
                      list[1].id == 'exec-2',
          )),
        );
      });

      test('should handle empty execution list', () async {
        final stream = client.zipWorkflows([]);

        await expectLater(
          stream,
          emits([]),
        );
      });

      test('should handle single execution', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);

        final stream = client.zipWorkflows(['exec-1']);

        await expectLater(
          stream,
          emits(predicate<List<WorkflowExecution>>(
            (list) => list.length == 1 && list[0].id == 'exec-1',
          )),
        );
      });
    });

    group('watchMultipleExecutions', () {
      test('should merge multiple execution streams', () async {
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-2', WorkflowStatus.success);

        final stream = client.watchMultipleExecutions(['exec-1', 'exec-2']);

        final executions = <WorkflowExecution>[];
        await for (final execution in stream.take(2)) {
          executions.add(execution);
        }

        expect(executions, hasLength(2));
        expect(executions.map((e) => e.id).toSet(), containsAll(['exec-1', 'exec-2']));
      });

      test('should handle empty list', () async {
        final stream = client.watchMultipleExecutions([]);

        await expectLater(
          stream,
          emitsDone,
        );
      });
    });

    group('batchStartWorkflows', () {
      test('should start all workflows and wait for completion', () async {
        mockHttp.mockStartWorkflow('webhook-1', 'exec-1', WorkflowStatus.running);
        mockHttp.mockStartWorkflow('webhook-2', 'exec-2', WorkflowStatus.running);
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-2', WorkflowStatus.success);

        final pairs = [
          const MapEntry('webhook-1', {'data': '1'}),
          const MapEntry('webhook-2', {'data': '2'}),
        ];

        final stream = client.batchStartWorkflows(pairs);

        await expectLater(
          stream,
          emits(predicate<List<WorkflowExecution>>(
            (list) => list.length == 2,
          )),
        );
      }, timeout: const Timeout(Duration(seconds: 10)));

      test('should handle empty batch', () async {
        final stream = client.batchStartWorkflows([]);

        await expectLater(
          stream,
          emits([]),
        );
      });
    });

    group('raceWorkflows', () {
      test('should emit result from fastest workflow', () async {
        mockHttp.mockStartWorkflow('webhook-fast', 'exec-fast', WorkflowStatus.running);
        mockHttp.mockStartWorkflow('webhook-slow', 'exec-slow', WorkflowStatus.running);
        mockHttp.mockExecutionStatus('exec-fast', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-slow', WorkflowStatus.running);

        final pairs = [
          const MapEntry('webhook-fast', {'speed': 'fast'}),
          const MapEntry('webhook-slow', {'speed': 'slow'}),
        ];

        final stream = client.raceWorkflows(pairs);

        await expectLater(
          stream,
          emits(predicate<WorkflowExecution>(
            (e) => e.id == 'exec-fast',
          )),
        );
      });

      test('should handle empty list', () async {
        final stream = client.raceWorkflows([]);

        await expectLater(
          stream,
          emitsDone,
        );
      });
    });

    group('startWorkflowsSequential', () {
      test('should process workflows in sequence', () async {
        mockHttp.mockStartWorkflow('webhook-1', 'exec-1', WorkflowStatus.running);
        mockHttp.mockStartWorkflow('webhook-2', 'exec-2', WorkflowStatus.running);
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-2', WorkflowStatus.success);

        final dataStream = Stream.fromIterable([
          const MapEntry('webhook-1', {'order': 1}),
          const MapEntry('webhook-2', {'order': 2}),
        ]);

        final stream = client.startWorkflowsSequential(dataStream);

        final executions = <WorkflowExecution>[];
        await for (final execution in stream) {
          executions.add(execution);
        }

        expect(executions, hasLength(2));
        expect(executions[0].id, equals('exec-1'));
        expect(executions[1].id, equals('exec-2'));
      });
    });

    group('throttledExecution', () {
      test('should throttle workflow starts', () async {
        mockHttp.mockStartWorkflow('webhook-1', 'exec-1', WorkflowStatus.running);

        final dataStream = Stream.periodic(
          const Duration(milliseconds: 100),
          (i) => MapEntry('webhook-1', {'count': i}),
        ).take(5);

        final stream = client.throttledExecution(
          dataStream,
          const Duration(milliseconds: 300),
        );

        final startTimes = <DateTime>[];
        final sub = stream.listen((_) {
          startTimes.add(DateTime.now());
        });

        await Future.delayed(const Duration(seconds: 2));
        await sub.cancel();

        // Verify throttling - should have fewer emissions than input stream
        expect(startTimes.length, lessThan(5));
      }, timeout: const Timeout(Duration(seconds: 5)));
    });

    group('Integration', () {
      test('should combine multiple operators', () async {
        // Start two workflows, race them, then batch the result
        mockHttp.mockStartWorkflow('webhook-1', 'exec-1', WorkflowStatus.running);
        mockHttp.mockStartWorkflow('webhook-2', 'exec-2', WorkflowStatus.running);
        mockHttp.mockExecutionStatus('exec-1', WorkflowStatus.success);
        mockHttp.mockExecutionStatus('exec-2', WorkflowStatus.running);

        final pairs = [
          const MapEntry('webhook-1', {'test': '1'}),
          const MapEntry('webhook-2', {'test': '2'}),
        ];

        // Use race to get fastest
        final raceStream = client.raceWorkflows(pairs);

        await expectLater(
          raceStream,
          emits(isA<WorkflowExecution>()),
        );
      });
    });
  });
}
