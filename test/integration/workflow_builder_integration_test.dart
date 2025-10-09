/// Workflow Builder Integration Tests
///
/// Tests WorkflowBuilder fluent API for programmatic workflow creation
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import 'utils/template_helpers.dart';

void main() {
  group('Workflow Builder Integration Tests', () {
    group('Basic Workflow Creation', () {
      test('creates simple workflow with webhook and response', () {
        final workflow = WorkflowBuilder.create()
            .name('Test Workflow')
            .webhookTrigger(name: 'Webhook', path: 'test')
            .respondToWebhook(name: 'Respond')
            .connectSequence(['Webhook', 'Respond'])
            .build();

        expect(workflow.name, equals('Test Workflow'));
        expect(workflow.nodes.length, equals(2));
        expect(workflow.connections.isNotEmpty, isTrue);
      });

      test('creates workflow with function node', () {
        final workflow = WorkflowBuilder.create()
            .name('Function Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .function(
              name: 'Transform',
              code: 'return [{json: {result: "success"}}];',
            )
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Transform', 'Response'])
            .build();

        expect(workflow.nodes.length, equals(3));
        expect(hasNodeType(workflow, 'n8n-nodes-base.function'), isTrue);
      });

      test('creates workflow with database node', () {
        final workflow = WorkflowBuilder.create()
            .name('Database Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .postgres(
              name: 'Query',
              operation: 'select',
              table: 'users',
            )
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Query', 'Response'])
            .build();

        expect(workflow.nodes.length, equals(3));
        expect(hasDatabaseNode(workflow), isTrue);
      });

      test('creates workflow with HTTP request node', () {
        final workflow = WorkflowBuilder.create()
            .name('HTTP Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .httpRequest(
              name: 'Fetch Data',
              url: 'https://api.example.com/data',
            )
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Fetch Data', 'Response'])
            .build();

        expect(workflow.nodes.length, equals(3));
        expect(hasNodeType(workflow, 'n8n-nodes-base.httpRequest'), isTrue);
      });

      test('creates workflow with IF conditional node', () {
        final workflow = WorkflowBuilder.create()
            .name('Conditional Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .ifNode(
              name: 'Check',
              conditions: [
                {
                  'leftValue': '={{"\$json.status"}}',
                  'operation': 'equals',
                  'rightValue': 'active',
                }
              ],
            )
            .respondToWebhook(name: 'Response')
            .connect('Trigger', 'Check')
            .connect('Check', 'Response')
            .build();

        expect(workflow.nodes.length, equals(3));
        expect(hasNodeType(workflow, 'n8n-nodes-base.if'), isTrue);
      });
    });

    group('Advanced Workflow Patterns', () {
      test('creates workflow with branching logic', () {
        final workflow = WorkflowBuilder.create()
            .name('Branching Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .function(name: 'Process', code: 'return items;')
            .newRow()
            .function(name: 'Branch A', code: 'return items;')
            .newRow()
            .function(name: 'Branch B', code: 'return items;')
            .newRow()
            .respondToWebhook(name: 'Response')
            .connect('Trigger', 'Process')
            .connect('Process', 'Branch A')
            .connect('Process', 'Branch B')
            .connect('Branch A', 'Response')
            .connect('Branch B', 'Response')
            .build();

        expect(workflow.nodes.length, equals(5));

        // Verify Process node connects to both branches
        final processConnections = workflow.connections['Process'];
        expect(processConnections, isNotNull);
      });

      test('creates workflow with multiple rows (complex layout)', () {
        final workflow = WorkflowBuilder.create()
            .name('Multi-Row Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .function(name: 'Node 1', code: 'return items;')
            .newRow()
            .function(name: 'Node 2', code: 'return items;')
            .newRow()
            .function(name: 'Node 3', code: 'return items;')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Node 1', 'Node 2', 'Node 3', 'Response'])
            .build();

        expect(workflow.nodes.length, equals(5));

        // Verify nodes have different Y positions (rows)
        final yPositions = workflow.nodes.map((n) => n.position.y).toSet();
        expect(yPositions.length, greaterThan(1), reason: 'Should have nodes in different rows');
      });

      test('creates workflow with custom positioning', () {
        final workflow = WorkflowBuilder.create()
            .name('Custom Position Test')
            .position(200, 300)
            .webhookTrigger(name: 'Custom', path: 'test')
            .position(500, 300)
            .respondToWebhook(name: 'Response')
            .connect('Custom', 'Response')
            .build();

        final webhookNode = workflow.nodes.firstWhere((n) => n.name == 'Custom');
        expect(webhookNode.position.x, equals(200));
        expect(webhookNode.position.y, equals(300));
      });

      test('creates workflow with tags', () {
        final workflow = WorkflowBuilder.create()
            .name('Tagged Test')
            .tag('api')
            .tag('database')
            .tags(['test', 'integration'])
            .webhookTrigger(name: 'Trigger', path: 'test')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Response'])
            .build();

        expect(workflow.tags, isNotNull);
        expect(workflow.tags!.length, equals(4));
        expect(workflow.tags, contains('api'));
        expect(workflow.tags, contains('database'));
        expect(workflow.tags, contains('test'));
        expect(workflow.tags, contains('integration'));
      });

      test('creates workflow with settings', () {
        const settings = WorkflowSettings(
          executionMode: 'parallel',
          timezone: 'America/New_York',
          executionTimeout: 120,
        );

        final workflow = WorkflowBuilder.create()
            .name('Settings Test')
            .settings(settings)
            .webhookTrigger(name: 'Trigger', path: 'test')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Response'])
            .build();

        expect(workflow.settings.executionMode, equals('parallel'));
        expect(workflow.settings.timezone, equals('America/New_York'));
        expect(workflow.settings.executionTimeout, equals(120));
      });
    });

    group('JSON Export/Import', () {
      test('exports workflow to valid JSON', () {
        final workflow = WorkflowBuilder.create()
            .name('Export Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .function(name: 'Process', code: 'return items;')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Process', 'Response'])
            .build();

        final json = workflow.toJson();
        expect(() => jsonDecode(json), returnsNormally);

        final map = jsonDecode(json) as Map<String, dynamic>;
        validateWorkflowJson(map);
      });

      test('imports workflow from JSON string', () {
        final original = WorkflowBuilder.create()
            .name('Import Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Response'])
            .build();

        final json = original.toJson();
        final imported = N8nWorkflow.fromJson(json);

        expect(imported.name, equals(original.name));
        expect(imported.nodes.length, equals(original.nodes.length));
        expect(imported.connections.length, equals(original.connections.length));
      });

      test('roundtrip export/import preserves workflow', () async {
        final original = WorkflowBuilder.create()
            .name('Roundtrip Test')
            .tags(['test', 'roundtrip'])
            .webhookTrigger(name: 'Trigger', path: 'test')
            .function(name: 'Process', code: 'return items;')
            .postgres(name: 'Save', operation: 'insert', table: 'data')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Process', 'Save', 'Response'])
            .build();

        await validateRoundtrip(original);
      });

      test('saves workflow to file', () async {
        final workflow = WorkflowBuilder.create()
            .name('File Save Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Response'])
            .build();

        const filePath = 'test/generated_workflows/builder_test.json';
        await workflow.saveToFile(filePath);

        expect(File(filePath).existsSync(), isTrue);

        // Clean up
        await File(filePath).delete();
      });

      test('loads workflow from file', () async {
        final original = WorkflowBuilder.create()
            .name('File Load Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .function(name: 'Process', code: 'return items;')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Process', 'Response'])
            .build();

        const filePath = 'test/generated_workflows/builder_load_test.json';
        await original.saveToFile(filePath);

        final loaded = await loadWorkflowFromFile('builder_load_test.json');

        expect(loaded.name, equals(original.name));
        expect(loaded.nodes.length, equals(original.nodes.length));

        // Clean up
        await File(filePath).delete();
      });
    });

    group('Connection Methods', () {
      test('connect() links two nodes correctly', () {
        final workflow = WorkflowBuilder.create()
            .name('Connect Test')
            .webhookTrigger(name: 'A', path: 'test')
            .respondToWebhook(name: 'B')
            .connect('A', 'B')
            .build();

        expect(workflow.connections['A'], isNotNull);
        expect(workflow.connections['A']!['main'], isNotNull);
        expect(workflow.connections['A']!['main']![0].first.node, equals('B'));
      });

      test('connectSequence() links multiple nodes in order', () {
        final workflow = WorkflowBuilder.create()
            .name('Sequence Test')
            .webhookTrigger(name: 'Node1', path: 'test')
            .function(name: 'Node2', code: 'return items;')
            .function(name: 'Node3', code: 'return items;')
            .respondToWebhook(name: 'Node4')
            .connectSequence(['Node1', 'Node2', 'Node3', 'Node4'])
            .build();

        // Verify sequential connections
        TemplateAssertions.assertHasConnection(workflow, 'Node1', 'Node2');
        TemplateAssertions.assertHasConnection(workflow, 'Node2', 'Node3');
        TemplateAssertions.assertHasConnection(workflow, 'Node3', 'Node4');
      });

      test('connect() supports multiple outputs from same node', () {
        final workflow = WorkflowBuilder.create()
            .name('Multi-Output Test')
            .webhookTrigger(name: 'Source', path: 'test')
            .function(name: 'Target1', code: 'return items;')
            .function(name: 'Target2', code: 'return items;')
            .respondToWebhook(name: 'Response')
            .connect('Source', 'Target1')
            .connect('Source', 'Target2')
            .connect('Target1', 'Response')
            .connect('Target2', 'Response')
            .build();

        final sourceConnections = workflow.connections['Source'];
        expect(sourceConnections, isNotNull);

        // Count connections from Source
        var connectionCount = 0;
        for (final outputs in sourceConnections!.values) {
          for (final conns in outputs) {
            connectionCount += conns.length;
          }
        }

        expect(connectionCount, equals(2), reason: 'Source should connect to 2 targets');
      });

      test('connect() supports different output indices (IF node)', () {
        final workflow = WorkflowBuilder.create()
            .name('Output Index Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .ifNode(name: 'Condition', conditions: [])
            .function(name: 'True Path', code: 'return items;')
            .function(name: 'False Path', code: 'return items;')
            .respondToWebhook(name: 'Response')
            .connect('Trigger', 'Condition')
            .connect('Condition', 'True Path')
            .connect('Condition', 'False Path', sourceIndex: 1)
            .connect('True Path', 'Response')
            .connect('False Path', 'Response')
            .build();

        final conditionConnections = workflow.connections['Condition'];
        expect(conditionConnections, isNotNull);
        expect(conditionConnections!['main']!.length, greaterThanOrEqualTo(2));
      });
    });

    group('Node Type Extensions', () {
      test('creates workflow with email node', () {
        final workflow = WorkflowBuilder.create()
            .name('Email Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .emailSend(
              name: 'Send Email',
              fromEmail: 'from@example.com',
              toEmail: 'to@example.com',
              subject: 'Test',
              message: 'Test message',
            )
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Send Email', 'Response'])
            .build();

        expect(hasNodeType(workflow, 'n8n-nodes-base.emailSend'), isTrue);

        final emailNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.emailSend',
        );
        expect(emailNode.parameters['fromEmail'], equals('from@example.com'));
        expect(emailNode.parameters['subject'], equals('Test'));
      });

      test('creates workflow with Slack node', () {
        final workflow = WorkflowBuilder.create()
            .name('Slack Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .slack(
              name: 'Notify',
              channel: '#general',
              text: 'Hello World',
            )
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Notify', 'Response'])
            .build();

        expect(hasNodeType(workflow, 'n8n-nodes-base.slack'), isTrue);

        final slackNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.slack',
        );
        expect(slackNode.parameters['channel'], equals('#general'));
        expect(slackNode.parameters['text'], equals('Hello World'));
      });

      test('creates workflow with wait node', () {
        final workflow = WorkflowBuilder.create()
            .name('Wait Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .waitNode(name: 'Wait for Input')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Wait for Input', 'Response'])
            .build();

        expect(hasWaitNode(workflow), isTrue);

        final waitNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.wait',
        );
        expect(waitNode.parameters['resume'], equals('webhook'));
      });

      test('creates workflow with Set node', () {
        final workflow = WorkflowBuilder.create()
            .name('Set Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .setNode(
              name: 'Transform',
              values: {'key': 'value'},
            )
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Transform', 'Response'])
            .build();

        expect(hasNodeType(workflow, 'n8n-nodes-base.set'), isTrue);
      });
    });

    group('Workflow Validation', () {
      test('validates workflow structure', () {
        final workflow = WorkflowBuilder.create()
            .name('Validation Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .function(name: 'Process', code: 'return items;')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Process', 'Response'])
            .build();

        validateWorkflowStructure(workflow);
      });

      test('validates all nodes have positions', () {
        final workflow = WorkflowBuilder.create()
            .name('Position Test')
            .webhookTrigger(name: 'Node1', path: 'test')
            .function(name: 'Node2', code: 'return items;')
            .function(name: 'Node3', code: 'return items;')
            .respondToWebhook(name: 'Node4')
            .connectSequence(['Node1', 'Node2', 'Node3', 'Node4'])
            .build();

        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });

      test('validates workflow has minimum nodes', () {
        final workflow = WorkflowBuilder.create()
            .name('Minimum Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Response'])
            .build();

        final helper = createTemplateHelper(workflow);
        helper.expectMinimumNodes(2);
      });

      test('validates workflow has connections', () {
        final workflow = WorkflowBuilder.create()
            .name('Connection Test')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Response'])
            .build();

        final helper = createTemplateHelper(workflow);
        helper.expectHasConnections();
      });
    });

    group('Complex Real-World Workflows', () {
      test('creates API endpoint with error handling', () {
        final workflow = WorkflowBuilder.create()
            .name('API with Error Handling')
            .tags(['api', 'production'])
            .webhookTrigger(name: 'API Trigger', path: 'api/data')
            .function(
              name: 'Validate Request',
              code: '''
if (!'\$json.body.id') {
  throw new Error('ID is required');
}
return items;
''',
            )
            .postgres(name: 'Fetch Data', operation: 'select', table: 'records')
            .function(
              name: 'Format Response',
              code: 'return [{json: {success: true, data: \$json}}];',
            )
            .respondToWebhook(name: 'Send Response')
            .connectSequence([
              'API Trigger',
              'Validate Request',
              'Fetch Data',
              'Format Response',
              'Send Response',
            ])
            .build();

        expect(workflow.nodes.length, equals(5));
        expect(workflow.tags, contains('api'));
        validateWorkflowStructure(workflow);
      });

      test('creates data processing pipeline', () {
        final workflow = WorkflowBuilder.create()
            .name('Data Pipeline')
            .tags(['etl', 'processing'])
            .webhookTrigger(name: 'Start', path: 'pipeline/start')
            .httpRequest(
              name: 'Fetch Source',
              url: 'https://api.source.com/data',
            )
            .function(
              name: 'Transform',
              code: 'return items.map(i => ({json: {...i.json, processed: true}}));',
            )
            .function(
              name: 'Filter',
              code: 'return items.filter(i => i.json.active);',
            )
            .postgres(name: 'Load to DB', operation: 'insert', table: 'processed_data')
            .slack(
              name: 'Notify Complete',
              channel: '#data-pipeline',
              text: 'Pipeline completed',
            )
            .respondToWebhook(name: 'Complete')
            .connectSequence([
              'Start',
              'Fetch Source',
              'Transform',
              'Filter',
              'Load to DB',
              'Notify Complete',
              'Complete',
            ])
            .build();

        expect(workflow.nodes.length, equals(7));
        expect(hasNodeType(workflow, 'n8n-nodes-base.httpRequest'), isTrue);
        expect(hasDatabaseNode(workflow), isTrue);
        expect(hasNodeType(workflow, 'n8n-nodes-base.slack'), isTrue);
        validateWorkflowStructure(workflow);
      });
    });
  });
}
