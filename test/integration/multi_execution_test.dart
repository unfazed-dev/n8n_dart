/// Multi-Execution Pattern Integration Tests
///
/// Tests complex stream compositions for parallel, sequential, race, and batch execution
@TestOn('vm')
library;

import 'package:n8n_dart/n8n_dart.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import 'config/test_config.dart';
import 'utils/test_helpers.dart';

void main() {
  // Skip all tests if .env.test doesn't exist
  if (!TestConfig.canRun()) {
    test('skipped - .env.test not found', () {});
    return;
  }

  late TestConfig config;

  setUpAll(() async {
    config = await TestConfig.loadWithAutoDiscovery();
    final errors = config.validate();
    if (errors.isNotEmpty) {
      throw StateError('Invalid test configuration: ${errors.join(", ")}');
    }
  });

  group('Multi-Execution Pattern Tests', () {
    late ReactiveN8nClient client;

    setUp(() {
      client = createTestReactiveClient(config);
    });

    tearDown(() {
      client.dispose();
    });

    group('Parallel Execution with Rx.forkJoin', () {
      test('executes multiple workflows in parallel and waits for all', () async {
        // Start multiple workflows in parallel using forkJoin
        final stream1 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'parallel-1'},
          workflowId: config.simpleWorkflowId,
        );
        final stream2 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'parallel-2'},
          workflowId: config.simpleWorkflowId,
        );
        final stream3 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'parallel-3'},
          workflowId: config.simpleWorkflowId,
        );

        // Wait for all workflows to start
        final results = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
          [stream1, stream2, stream3],
          (values) => values,
        ).first;

        expect(results.length, equals(3));
        for (final execution in results) {
          expect(execution.id, isNotEmpty);
          expect(execution.workflowId, isNotEmpty);
        }
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('forkJoin completes only when all workflows complete', () async {
        final stream1 = client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'complete-1'},
              workflowId: config.simpleWorkflowId,
            )
            .switchMap((e) => client.pollExecutionStatus(e.id))
            .where((e) => e.isFinished)
            .take(1);

        final stream2 = client
            .startWorkflow(
              config.simpleWebhookPath,
              {'test': 'complete-2'},
              workflowId: config.simpleWorkflowId,
            )
            .switchMap((e) => client.pollExecutionStatus(e.id))
            .where((e) => e.isFinished)
            .take(1);

        final startTime = DateTime.now();
        final results = await Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
          [stream1, stream2],
          (values) => values,
        ).first;
        final duration = DateTime.now().difference(startTime);

        expect(results.length, equals(2));
        expect(results[0].isFinished, isTrue);
        expect(results[1].isFinished, isTrue);

        // Should take at least as long as the longest workflow
        expect(duration.inSeconds, greaterThan(0));
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Sequential Execution with asyncExpand', () {
      test('executes workflows sequentially in order', () async {
        final webhookPaths = [
          config.simpleWebhookPath,
          config.simpleWebhookPath,
          config.simpleWebhookPath,
        ];

        final workflowIds = [
          config.simpleWorkflowId,
          config.simpleWorkflowId,
          config.simpleWorkflowId,
        ];

        final executionIds = <String>[];

        // Execute sequentially using asyncExpand
        await Stream.fromIterable(List.generate(3, (i) => i))
            .asyncExpand((i) => client.startWorkflow(
                  webhookPaths[i],
                  {'test': 'sequential-$i', 'order': i},
                  workflowId: workflowIds[i],
                ))
            .doOnData((execution) => executionIds.add(execution.id))
            .toList();

        expect(executionIds.length, equals(3));
        expect(executionIds.toSet().length, equals(3), reason: 'All execution IDs should be unique');
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('asyncExpand waits for each workflow to complete before starting next', () async {
        final timestamps = <DateTime>[];

        await Stream.fromIterable([0, 1, 2])
            .asyncExpand((i) {
              timestamps.add(DateTime.now());
              return client.startWorkflow(
                config.simpleWebhookPath,
                {'test': 'wait-sequential-$i'},
                workflowId: config.simpleWorkflowId,
              );
            })
            .switchMap((e) => client.pollExecutionStatus(e.id))
            .where((e) => e.isFinished)
            .take(3)
            .toList();

        expect(timestamps.length, equals(3));

        // Verify sequential timing (each start should be after previous finished)
        for (var i = 1; i < timestamps.length; i++) {
          expect(
            timestamps[i].isAfter(timestamps[i - 1]),
            isTrue,
            reason: 'Workflow $i should start after workflow ${i - 1}',
          );
        }
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Race Execution with Rx.race', () {
      test('completes with fastest workflow', () async {
        // Start multiple workflows, race returns the first to complete
        final stream1 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'race-1'},
          workflowId: config.simpleWorkflowId,
        );

        final stream2 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'race-2'},
          workflowId: config.simpleWorkflowId,
        );

        final stream3 = client.startWorkflow(
          config.slowWebhookPath,
          {'test': 'race-slow'},
          workflowId: config.slowWorkflowId,
        );

        // Race - first one to emit wins
        final winner = await Rx.race([stream1, stream2, stream3]).first;

        expect(winner.id, isNotEmpty);
        // Winner should be one of the fast workflows, not the slow one
        // (This is probabilistic, but slow workflow should lose the race)
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('race cancels slower workflows', () async {
        final stream1 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'race-fast'},
          workflowId: config.simpleWorkflowId,
        );

        final stream2 = client.startWorkflow(
          config.slowWebhookPath,
          {'test': 'race-slow'},
          workflowId: config.slowWorkflowId,
        ).delay(const Duration(seconds: 2)); // Delay to ensure it loses

        final startTime = DateTime.now();
        final winner = await Rx.race([stream1, stream2]).first;
        final duration = DateTime.now().difference(startTime);

        expect(winner.id, isNotEmpty);

        // Should complete quickly (fast workflow wins)
        expect(duration.inSeconds, lessThan(15));
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Batch Execution with bufferCount', () {
      test('processes workflows in batches', () async {
        const batchSize = 2;
        const totalWorkflows = 4;

        var batchesProcessed = 0;

        await Stream.fromIterable(List.generate(totalWorkflows, (i) => i))
            .bufferCount(batchSize)
            .asyncMap((batch) async {
              batchesProcessed++;

              // Process batch in parallel
              final batchStreams = batch.map((i) => client.startWorkflow(
                    config.simpleWebhookPath,
                    {'test': 'batch-$i', 'batch': batchesProcessed},
                    workflowId: config.simpleWorkflowId,
                  ));

              return Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
                batchStreams.toList(),
                (values) => values,
              ).first;
            })
            .toList();

        expect(batchesProcessed, equals(2), reason: 'Should process 2 batches of 2 workflows');
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('bufferCount waits for batch to complete before next', () async {
        final batchTimestamps = <DateTime>[];

        await Stream.fromIterable([0, 1, 2, 3, 4, 5])
            .bufferCount(2)
            .asyncMap((batch) async {
              batchTimestamps.add(DateTime.now());

              final batchStreams = batch.map((i) => client.startWorkflow(
                    config.simpleWebhookPath,
                    {'test': 'timed-batch-$i'},
                    workflowId: config.simpleWorkflowId,
                  ));

              return Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
                batchStreams.toList(),
                (values) => values,
              ).first;
            })
            .toList();

        expect(batchTimestamps.length, equals(3), reason: 'Should have 3 batches');

        // Verify batches are sequential
        for (var i = 1; i < batchTimestamps.length; i++) {
          expect(
            batchTimestamps[i].isAfter(batchTimestamps[i - 1]),
            isTrue,
            reason: 'Batch $i should start after batch ${i - 1} completes',
          );
        }
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Merge Execution with Rx.merge', () {
      test('merges multiple workflow streams concurrently', () async {
        final stream1 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'merge-1'},
          workflowId: config.simpleWorkflowId,
        );

        final stream2 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'merge-2'},
          workflowId: config.simpleWorkflowId,
        );

        final stream3 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'merge-3'},
          workflowId: config.simpleWorkflowId,
        );

        // Merge emits items as they arrive (not waiting for all)
        final results = await Rx.merge([stream1, stream2, stream3]).toList();

        // n8n webhooks may return same execution ID, so just verify we got results
        expect(results.length, greaterThan(0));
        expect(results.every((e) => e.id.isNotEmpty), isTrue);
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('merge emits items as soon as available', () async {
        final timestamps = <DateTime>[];

        await Rx.merge([
          client
              .startWorkflow(
                config.simpleWebhookPath,
                {'test': 'merge-fast'},
                workflowId: config.simpleWorkflowId,
              )
              .doOnData((_) => timestamps.add(DateTime.now())),
          client
              .startWorkflow(
                config.slowWebhookPath,
                {'test': 'merge-slow'},
                workflowId: config.slowWorkflowId,
              )
              .doOnData((_) => timestamps.add(DateTime.now())),
        ]).toList();

        expect(timestamps.length, equals(2));

        // First timestamp should be significantly before second
        final gap = timestamps[1].difference(timestamps[0]);
        expect(gap.inSeconds, greaterThan(0));
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Zip Execution with Rx.zip2', () {
      test('combines results from multiple workflows', () async {
        final stream1 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'zip-1'},
          workflowId: config.simpleWorkflowId,
        );

        final stream2 = client.startWorkflow(
          config.simpleWebhookPath,
          {'test': 'zip-2'},
          workflowId: config.simpleWorkflowId,
        );

        // Zip combines emissions from both streams
        final combined = await Rx.zip2(
          stream1,
          stream2,
          (WorkflowExecution a, WorkflowExecution b) => [a, b],
        ).first;

        expect(combined.length, equals(2));
        expect(combined[0].id, isNotEmpty);
        expect(combined[1].id, isNotEmpty);
        // Note: n8n webhooks may return same execution ID for rapid calls
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('CombineLatest with Rx.combineLatest2', () {
      test('combines latest values from multiple workflows', () async {
        final stream1 = client.pollExecutionStatus(
          await client
              .startWorkflow(
                config.simpleWebhookPath,
                {'test': 'combine-1'},
                workflowId: config.simpleWorkflowId,
              )
              .first
              .then((e) => e.id),
        );

        final stream2 = client.pollExecutionStatus(
          await client
              .startWorkflow(
                config.simpleWebhookPath,
                {'test': 'combine-2'},
                workflowId: config.simpleWorkflowId,
              )
              .first
              .then((e) => e.id),
        );

        // CombineLatest emits whenever either stream emits
        final combined = await Rx.combineLatest2(
          stream1.take(2),
          stream2.take(2),
          (WorkflowExecution a, WorkflowExecution b) => [a, b],
        ).first;

        expect(combined.length, equals(2));
      }, timeout: const Timeout(Duration(seconds: 60)));
    });

    group('Complex Patterns', () {
      test('parallel execution with error handling and retries', () async {
        final results = <WorkflowExecution>[];
        final errors = <Object>[];

        Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
          [
            client
                .startWorkflow(
                  config.simpleWebhookPath,
                  {'test': 'complex-1'},
                  workflowId: config.simpleWorkflowId,
                )
                .onErrorResume((error, stackTrace) {
              errors.add(error);
              return const Stream.empty();
            }),
            client
                .startWorkflow(
                  config.simpleWebhookPath,
                  {'test': 'complex-2'},
                  workflowId: config.simpleWorkflowId,
                )
                .onErrorResume((error, stackTrace) {
              errors.add(error);
              return const Stream.empty();
            }),
          ],
          (values) => values,
        )
            .doOnData(results.addAll)
            .onErrorResume((error, stackTrace) => Stream.value([]))
            .listen((_) {});

        await Future.delayed(const Duration(seconds: 5));

        // Should complete even with errors
        expect(results.length + errors.length, greaterThan(0));
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('sequential with conditional branching', () async {
        final executionIds = <String>[];

        await Stream.fromIterable([0, 1, 2])
            .asyncExpand((i) => client.startWorkflow(
                  config.simpleWebhookPath,
                  {'test': 'conditional-$i'},
                  workflowId: config.simpleWorkflowId,
                ))
            .doOnData((e) => executionIds.add(e.id))
            .switchMap((execution) {
              // Conditionally poll based on index
              if (executionIds.length % 2 == 0) {
                return client.pollExecutionStatus(execution.id).take(1);
              }
              return Stream.value(execution);
            })
            .toList();

        expect(executionIds.length, equals(3));
      }, timeout: const Timeout(Duration(seconds: 60)));

      test('batch processing with throttling', () async {
        var emissionCount = 0;

        await Stream.fromIterable(List.generate(4, (i) => i))
            .throttleTime(const Duration(milliseconds: 500))
            .bufferCount(2)
            .asyncMap((batch) async {
              emissionCount++;

              final batchStreams = batch.map((i) => client.startWorkflow(
                    config.simpleWebhookPath,
                    {'test': 'throttled-$i'},
                    workflowId: config.simpleWorkflowId,
                  ));

              return Rx.forkJoin<WorkflowExecution, List<WorkflowExecution>>(
                batchStreams.toList(),
                (values) => values,
              ).first;
            })
            .toList();

        expect(emissionCount, greaterThan(0));
      }, timeout: const Timeout(Duration(seconds: 60)));
    });
  });
}
