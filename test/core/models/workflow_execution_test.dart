import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowExecution - New Fields (Priority 1 & 2)', () {
    final now = DateTime.now();
    final stoppedTime = now.add(const Duration(seconds: 30));
    final waitTillTime = now.add(const Duration(minutes: 5));

    group('lastNodeExecuted field', () {
      test('should parse lastNodeExecuted from JSON', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'waiting',
          'startedAt': now.toIso8601String(),
          'lastNodeExecuted': 'Wait_Node_1',
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.lastNodeExecuted, equals('Wait_Node_1'));
      });

      test('should handle missing lastNodeExecuted', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'running',
          'startedAt': now.toIso8601String(),
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.lastNodeExecuted, isNull);
      });

      test('should serialize lastNodeExecuted to JSON', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          lastNodeExecuted: 'HTTP_Request_Node',
        );

        final json = execution.toJson();

        expect(json['lastNodeExecuted'], equals('HTTP_Request_Node'));
      });

      test('should not include lastNodeExecuted in JSON when null', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.running,
          startedAt: now,
        );

        final json = execution.toJson();

        expect(json.containsKey('lastNodeExecuted'), isFalse);
      });

      test('should support copyWith for lastNodeExecuted', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
        );

        final updated = execution.copyWith(lastNodeExecuted: 'Wait_Node_2');

        expect(updated.lastNodeExecuted, equals('Wait_Node_2'));
        expect(execution.lastNodeExecuted, isNull);
      });
    });

    group('stoppedAt field', () {
      test('should parse stoppedAt from JSON', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'waiting',
          'startedAt': now.toIso8601String(),
          'stoppedAt': stoppedTime.toIso8601String(),
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.stoppedAt, isNotNull);
        expect(
          result.value!.stoppedAt!.millisecondsSinceEpoch,
          equals(stoppedTime.millisecondsSinceEpoch),
        );
      });

      test('should handle missing stoppedAt', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'running',
          'startedAt': now.toIso8601String(),
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.stoppedAt, isNull);
      });

      test('should handle invalid stoppedAt format', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'waiting',
          'startedAt': now.toIso8601String(),
          'stoppedAt': 'invalid-date',
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('stoppedAt')), isTrue);
      });

      test('should serialize stoppedAt to JSON', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          stoppedAt: stoppedTime,
        );

        final json = execution.toJson();

        expect(json['stoppedAt'], equals(stoppedTime.toIso8601String()));
      });

      test('should support copyWith for stoppedAt', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
        );

        final updated = execution.copyWith(stoppedAt: stoppedTime);

        expect(updated.stoppedAt, equals(stoppedTime));
        expect(execution.stoppedAt, isNull);
      });
    });

    group('waitTill field', () {
      test('should parse waitTill from JSON', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'waiting',
          'startedAt': now.toIso8601String(),
          'waitTill': waitTillTime.toIso8601String(),
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.waitTill, isNotNull);
        expect(
          result.value!.waitTill!.millisecondsSinceEpoch,
          equals(waitTillTime.millisecondsSinceEpoch),
        );
      });

      test('should handle missing waitTill', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'running',
          'startedAt': now.toIso8601String(),
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.waitTill, isNull);
      });

      test('should handle invalid waitTill format', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'waiting',
          'startedAt': now.toIso8601String(),
          'waitTill': 'not-a-date',
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isFalse);
        expect(result.errors.any((e) => e.contains('waitTill')), isTrue);
      });

      test('should serialize waitTill to JSON', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          waitTill: waitTillTime,
        );

        final json = execution.toJson();

        expect(json['waitTill'], equals(waitTillTime.toIso8601String()));
      });

      test('should support copyWith for waitTill', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
        );

        final updated = execution.copyWith(waitTill: waitTillTime);

        expect(updated.waitTill, equals(waitTillTime));
        expect(execution.waitTill, isNull);
      });

      test('should support timeout detection with waitTill', () {
        final pastTime = DateTime.now().subtract(const Duration(minutes: 1));
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          waitTill: pastTime,
        );

        final isExpired = execution.waitTill!.isBefore(DateTime.now());

        expect(isExpired, isTrue);
      });
    });

    group('resumeUrl field', () {
      const testResumeUrl = 'https://n8n.example.com/webhook/resume-abc123';

      test('should parse resumeUrl from JSON', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'waiting',
          'startedAt': now.toIso8601String(),
          'resumeUrl': testResumeUrl,
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.resumeUrl, equals(testResumeUrl));
      });

      test('should handle missing resumeUrl', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'running',
          'startedAt': now.toIso8601String(),
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.resumeUrl, isNull);
      });

      test('should serialize resumeUrl to JSON', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          resumeUrl: testResumeUrl,
        );

        final json = execution.toJson();

        expect(json['resumeUrl'], equals(testResumeUrl));
      });

      test('should not include resumeUrl in JSON when null', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.running,
          startedAt: now,
        );

        final json = execution.toJson();

        expect(json.containsKey('resumeUrl'), isFalse);
      });

      test('should support copyWith for resumeUrl', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
        );

        final updated = execution.copyWith(resumeUrl: testResumeUrl);

        expect(updated.resumeUrl, equals(testResumeUrl));
        expect(execution.resumeUrl, isNull);
      });
    });

    group('Combined new fields scenarios', () {
      test('should handle all new fields together', () {
        final json = {
          'id': 'exec-123',
          'workflowId': 'wf-456',
          'status': 'waiting',
          'startedAt': now.toIso8601String(),
          'lastNodeExecuted': 'Wait_Node_1',
          'stoppedAt': stoppedTime.toIso8601String(),
          'waitTill': waitTillTime.toIso8601String(),
          'resumeUrl': 'https://n8n.example.com/webhook/resume-abc',
        };

        final result = WorkflowExecution.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.lastNodeExecuted, equals('Wait_Node_1'));
        expect(result.value!.stoppedAt, isNotNull);
        expect(result.value!.waitTill, isNotNull);
        expect(result.value!.resumeUrl, isNotNull);
      });

      test('should serialize all new fields together', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          lastNodeExecuted: 'Form_Node',
          stoppedAt: stoppedTime,
          waitTill: waitTillTime,
          resumeUrl: 'https://n8n.example.com/form/submit-xyz',
        );

        final json = execution.toJson();

        expect(json['lastNodeExecuted'], equals('Form_Node'));
        expect(json['stoppedAt'], isNotNull);
        expect(json['waitTill'], isNotNull);
        expect(json['resumeUrl'], isNotNull);
      });

      test('should handle round-trip JSON conversion', () {
        final original = WorkflowExecution(
          id: 'exec-789',
          workflowId: 'wf-012',
          status: WorkflowStatus.waiting,
          startedAt: now,
          lastNodeExecuted: 'Webhook_Wait',
          stoppedAt: stoppedTime,
          waitTill: waitTillTime,
          resumeUrl: 'https://n8n.example.com/webhook/abc',
          waitingForInput: true,
        );

        final json = original.toJson();
        final parsed = WorkflowExecution.fromJson(json);

        expect(parsed.id, equals(original.id));
        expect(parsed.lastNodeExecuted, equals(original.lastNodeExecuted));
        expect(
          parsed.stoppedAt!.millisecondsSinceEpoch,
          equals(original.stoppedAt!.millisecondsSinceEpoch),
        );
        expect(
          parsed.waitTill!.millisecondsSinceEpoch,
          equals(original.waitTill!.millisecondsSinceEpoch),
        );
        expect(parsed.resumeUrl, equals(original.resumeUrl));
      });

      test('should support copyWith with multiple new fields', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.running,
          startedAt: now,
        );

        final updated = execution.copyWith(
          status: WorkflowStatus.waiting,
          lastNodeExecuted: 'Updated_Node',
          stoppedAt: stoppedTime,
          waitTill: waitTillTime,
          resumeUrl: 'https://updated.url/webhook',
        );

        expect(updated.status, equals(WorkflowStatus.waiting));
        expect(updated.lastNodeExecuted, equals('Updated_Node'));
        expect(updated.stoppedAt, equals(stoppedTime));
        expect(updated.waitTill, equals(waitTillTime));
        expect(updated.resumeUrl, equals('https://updated.url/webhook'));
        // Original should be unchanged
        expect(execution.lastNodeExecuted, isNull);
      });
    });

    group('n8nui compatibility scenarios', () {
      test('should track workflow position with lastNodeExecuted', () {
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          lastNodeExecuted: 'Form_Submission_Wait',
          waitingForInput: true,
        );

        expect(execution.lastNodeExecuted, isNotNull);
        expect(execution.waitingForInput, isTrue);
        expect(execution.status, equals(WorkflowStatus.waiting));
      });

      test('should distinguish pause vs completion with stoppedAt', () {
        final paused = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          stoppedAt: stoppedTime,
        );

        final completed = WorkflowExecution(
          id: 'exec-456',
          workflowId: 'wf-789',
          status: WorkflowStatus.success,
          startedAt: now,
          finishedAt: stoppedTime,
        );

        // Paused has stoppedAt but no finishedAt
        expect(paused.stoppedAt, isNotNull);
        expect(paused.finishedAt, isNull);

        // Completed has finishedAt
        expect(completed.finishedAt, isNotNull);
        expect(completed.isFinished, isTrue);
      });

      test('should enable timeout detection with waitTill', () {
        final futureTime = DateTime.now().add(const Duration(minutes: 10));
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          waitTill: futureTime,
        );

        final timeoutCheckable = execution.waitTill != null;
        expect(timeoutCheckable, isTrue);
      });

      test('should provide direct resume URL access', () {
        const resumeUrl = 'https://n8n.example.com/webhook/resume-xyz';
        final execution = WorkflowExecution(
          id: 'exec-123',
          workflowId: 'wf-456',
          status: WorkflowStatus.waiting,
          startedAt: now,
          resumeUrl: resumeUrl,
          waitingForInput: true,
        );

        // Direct access without parsing waitNodeData
        expect(execution.resumeUrl, equals(resumeUrl));
        expect(execution.resumeUrl, isNotNull);
      });
    });
  });
}
