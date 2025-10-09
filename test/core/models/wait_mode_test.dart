@TestOn('vm')
library;

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('WaitMode', () {
    group('fromString()', () {
      test('parses timeInterval variations', () {
        expect(WaitMode.fromString('timeInterval'), WaitMode.timeInterval);
        expect(WaitMode.fromString('time_interval'), WaitMode.timeInterval);
        expect(WaitMode.fromString('time-interval'), WaitMode.timeInterval);
        expect(WaitMode.fromString('TIMEINTERVAL'), WaitMode.timeInterval);
      });

      test('parses specifiedTime variations', () {
        expect(WaitMode.fromString('specifiedTime'), WaitMode.specifiedTime);
        expect(WaitMode.fromString('specified_time'), WaitMode.specifiedTime);
        expect(WaitMode.fromString('specified-time'), WaitMode.specifiedTime);
        expect(WaitMode.fromString('SPECIFIEDTIME'), WaitMode.specifiedTime);
      });

      test('parses webhook', () {
        expect(WaitMode.fromString('webhook'), WaitMode.webhook);
        expect(WaitMode.fromString('WEBHOOK'), WaitMode.webhook);
      });

      test('parses form', () {
        expect(WaitMode.fromString('form'), WaitMode.form);
        expect(WaitMode.fromString('FORM'), WaitMode.form);
      });

      test('returns unknown for invalid values', () {
        expect(WaitMode.fromString('invalid'), WaitMode.unknown);
        expect(WaitMode.fromString(''), WaitMode.unknown);
        expect(WaitMode.fromString('xyz'), WaitMode.unknown);
      });
    });

    group('toString()', () {
      test('serializes timeInterval correctly', () {
        expect(WaitMode.timeInterval.toString(), 'timeInterval');
      });

      test('serializes specifiedTime correctly', () {
        expect(WaitMode.specifiedTime.toString(), 'specifiedTime');
      });

      test('serializes webhook correctly', () {
        expect(WaitMode.webhook.toString(), 'webhook');
      });

      test('serializes form correctly', () {
        expect(WaitMode.form.toString(), 'form');
      });

      test('serializes unknown correctly', () {
        expect(WaitMode.unknown.toString(), 'unknown');
      });
    });
  });

  group('WaitNodeData - Enhanced Fields', () {
    group('mode field', () {
      test('defaults to unknown when not provided', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.mode, WaitMode.unknown);
      });

      test('parses mode from "mode" field', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'mode': 'webhook',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.mode, WaitMode.webhook);
      });

      test('infers mode from "resume" field as fallback', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'resume': 'form',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.mode, WaitMode.form);
      });

      test('mode field takes precedence over resume field', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'mode': 'webhook',
          'resume': 'form',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.mode, WaitMode.webhook);
      });
    });

    group('resumeUrl field', () {
      test('parses resumeUrl when provided', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'resumeUrl': 'https://n8n.cloud/webhook-waiting/abc123',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.resumeUrl,
            'https://n8n.cloud/webhook-waiting/abc123');
      });

      test('falls back to webhookUrl field', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'webhookUrl': 'https://n8n.cloud/webhook/xyz789',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.resumeUrl, 'https://n8n.cloud/webhook/xyz789');
      });

      test('is null when not provided', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.resumeUrl, isNull);
      });
    });

    group('formUrl field', () {
      test('parses formUrl when provided', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'formUrl': 'https://n8n.cloud/form/def456',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.formUrl, 'https://n8n.cloud/form/def456');
      });

      test('is null when not provided', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.formUrl, isNull);
      });
    });

    group('waitDuration field', () {
      test('parses waitDuration in seconds', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'waitDuration': 300,
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.waitDuration, const Duration(seconds: 300));
      });

      test('is null when not provided', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.waitDuration, isNull);
      });

      test('is null when invalid format', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'waitDuration': 'invalid',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.waitDuration, isNull);
      });
    });

    group('waitUntil field', () {
      test('parses waitUntil datetime', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'waitUntil': '2025-12-25T09:00:00Z',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.waitUntil, DateTime.parse('2025-12-25T09:00:00Z'));
      });

      test('is null when not provided', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.waitUntil, isNull);
      });

      test('is null when invalid format', () {
        final json = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'waitUntil': 'invalid-date',
        };

        final result = WaitNodeData.fromJsonSafe(json);

        expect(result.isValid, isTrue);
        expect(result.value!.waitUntil, isNull);
      });
    });

    group('toJson()', () {
      test('includes mode in JSON output', () {
        final waitNodeData = WaitNodeData(
          nodeId: 'test-node',
          nodeName: 'Test Node',
          fields: const [],
          createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
          mode: WaitMode.webhook,
        );

        final json = waitNodeData.toJson();

        expect(json['mode'], 'webhook');
      });

      test('includes resumeUrl when provided', () {
        final waitNodeData = WaitNodeData(
          nodeId: 'test-node',
          nodeName: 'Test Node',
          fields: const [],
          createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
          resumeUrl: 'https://n8n.cloud/webhook/abc',
        );

        final json = waitNodeData.toJson();

        expect(json['resumeUrl'], 'https://n8n.cloud/webhook/abc');
      });

      test('includes formUrl when provided', () {
        final waitNodeData = WaitNodeData(
          nodeId: 'test-node',
          nodeName: 'Test Node',
          fields: const [],
          createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
          formUrl: 'https://n8n.cloud/form/xyz',
        );

        final json = waitNodeData.toJson();

        expect(json['formUrl'], 'https://n8n.cloud/form/xyz');
      });

      test('includes waitDuration as seconds when provided', () {
        final waitNodeData = WaitNodeData(
          nodeId: 'test-node',
          nodeName: 'Test Node',
          fields: const [],
          createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
          waitDuration: const Duration(minutes: 5),
        );

        final json = waitNodeData.toJson();

        expect(json['waitDuration'], 300);
      });

      test('includes waitUntil as ISO string when provided', () {
        final waitNodeData = WaitNodeData(
          nodeId: 'test-node',
          nodeName: 'Test Node',
          fields: const [],
          createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
          waitUntil: DateTime.parse('2025-12-25T09:00:00Z'),
        );

        final json = waitNodeData.toJson();

        expect(json['waitUntil'], '2025-12-25T09:00:00.000Z');
      });

      test('omits optional fields when null', () {
        final waitNodeData = WaitNodeData(
          nodeId: 'test-node',
          nodeName: 'Test Node',
          fields: const [],
          createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
        );

        final json = waitNodeData.toJson();

        expect(json.containsKey('resumeUrl'), isFalse);
        expect(json.containsKey('formUrl'), isFalse);
        expect(json.containsKey('waitDuration'), isFalse);
        expect(json.containsKey('waitUntil'), isFalse);
      });
    });

    group('toString()', () {
      test('includes mode in string representation', () {
        final waitNodeData = WaitNodeData(
          nodeId: 'test-node',
          nodeName: 'Test Node',
          fields: const [],
          createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
          mode: WaitMode.form,
        );

        final string = waitNodeData.toString();

        expect(string, contains('mode: form'));
      });
    });

    group('roundtrip serialization', () {
      test('fromJson -> toJson preserves all new fields', () {
        final originalJson = {
          'nodeId': 'test-node',
          'nodeName': 'Test Node',
          'fields': [],
          'mode': 'webhook',
          'resumeUrl': 'https://n8n.cloud/webhook/abc',
          'formUrl': 'https://n8n.cloud/form/xyz',
          'waitDuration': 600,
          'waitUntil': '2025-12-25T09:00:00Z',
          'createdAt': '2025-01-01T00:00:00Z',
        };

        final result = WaitNodeData.fromJsonSafe(originalJson);
        expect(result.isValid, isTrue);

        final serializedJson = result.value!.toJson();

        expect(serializedJson['mode'], 'webhook');
        expect(serializedJson['resumeUrl'], 'https://n8n.cloud/webhook/abc');
        expect(serializedJson['formUrl'], 'https://n8n.cloud/form/xyz');
        expect(serializedJson['waitDuration'], 600);
        expect(serializedJson['waitUntil'], '2025-12-25T09:00:00.000Z');
      });
    });
  });

  group('WaitNodeData - Complete Scenarios', () {
    test('time interval wait node scenario', () {
      final json = {
        'nodeId': 'wait-time',
        'nodeName': 'Wait 5 seconds',
        'fields': [],
        'mode': 'timeInterval',
        'waitDuration': 5,
      };

      final result = WaitNodeData.fromJsonSafe(json);

      expect(result.isValid, isTrue);
      expect(result.value!.mode, WaitMode.timeInterval);
      expect(result.value!.waitDuration, const Duration(seconds: 5));
      expect(result.value!.resumeUrl, isNull);
      expect(result.value!.formUrl, isNull);
    });

    test('specified time wait node scenario', () {
      final json = {
        'nodeId': 'wait-until',
        'nodeName': 'Wait until Christmas',
        'fields': [],
        'mode': 'specifiedTime',
        'waitUntil': '2025-12-25T09:00:00Z',
      };

      final result = WaitNodeData.fromJsonSafe(json);

      expect(result.isValid, isTrue);
      expect(result.value!.mode, WaitMode.specifiedTime);
      expect(result.value!.waitUntil, DateTime.parse('2025-12-25T09:00:00Z'));
    });

    test('webhook wait node scenario', () {
      final json = {
        'nodeId': 'wait-webhook',
        'nodeName': 'Wait for webhook',
        'fields': [],
        'mode': 'webhook',
        'resumeUrl': 'https://n8n.cloud/webhook-waiting/abc123',
      };

      final result = WaitNodeData.fromJsonSafe(json);

      expect(result.isValid, isTrue);
      expect(result.value!.mode, WaitMode.webhook);
      expect(result.value!.resumeUrl,
          'https://n8n.cloud/webhook-waiting/abc123');
    });

    test('form submission wait node scenario', () {
      final json = {
        'nodeId': 'wait-form',
        'nodeName': 'Approval Form',
        'fields': [
          {
            'name': 'decision',
            'label': 'Approve?',
            'type': 'select',
            'required': true,
          }
        ],
        'mode': 'form',
        'formUrl': 'https://n8n.cloud/form/xyz789',
      };

      final result = WaitNodeData.fromJsonSafe(json);

      expect(result.isValid, isTrue);
      expect(result.value!.mode, WaitMode.form);
      expect(result.value!.formUrl, 'https://n8n.cloud/form/xyz789');
      expect(result.value!.fields.length, 1);
    });
  });
}
