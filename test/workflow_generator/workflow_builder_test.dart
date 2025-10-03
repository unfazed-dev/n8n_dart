import 'dart:convert';
import 'dart:io';
import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowBuilder - Basic Usage', () {
    test('creates builder with default values', () {
      final builder = WorkflowBuilder.create();
      final workflow = builder.build();

      expect(workflow.name, equals('Untitled Workflow'));
      expect(workflow.active, isFalse);
      expect(workflow.version, equals(1));
      expect(workflow.nodes, isEmpty);
      expect(workflow.connections, isEmpty);
    });

    test('sets workflow name', () {
      final workflow = WorkflowBuilder.create()
          .name('My Custom Workflow')
          .build();

      expect(workflow.name, equals('My Custom Workflow'));
    });

    test('sets workflow as active', () {
      final workflow = WorkflowBuilder.create()
          .active()
          .build();

      expect(workflow.active, isTrue);
    });

    test('sets workflow as inactive explicitly', () {
      final workflow = WorkflowBuilder.create()
          .active(false)
          .build();

      expect(workflow.active, isFalse);
    });

    test('sets workflow version', () {
      final workflow = WorkflowBuilder.create()
          .version(2.0)
          .build();

      expect(workflow.version, equals(2.0));
    });

    test('adds single tag', () {
      final workflow = WorkflowBuilder.create()
          .tag('production')
          .build();

      expect(workflow.tags, equals(['production']));
    });

    test('adds multiple tags', () {
      final workflow = WorkflowBuilder.create()
          .tags(['api', 'production', 'v1'])
          .build();

      expect(workflow.tags, containsAll(['api', 'production', 'v1']));
    });

    test('sets custom settings', () {
      final workflow = WorkflowBuilder.create()
          .settings(const WorkflowSettings(
            executionMode: 'parallel',
            timezone: 'America/New_York',
          ))
          .build();

      expect(workflow.settings.executionMode, equals('parallel'));
      expect(workflow.settings.timezone, equals('America/New_York'));
    });

    test('sets static data', () {
      final workflow = WorkflowBuilder.create()
          .staticData({'key': 'value', 'count': 42})
          .build();

      expect(workflow.staticData, isNotNull);
      expect(workflow.staticData!['key'], equals('value'));
      expect(workflow.staticData!['count'], equals(42));
    });
  });

  group('WorkflowBuilder - Node Management', () {
    test('adds custom node', () {
      final customNode = WorkflowNode(
        name: 'Custom Node',
        type: 'n8n-nodes-base.custom',
        position: const NodePosition(100, 200),
      );

      final workflow = WorkflowBuilder.create()
          .addNode(customNode)
          .build();

      expect(workflow.nodes.length, equals(1));
      expect(workflow.nodes[0].name, equals('Custom Node'));
    });

    test('adds node with auto-positioning', () {
      final workflow = WorkflowBuilder.create()
          .node(
            name: 'Node 1',
            type: 'n8n-nodes-base.test',
          )
          .node(
            name: 'Node 2',
            type: 'n8n-nodes-base.test',
          )
          .build();

      expect(workflow.nodes.length, equals(2));
      expect(workflow.nodes[0].position.x, equals(100));
      expect(workflow.nodes[1].position.x, equals(350)); // 100 + 250
    });

    test('adds node with parameters', () {
      final workflow = WorkflowBuilder.create()
          .node(
            name: 'Configured Node',
            type: 'n8n-nodes-base.postgres',
            parameters: {
              'operation': 'select',
              'table': 'users',
            },
          )
          .build();

      expect(workflow.nodes[0].parameters['operation'], equals('select'));
      expect(workflow.nodes[0].parameters['table'], equals('users'));
    });

    test('adds node with credentials', () {
      final workflow = WorkflowBuilder.create()
          .node(
            name: 'Auth Node',
            type: 'n8n-nodes-base.postgres',
            credentials: {
              'postgres': {'id': 'cred-1', 'name': 'PostgreSQL'}
            },
          )
          .build();

      expect(workflow.nodes[0].credentials, isNotNull);
      expect(workflow.nodes[0].credentials!['postgres']['id'], equals('cred-1'));
    });

    test('adds disabled node', () {
      final workflow = WorkflowBuilder.create()
          .node(
            name: 'Disabled Node',
            type: 'n8n-nodes-base.test',
            disabled: true,
          )
          .build();

      expect(workflow.nodes[0].disabled, isTrue);
    });

    test('adds node with notes', () {
      final workflow = WorkflowBuilder.create()
          .node(
            name: 'Documented Node',
            type: 'n8n-nodes-base.test',
            notes: 'This is a test node',
          )
          .build();

      expect(workflow.nodes[0].notes, equals('This is a test node'));
    });
  });

  group('WorkflowBuilder - Positioning', () {
    test('resets position with newRow', () {
      final workflow = WorkflowBuilder.create()
          .node(name: 'Node 1', type: 'test') // x=100, y=200
          .node(name: 'Node 2', type: 'test') // x=350, y=200
          .newRow()
          .node(name: 'Node 3', type: 'test') // x=100, y=300
          .build();

      expect(workflow.nodes[0].position.x, equals(100));
      expect(workflow.nodes[1].position.x, equals(350));
      expect(workflow.nodes[2].position.x, equals(100)); // Reset to 100
      expect(workflow.nodes[2].position.y, equals(300)); // Increased Y
    });

    test('sets custom position', () {
      final workflow = WorkflowBuilder.create()
          .position(500, 600)
          .node(name: 'Custom Position', type: 'test')
          .build();

      expect(workflow.nodes[0].position.x, equals(500));
      expect(workflow.nodes[0].position.y, equals(600));
    });

    test('continues from custom position', () {
      final workflow = WorkflowBuilder.create()
          .position(200, 300)
          .node(name: 'Node 1', type: 'test')
          .node(name: 'Node 2', type: 'test')
          .build();

      expect(workflow.nodes[0].position.x, equals(200));
      expect(workflow.nodes[1].position.x, equals(450)); // 200 + 250
      expect(workflow.nodes[1].position.y, equals(300)); // Same Y
    });
  });

  group('WorkflowBuilder - Connections', () {
    test('connects two nodes', () {
      final workflow = WorkflowBuilder.create()
          .node(name: 'Node A', type: 'test')
          .node(name: 'Node B', type: 'test')
          .connect('Node A', 'Node B')
          .build();

      expect(workflow.connections.keys, contains('Node A'));
      expect(
        workflow.connections['Node A']!['main']![0][0].node,
        equals('Node B'),
      );
    });

    test('connects with custom output type', () {
      final workflow = WorkflowBuilder.create()
          .node(name: 'Source', type: 'test')
          .node(name: 'Target', type: 'test')
          .connect('Source', 'Target', outputType: 'custom')
          .build();

      expect(workflow.connections['Source']!.keys, contains('custom'));
    });

    test('connects with source index', () {
      final workflow = WorkflowBuilder.create()
          .node(name: 'Multi Output', type: 'test')
          .node(name: 'Target 1', type: 'test')
          .node(name: 'Target 2', type: 'test')
          .connect('Multi Output', 'Target 1', sourceIndex: 0)
          .connect('Multi Output', 'Target 2', sourceIndex: 1)
          .build();

      expect(workflow.connections['Multi Output']!['main']!.length, equals(2));
    });

    test('connects sequence of nodes', () {
      final workflow = WorkflowBuilder.create()
          .node(name: 'Step 1', type: 'test')
          .node(name: 'Step 2', type: 'test')
          .node(name: 'Step 3', type: 'test')
          .connectSequence(['Step 1', 'Step 2', 'Step 3'])
          .build();

      expect(workflow.connections.keys.length, equals(2));
      expect(workflow.connections['Step 1']!['main']![0][0].node, equals('Step 2'));
      expect(workflow.connections['Step 2']!['main']![0][0].node, equals('Step 3'));
    });

    test('handles multiple connections from same node', () {
      final workflow = WorkflowBuilder.create()
          .node(name: 'Source', type: 'test')
          .node(name: 'Target 1', type: 'test')
          .node(name: 'Target 2', type: 'test')
          .connect('Source', 'Target 1')
          .connect('Source', 'Target 2')
          .build();

      expect(workflow.connections['Source']!['main']![0].length, equals(2));
    });
  });

  group('WorkflowBuilder - Fluent API Chaining', () {
    test('chains all builder methods', () {
      final workflow = WorkflowBuilder.create()
          .name('Chained Workflow')
          .active()
          .version(2.0)
          .tags(['test', 'chained'])
          .node(name: 'Node 1', type: 'test')
          .node(name: 'Node 2', type: 'test')
          .connect('Node 1', 'Node 2')
          .build();

      expect(workflow.name, equals('Chained Workflow'));
      expect(workflow.active, isTrue);
      expect(workflow.version, equals(2.0));
      expect(workflow.tags, containsAll(['test', 'chained']));
      expect(workflow.nodes.length, equals(2));
      expect(workflow.connections.keys.length, equals(1));
    });
  });

  group('WorkflowBuilder - Build Methods', () {
    test('build() returns N8nWorkflow instance', () {
      final workflow = WorkflowBuilder.create()
          .name('Test')
          .build();

      expect(workflow, isA<N8nWorkflow>());
      expect(workflow.name, equals('Test'));
    });

    test('buildJson() returns JSON string', () {
      final json = WorkflowBuilder.create()
          .name('JSON Test')
          .buildJson();

      expect(json, isA<String>());

      final decoded = jsonDecode(json);
      expect(decoded['name'], equals('JSON Test'));
    });

    test('buildJson() produces valid JSON', () {
      final json = WorkflowBuilder.create()
          .name('Valid JSON')
          .node(name: 'Test Node', type: 'n8n-nodes-base.test')
          .buildJson();

      expect(() => jsonDecode(json), returnsNormally);

      final decoded = jsonDecode(json);
      expect(decoded['nodes'], isList);
      expect(decoded['nodes'].length, equals(1));
    });

    test('buildAndSave() creates file', () async {
      final tempDir = Directory.systemTemp.createTempSync('workflow_test_');
      final filePath = '${tempDir.path}/workflow.json';

      await WorkflowBuilder.create()
          .name('Saved Workflow')
          .node(name: 'Test', type: 'test')
          .buildAndSave(filePath);

      expect(File(filePath).existsSync(), isTrue);

      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);
      expect(decoded['name'], equals('Saved Workflow'));

      tempDir.deleteSync(recursive: true);
    });
  });

  group('WorkflowBuilder - Complex Workflows', () {
    test('builds multi-branch workflow', () {
      final workflow = WorkflowBuilder.create()
          .name('Multi-Branch')
          .node(name: 'Start', type: 'webhook')
          .node(name: 'Branch A', type: 'process')
          .newRow()
          .node(name: 'Branch B', type: 'process')
          .newRow()
          .node(name: 'Merge', type: 'merge')
          .connect('Start', 'Branch A')
          .connect('Start', 'Branch B')
          .connect('Branch A', 'Merge')
          .connect('Branch B', 'Merge')
          .build();

      expect(workflow.nodes.length, equals(4));
      expect(workflow.connections['Start']!['main']![0].length, equals(2));
    });

    test('builds conditional workflow', () {
      final workflow = WorkflowBuilder.create()
          .name('Conditional')
          .node(name: 'Start', type: 'webhook')
          .node(name: 'Check Condition', type: 'if')
          .node(name: 'True Path', type: 'action')
          .newRow()
          .node(name: 'False Path', type: 'action')
          .newRow()
          .node(name: 'End', type: 'respond')
          .connect('Start', 'Check Condition')
          .connect('Check Condition', 'True Path', sourceIndex: 0)
          .connect('Check Condition', 'False Path', sourceIndex: 1)
          .connect('True Path', 'End')
          .connect('False Path', 'End')
          .build();

      expect(workflow.nodes.length, equals(5));
      expect(workflow.connections['Check Condition']!['main']!.length, equals(2));
    });

    test('builds sequential workflow with multiple steps', () {
      final workflow = WorkflowBuilder.create()
          .name('Sequential Pipeline')
          .node(name: 'Trigger', type: 'webhook')
          .node(name: 'Validate', type: 'function')
          .node(name: 'Process', type: 'function')
          .node(name: 'Save', type: 'database')
          .node(name: 'Notify', type: 'email')
          .node(name: 'Respond', type: 'respond')
          .connectSequence([
            'Trigger',
            'Validate',
            'Process',
            'Save',
            'Notify',
            'Respond',
          ])
          .build();

      expect(workflow.nodes.length, equals(6));
      expect(workflow.connections.keys.length, equals(5));
    });
  });

  group('WorkflowBuilder - Edge Cases', () {
    test('builds empty workflow', () {
      final workflow = WorkflowBuilder.create().build();

      expect(workflow.nodes, isEmpty);
      expect(workflow.connections, isEmpty);
    });

    test('handles single node workflow', () {
      final workflow = WorkflowBuilder.create()
          .node(name: 'Only Node', type: 'test')
          .build();

      expect(workflow.nodes.length, equals(1));
      expect(workflow.connections, isEmpty);
    });

    test('handles workflow with only connections (no nodes added via builder)', () {
      final node1 = WorkflowNode(
        name: 'External Node 1',
        type: 'test',
        position: const NodePosition(0, 0),
      );
      final node2 = WorkflowNode(
        name: 'External Node 2',
        type: 'test',
        position: const NodePosition(100, 0),
      );

      final workflow = WorkflowBuilder.create()
          .addNode(node1)
          .addNode(node2)
          .connect('External Node 1', 'External Node 2')
          .build();

      expect(workflow.nodes.length, equals(2));
      expect(workflow.connections.keys.length, equals(1));
    });

    test('allows multiple tags additions', () {
      final workflow = WorkflowBuilder.create()
          .tag('tag1')
          .tag('tag2')
          .tags(['tag3', 'tag4'])
          .build();

      expect(workflow.tags, hasLength(4));
      expect(workflow.tags, containsAll(['tag1', 'tag2', 'tag3', 'tag4']));
    });

    test('handles connectSequence with single node', () {
      final workflow = WorkflowBuilder.create()
          .node(name: 'Single', type: 'test')
          .connectSequence(['Single'])
          .build();

      expect(workflow.connections, isEmpty);
    });

    test('handles connectSequence with empty list', () {
      final workflow = WorkflowBuilder.create()
          .connectSequence([])
          .build();

      expect(workflow.connections, isEmpty);
    });
  });

  group('WorkflowBuilder - create() factory', () {
    test('creates new instance each time', () {
      final builder1 = WorkflowBuilder.create();
      final builder2 = WorkflowBuilder.create();

      expect(identical(builder1, builder2), isFalse);
    });

    test('instances are independent', () {
      final workflow1 = WorkflowBuilder.create()
          .name('Workflow 1')
          .build();

      final workflow2 = WorkflowBuilder.create()
          .name('Workflow 2')
          .build();

      expect(workflow1.name, equals('Workflow 1'));
      expect(workflow2.name, equals('Workflow 2'));
    });
  });
}
