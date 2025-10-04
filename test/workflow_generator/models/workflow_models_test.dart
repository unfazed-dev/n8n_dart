import 'dart:convert';
import 'dart:io';
import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('NodePosition', () {
    test('creates position with x and y coordinates', () {
      const position = NodePosition(100, 200);

      expect(position.x, equals(100));
      expect(position.y, equals(200));
    });

    test('converts to JSON array', () {
      const position = NodePosition(150.5, 250.75);

      expect(position.toJson(), equals([150.5, 250.75]));
    });
  });

  group('NodeConnection', () {
    test('creates connection with required fields', () {
      const connection = NodeConnection(node: 'TargetNode');

      expect(connection.node, equals('TargetNode'));
      expect(connection.type, equals('main'));
      expect(connection.index, equals(0));
    });

    test('creates connection with custom values', () {
      const connection = NodeConnection(
        node: 'CustomNode',
        type: 'custom',
        index: 2,
      );

      expect(connection.node, equals('CustomNode'));
      expect(connection.type, equals('custom'));
      expect(connection.index, equals(2));
    });

    test('converts to JSON', () {
      const connection = NodeConnection(
        node: 'TestNode',
        index: 1,
      );

      final json = connection.toJson();

      expect(json['node'], equals('TestNode'));
      expect(json['type'], equals('main'));
      expect(json['index'], equals(1));
    });
  });

  group('WorkflowNode', () {
    test('creates node with required fields', () {
      final node = WorkflowNode(
        name: 'Test Node',
        type: 'n8n-nodes-base.webhook',
        position: const NodePosition(100, 200),
      );

      expect(node.name, equals('Test Node'));
      expect(node.type, equals('n8n-nodes-base.webhook'));
      expect(node.position.x, equals(100));
      expect(node.position.y, equals(200));
      expect(node.typeVersion, equals(1));
      expect(node.parameters, isEmpty);
    });

    test('generates unique ID when not provided', () {
      final node1 = WorkflowNode(
        name: 'Node 1',
        type: 'n8n-nodes-base.webhook',
        position: const NodePosition(100, 200),
      );

      final node2 = WorkflowNode(
        name: 'Node 2',
        type: 'n8n-nodes-base.webhook',
        position: const NodePosition(300, 200),
      );

      expect(node1.id, isNotEmpty);
      expect(node2.id, isNotEmpty);
      expect(node1.id, isNot(equals(node2.id)));
    });

    test('uses provided ID when specified', () {
      final node = WorkflowNode(
        id: 'custom-id-123',
        name: 'Test Node',
        type: 'n8n-nodes-base.webhook',
        position: const NodePosition(100, 200),
      );

      expect(node.id, equals('custom-id-123'));
    });

    test('includes optional fields in JSON', () {
      final node = WorkflowNode(
        name: 'Test Node',
        type: 'n8n-nodes-base.postgres',
        position: const NodePosition(100, 200),
        parameters: {'operation': 'select', 'table': 'users'},
        credentials: {'postgres': {'id': 'cred-1', 'name': 'PostgreSQL'}},
        disabled: true,
        alwaysOutputData: true,
        notes: 'This is a test note',
        notesInFlow: 'Flow note',
      );

      final json = node.toJson();

      expect(json['parameters'], equals({'operation': 'select', 'table': 'users'}));
      expect(json['credentials'], isNotNull);
      expect(json['disabled'], isTrue);
      expect(json['alwaysOutputData'], isTrue);
      expect(json['notes'], equals('This is a test note'));
      expect(json['notesInFlow'], equals('Flow note'));
    });

    test('converts to valid JSON', () {
      final node = WorkflowNode(
        id: 'test-123',
        name: 'Webhook Trigger',
        type: 'n8n-nodes-base.webhook',
        position: const NodePosition(100, 200),
        parameters: {
          'path': 'test-webhook',
          'method': 'POST',
        },
      );

      final json = node.toJson();

      expect(json['id'], equals('test-123'));
      expect(json['name'], equals('Webhook Trigger'));
      expect(json['type'], equals('n8n-nodes-base.webhook'));
      expect(json['typeVersion'], equals(1));
      expect(json['position'], equals([100.0, 200.0]));
      expect(json['parameters']['path'], equals('test-webhook'));
      expect(json['parameters']['method'], equals('POST'));
    });
  });

  group('WorkflowSettings', () {
    test('creates settings with default values', () {
      const settings = WorkflowSettings();

      expect(settings.executionMode, equals('sequential'));
      expect(settings.timezone, equals('UTC'));
    });

    test('creates settings with custom values', () {
      const settings = WorkflowSettings(
        executionMode: 'parallel',
        timezone: 'America/New_York',
        executionTimeout: 3600,
        saveExecutionProgress: true,
      );

      expect(settings.executionMode, equals('parallel'));
      expect(settings.timezone, equals('America/New_York'));
      expect(settings.executionTimeout, equals(3600));
      expect(settings.saveExecutionProgress, isTrue);
    });

    test('converts to JSON with only non-null values', () {
      const settings = WorkflowSettings(
        executionTimeout: 3600,
      );

      final json = settings.toJson();

      expect(json['executionMode'], equals('sequential'));
      expect(json['timezone'], equals('UTC'));
      expect(json['executionTimeout'], equals(3600));
      expect(json.containsKey('saveExecutionProgress'), isFalse);
    });

    test('includes all optional save settings', () {
      const settings = WorkflowSettings(
        saveExecutionProgress: true,
        saveManualExecutions: true,
        saveDataErrorExecution: true,
        saveDataSuccessExecution: true,
      );

      final json = settings.toJson();

      expect(json['saveExecutionProgress'], isTrue);
      expect(json['saveManualExecutions'], isTrue);
      expect(json['saveDataErrorExecution'], isTrue);
      expect(json['saveDataSuccessExecution'], isTrue);
    });
  });

  group('N8nWorkflow', () {
    test('creates minimal workflow', () {
      const workflow = N8nWorkflow(
        name: 'Test Workflow',
        nodes: [],
        connections: {},
      );

      expect(workflow.name, equals('Test Workflow'));
      expect(workflow.active, isFalse);
      expect(workflow.version, equals(1.0));
      expect(workflow.nodes, isEmpty);
      expect(workflow.connections, isEmpty);
    });

    test('creates workflow with nodes and connections', () {
      final node1 = WorkflowNode(
        id: 'node1',
        name: 'Start',
        type: 'n8n-nodes-base.webhook',
        position: const NodePosition(100, 200),
      );

      final node2 = WorkflowNode(
        id: 'node2',
        name: 'End',
        type: 'n8n-nodes-base.respondToWebhook',
        position: const NodePosition(300, 200),
      );

      final workflow = N8nWorkflow(
        name: 'Simple Workflow',
        active: true,
        nodes: [node1, node2],
        connections: {
          'Start': {
            'main': [
              [
                const NodeConnection(node: 'End'),
              ],
            ],
          },
        },
      );

      expect(workflow.name, equals('Simple Workflow'));
      expect(workflow.active, isTrue);
      expect(workflow.nodes.length, equals(2));
      expect(workflow.connections.length, equals(1));
    });

    test('converts to JSON string', () {
      const workflow = N8nWorkflow(
        name: 'Test',
        nodes: [],
        connections: {},
      );

      final jsonString = workflow.toJson();
      final decoded = jsonDecode(jsonString);

      expect(decoded['name'], equals('Test'));
      expect(decoded['active'], isFalse);
      expect(decoded['nodes'], isEmpty);
      expect(decoded['connections'], isEmpty);
    });

    test('includes tags when provided', () {
      const workflow = N8nWorkflow(
        name: 'Tagged Workflow',
        tags: ['production', 'api'],
        nodes: [],
        connections: {},
      );

      final jsonString = workflow.toJson();
      final decoded = jsonDecode(jsonString);

      expect(decoded['tags'], equals(['production', 'api']));
    });

    test('creates valid n8n workflow JSON structure', () {
      final node = WorkflowNode(
        id: 'webhook1',
        name: 'Webhook',
        type: 'n8n-nodes-base.webhook',
        position: const NodePosition(100, 200),
        parameters: {
          'path': 'test',
          'method': 'POST',
        },
      );

      final workflow = N8nWorkflow(
        name: 'Complete Workflow',
        active: true,
        nodes: [node],
        connections: {},
        tags: ['test'],
      );

      final jsonString = workflow.toJson();
      final decoded = jsonDecode(jsonString);

      expect(decoded['name'], equals('Complete Workflow'));
      expect(decoded['active'], isTrue);
      expect(decoded['settings']['executionMode'], equals('sequential'));
      expect(decoded['nodes'].length, equals(1));
      expect(decoded['nodes'][0]['name'], equals('Webhook'));
      expect(decoded['tags'], equals(['test']));
    });

    test('saves to file successfully', () async {
      const workflow = N8nWorkflow(
        name: 'File Test',
        nodes: [],
        connections: {},
      );

      final tempDir = Directory.systemTemp.createTempSync('n8n_test_');
      final filePath = '${tempDir.path}/test_workflow.json';

      await workflow.saveToFile(filePath);

      final file = File(filePath);
      expect(file.existsSync(), isTrue);

      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      expect(decoded['name'], equals('File Test'));

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });

    test('fromJson creates workflow from JSON string', () {
      const jsonString = '''
      {
        "name": "Imported Workflow",
        "active": true,
        "nodes": [
          {
            "id": "node1",
            "name": "Test Node",
            "type": "n8n-nodes-base.webhook",
            "typeVersion": 1,
            "position": [100, 200],
            "parameters": {"path": "test"}
          }
        ],
        "connections": {},
        "settings": {
          "executionMode": "sequential",
          "timezone": "UTC"
        },
        "tags": ["imported"]
      }
      ''';

      final workflow = N8nWorkflow.fromJson(jsonString);

      expect(workflow.name, equals('Imported Workflow'));
      expect(workflow.active, isTrue);
      expect(workflow.nodes.length, equals(1));
      expect(workflow.nodes[0].name, equals('Test Node'));
      expect(workflow.tags, equals(['imported']));
    });

    test('round-trip JSON serialization preserves data', () {
      final original = N8nWorkflow(
        name: 'Round Trip Test',
        active: true,
        nodes: [
          WorkflowNode(
            id: 'node1',
            name: 'Test',
            type: 'n8n-nodes-base.webhook',
            position: const NodePosition(100, 200),
            parameters: {'test': 'value'},
          ),
        ],
        connections: {
          'Test': {
            'main': [
              [const NodeConnection(node: 'Node2')],
            ],
          },
        },
        tags: ['test'],
      );

      // Serialize to JSON
      final jsonString = original.toJson();

      // Deserialize back
      final restored = N8nWorkflow.fromJson(jsonString);

      expect(restored.name, equals(original.name));
      expect(restored.active, equals(original.active));
      expect(restored.nodes.length, equals(original.nodes.length));
      expect(restored.nodes[0].name, equals(original.nodes[0].name));
      expect(restored.tags, equals(original.tags));
      expect(restored.connections.keys.length, equals(1));
    });
  });

  group('WorkflowNode edge cases', () {
    test('handles empty parameters', () {
      final node = WorkflowNode(
        name: 'Empty Params',
        type: 'n8n-nodes-base.test',
        position: const NodePosition(0, 0),
        parameters: {},
      );

      final json = node.toJson();
      expect(json['parameters'], isEmpty);
    });

    test('handles null optional fields', () {
      final node = WorkflowNode(
        name: 'Minimal',
        type: 'n8n-nodes-base.test',
        position: const NodePosition(0, 0),
      );

      final json = node.toJson();
      expect(json.containsKey('credentials'), isFalse);
      expect(json.containsKey('disabled'), isFalse);
      expect(json.containsKey('notes'), isFalse);
    });
  });

  group('N8nWorkflow connections', () {
    test('handles complex connection structures', () {
      const workflow = N8nWorkflow(
        name: 'Complex Connections',
        nodes: [],
        connections: {
          'Node1': {
            'main': [
              [
                NodeConnection(node: 'Node2'),
                NodeConnection(node: 'Node3'),
              ],
            ],
          },
          'Node2': {
            'main': [
              [NodeConnection(node: 'Node4')],
            ],
          },
        },
      );

      final jsonString = workflow.toJson();
      final decoded = jsonDecode(jsonString);

      expect(decoded['connections']['Node1']['main'][0].length, equals(2));
      expect(decoded['connections']['Node2']['main'][0].length, equals(1));
    });

    test('handles empty connections', () {
      const workflow = N8nWorkflow(
        name: 'No Connections',
        nodes: [],
        connections: {},
      );

      final jsonString = workflow.toJson();
      final decoded = jsonDecode(jsonString);

      expect(decoded['connections'], isEmpty);
    });
  });
}
