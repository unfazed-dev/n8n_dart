import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('ReactiveWorkflowBuilder', () {
    late ReactiveWorkflowBuilder builder;

    setUp(() {
      builder = ReactiveWorkflowBuilder();
    });

    tearDown(() {
      builder.dispose();
    });

    group('Node Management', () {
      test('addNode() should add node to stream', () async {
        final node = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        builder.addNode(node);

        await expectLater(
          builder.nodeCount$,
          emits(1),
        );
      });

      test('addNode() should reject duplicate names', () async {
        final node1 = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        final node2 = WorkflowNode(
          name: 'Webhook', // Duplicate name
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(300, 200),
          parameters: {},
        );

        builder.addNode(node1);
        builder.addNode(node2);

        await expectLater(
          builder.validationErrors$,
          emits(contains('Duplicate node name: Webhook')),
        );
      });

      test('removeNode() should remove node', () async {
        final node = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        builder.addNode(node);
        builder.removeNode('Webhook');

        await expectLater(
          builder.nodeCount$,
          emits(0),
        );
      });

      test('updateNode() should update existing node', () async {
        final node = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        builder.addNode(node);

        final updatedNode = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          typeVersion: 2,
          position: const NodePosition(150, 250),
          parameters: {'path': 'updated'},
        );

        builder.updateNode('Webhook', updatedNode);

        final nodes = await builder.nodes$.first;
        expect(nodes.first.parameters['path'], equals('updated'));
      });
    });

    group('Connections', () {
      test('connect() should create connection between nodes', () async {
        final webhook = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        final postgres = WorkflowNode(
          name: 'Postgres',
          type: 'n8n-nodes-base.postgres',
          position: const NodePosition(350, 200),
          parameters: {},
        );

        builder.addNode(webhook);
        builder.addNode(postgres);

        builder.connect(fromNode: 'Webhook', toNode: 'Postgres');

        await expectLater(
          builder.connections$,
          emits(isNotEmpty),
        );
      });

      test('connect() should validate node existence', () async {
        builder.connect(fromNode: 'Nonexistent', toNode: 'AlsoNonexistent');

        await expectLater(
          builder.validationErrors$,
          emits(contains('Source node not found: Nonexistent')),
        );
      });

      test('disconnect() should remove connection', () async {
        final webhook = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        final postgres = WorkflowNode(
          name: 'Postgres',
          type: 'n8n-nodes-base.postgres',
          position: const NodePosition(350, 200),
          parameters: {},
        );

        builder.addNode(webhook);
        builder.addNode(postgres);
        builder.connect(fromNode: 'Webhook', toNode: 'Postgres');

        builder.disconnect(fromNode: 'Webhook', toNode: 'Postgres');

        await expectLater(
          builder.connections$,
          emits(isEmpty),
        );
      });
    });

    group('Validation', () {
      test('isValid\$ should be false for empty workflow', () async {
        await expectLater(
          builder.isValid$,
          emits(false),
        );
      });

      test('isValid\$ should require at least one trigger node', () async {
        final nonTrigger = WorkflowNode(
          name: 'Postgres',
          type: 'n8n-nodes-base.postgres',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        builder.addNode(nonTrigger);

        await expectLater(
          builder.validationErrors$,
          emits(contains('Workflow must have at least one trigger or webhook node')),
        );
      });

      test('should validate disconnected nodes', () async {
        final webhook = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        final postgres = WorkflowNode(
          name: 'Postgres',
          type: 'n8n-nodes-base.postgres',
          position: const NodePosition(350, 200),
          parameters: {},
        );

        builder.addNode(webhook);
        builder.addNode(postgres);

        // No connections - postgres should be flagged

        await expectLater(
          builder.validationErrors$,
          emits(predicate<List<String>>((errors) =>
              errors.any((e) => e.contains('no incoming connections') ||
                  e.contains('no outgoing connections')))),
        );
      });
    });

    group('Workflow Building', () {
      test('workflow\$ should emit built workflow', () async {
        final webhook = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        final respond = WorkflowNode(
          name: 'Respond',
          type: 'n8n-nodes-base.respondToWebhook',
          position: const NodePosition(350, 200),
          parameters: {},
        );

        builder.addNode(webhook);
        builder.addNode(respond);
        builder.connect(fromNode: 'Webhook', toNode: 'Respond');

        // Wait for debounce
        await Future.delayed(const Duration(milliseconds: 400));

        await expectLater(
          builder.workflow$,
          emits(predicate<N8nWorkflow>((wf) => wf.nodes.length == 2)),
        );
      }, timeout: const Timeout(Duration(seconds: 3)));

      test('workflow\$ should debounce rapid changes', () async {
        var emissionCount = 0;

        builder.workflow$.listen((_) => emissionCount++);

        final webhook = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        // Rapid additions
        builder.addNode(webhook);
        builder.setName('Test');
        builder.addTag('test');

        // Wait for debounce period
        await Future.delayed(const Duration(milliseconds: 500));

        // Should only emit once after debounce
        expect(emissionCount, lessThanOrEqualTo(2)); // May include initial emission
      }, timeout: const Timeout(Duration(seconds: 3)));
    });

    group('Metadata', () {
      test('setName() should update workflow name', () {
        builder.setName('My Workflow');

        expectLater(
          builder.metadata$,
          emits(predicate<WorkflowMetadata>((m) => m.name == 'My Workflow')),
        );
      });

      test('addTag() should add tag', () {
        builder.addTag('production');

        expectLater(
          builder.metadata$,
          emits(predicate<WorkflowMetadata>((m) => m.tags.contains('production'))),
        );
      });

      test('removeTag() should remove tag', () {
        builder.addTag('test');
        builder.removeTag('test');

        expectLater(
          builder.metadata$,
          emits(predicate<WorkflowMetadata>((m) => !m.tags.contains('test'))),
        );
      });
    });

    group('Clear', () {
      test('clear() should reset workflow', () async {
        final webhook = WorkflowNode(
          name: 'Webhook',
          type: 'n8n-nodes-base.webhook',
          position: const NodePosition(100, 200),
          parameters: {},
        );

        builder.addNode(webhook);
        builder.clear();

        await expectLater(
          builder.nodeCount$,
          emits(0),
        );
      });
    });
  });
}
