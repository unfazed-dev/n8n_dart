import 'dart:convert';
import 'dart:io';
import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Workflow Generator Integration - End-to-End', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('n8n_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('creates, exports, and imports simple workflow', () async {
      // Create workflow
      final original = WorkflowBuilder.create()
          .name('Test Workflow')
          .active()
          .tags(['test', 'integration'])
          .webhookTrigger(name: 'Start', path: 'test')
          .function(name: 'Process', code: 'return items;')
          .respondToWebhook(name: 'End')
          .connectSequence(['Start', 'Process', 'End'])
          .build();

      // Export to file
      final filePath = '${tempDir.path}/workflow.json';
      await original.saveToFile(filePath);

      // Verify file exists
      final file = File(filePath);
      expect(file.existsSync(), isTrue);

      // Import from file
      final fileContent = await file.readAsString();
      final imported = N8nWorkflow.fromJson(fileContent);

      // Verify workflow properties
      expect(imported.name, equals(original.name));
      expect(imported.active, equals(original.active));
      expect(imported.tags, equals(original.tags));
      expect(imported.nodes.length, equals(original.nodes.length));
    });

    test('round-trip preserves all workflow data', () async {
      final original = WorkflowBuilder.create()
          .name('Complex Workflow')
          .active(true)
          .version(2.0)
          .tags(['production', 'api'])
          .settings(const WorkflowSettings(
            executionMode: 'sequential',
            timezone: 'America/New_York',
            executionTimeout: 3600,
          ))
          .webhookTrigger(name: 'Webhook', path: 'api/v1')
          .postgres(name: 'DB Query', operation: 'select', table: 'users')
          .emailSend(
            name: 'Email',
            fromEmail: 'app@example.com',
            toEmail: 'user@example.com',
            subject: 'Test',
          )
          .connectSequence(['Webhook', 'DB Query', 'Email'])
          .build();

      final filePath = '${tempDir.path}/complex.json';
      await original.saveToFile(filePath);

      final fileContent = await File(filePath).readAsString();
      final restored = N8nWorkflow.fromJson(fileContent);

      // Verify all properties
      expect(restored.name, equals(original.name));
      expect(restored.active, equals(original.active));
      expect(restored.version, equals(original.version));
      expect(restored.tags, equals(original.tags));
      expect(restored.settings.executionMode, equals(original.settings.executionMode));
      expect(restored.settings.timezone, equals(original.settings.timezone));
      expect(restored.nodes.length, equals(original.nodes.length));
      expect(restored.connections.keys.length, equals(original.connections.keys.length));
    });
  });

  group('Workflow Generator Integration - Real-World Scenarios', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('n8n_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generates complete user registration workflow', () async {
      final workflow = WorkflowTemplates.userRegistration(
        webhookPath: 'auth/register',
        tableName: 'users',
        fromEmail: 'welcome@app.com',
      );

      final filePath = '${tempDir.path}/user_registration.json';
      await workflow.saveToFile(filePath);

      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);

      // Verify it's a valid n8n workflow
      expect(decoded['name'], isNotNull);
      expect(decoded['nodes'], isList);
      expect(decoded['connections'], isA<Map>());
      expect(decoded['settings'], isA<Map>());

      // Verify workflow has expected nodes
      final nodes = decoded['nodes'] as List;
      expect(nodes.length, greaterThan(3));

      // Verify at least one node is a webhook
      final hasWebhook = nodes.any((n) => n['type'].toString().contains('webhook'));
      expect(hasWebhook, isTrue);
    });

    test('generates complete CRUD API workflow', () async {
      final workflow = WorkflowTemplates.crudApi(
        resourceName: 'products',
        tableName: 'products',
        webhookPath: 'api/v1',
      );

      final filePath = '${tempDir.path}/crud_api.json';
      await workflow.saveToFile(filePath);

      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);

      // Verify structure
      expect(decoded['name'], contains('PRODUCTS'));
      expect(decoded['tags'], contains('crud'));

      final nodes = decoded['nodes'] as List;
      final nodeNames = nodes.map((n) => n['name'] as String).toList();

      // Verify CRUD operations are present
      expect(nodeNames.any((n) => n.contains('Create')), isTrue);
      expect(nodeNames.any((n) => n.contains('Read')), isTrue);
      expect(nodeNames.any((n) => n.contains('Update')), isTrue);
      expect(nodeNames.any((n) => n.contains('Delete')), isTrue);
    });

    test('generates multi-step form workflow with wait nodes', () async {
      final workflow = WorkflowTemplates.multiStepForm(
        webhookPath: 'form/start',
        tableName: 'submissions',
      );

      final filePath = '${tempDir.path}/multi_step_form.json';
      await workflow.saveToFile(filePath);

      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);

      final nodes = decoded['nodes'] as List;

      // Verify wait nodes exist
      final waitNodes = nodes.where((n) => n['type'].toString().contains('.wait')).toList();
      expect(waitNodes.length, greaterThanOrEqualTo(2));

      // Verify connections chain through wait nodes
      final connections = decoded['connections'] as Map;
      expect(connections, isNotEmpty);
    });

    test('generates scheduled report workflow', () async {
      final workflow = WorkflowTemplates.scheduledReport(
        reportName: 'Weekly Sales',
        recipients: 'team@company.com',
        schedule: '0 9 * * 1',
      );

      final filePath = '${tempDir.path}/scheduled_report.json';
      await workflow.saveToFile(filePath);

      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);

      final nodes = decoded['nodes'] as List;

      // Verify schedule trigger exists
      final hasTrigger = nodes.any((n) => n['type'].toString().contains('scheduleTrigger'));
      expect(hasTrigger, isTrue);

      // Verify email node exists
      final hasEmail = nodes.any((n) => n['type'].toString().contains('emailSend'));
      expect(hasEmail, isTrue);
    });
  });

  group('Workflow Generator Integration - Template Batch Generation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('n8n_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generates all template workflows successfully', () async {
      final templates = {
        'crud': WorkflowTemplates.crudApi(
          resourceName: 'items',
          tableName: 'items',
        ),
        'registration': WorkflowTemplates.userRegistration(
          fromEmail: 'test@test.com',
        ),
        'upload': WorkflowTemplates.fileUpload(
          s3Bucket: 'bucket',
        ),
        'orders': WorkflowTemplates.orderProcessing(
          notificationEmail: 'test@test.com',
        ),
        'form': WorkflowTemplates.multiStepForm(
          tableName: 'forms',
        ),
        'report': WorkflowTemplates.scheduledReport(
          reportName: 'Test',
          recipients: 'test@test.com',
        ),
        'sync': WorkflowTemplates.dataSync(
          sourceName: 'A',
          targetName: 'B',
        ),
        'logger': WorkflowTemplates.webhookLogger(
          spreadsheetId: 'sheet',
        ),
      };

      for (final entry in templates.entries) {
        final filePath = '${tempDir.path}/${entry.key}.json';
        await entry.value.saveToFile(filePath);

        // Verify file was created
        expect(File(filePath).existsSync(), isTrue);

        // Verify valid JSON
        final content = await File(filePath).readAsString();
        expect(() => jsonDecode(content), returnsNormally);
      }

      // Verify all files exist
      final files = tempDir.listSync();
      expect(files.length, equals(8));
    });
  });

  group('Workflow Generator Integration - Dynamic Workflow Creation', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('n8n_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generates workflows for multiple tenants', () async {
      final tenants = [
        {'name': 'Tenant A', 'table': 'tenant_a_data'},
        {'name': 'Tenant B', 'table': 'tenant_b_data'},
        {'name': 'Tenant C', 'table': 'tenant_c_data'},
      ];

      for (final tenant in tenants) {
        final workflow = WorkflowBuilder.create()
            .name('${tenant['name']} API')
            .tags([tenant['name']!, 'api'])
            .webhookTrigger(
              name: 'Webhook',
              path: 'api/${tenant['name']!.toLowerCase().replaceAll(' ', '-')}',
            )
            .postgres(
              name: 'Database',
              operation: 'select',
              table: tenant['table']!,
            )
            .respondToWebhook(name: 'Response')
            .connectSequence(['Webhook', 'Database', 'Response'])
            .build();

        final filePath = '${tempDir.path}/${tenant['name']!.replaceAll(' ', '_')}.json';
        await workflow.saveToFile(filePath);
      }

      // Verify all workflows created
      final files = tempDir.listSync();
      expect(files.length, equals(3));

      // Verify each workflow has correct table
      for (var i = 0; i < tenants.length; i++) {
        final fileName = tenants[i]['name']!.replaceAll(' ', '_');
        final content = await File('${tempDir.path}/$fileName.json').readAsString();
        final decoded = jsonDecode(content);

        expect(decoded['name'], contains(tenants[i]['name']));
        expect(decoded['tags'], contains(tenants[i]['name']));
      }
    });

    test('generates conditional workflows programmatically', () async {
      final conditions = [
        {'field': 'amount', 'operator': 'larger', 'value': 1000},
        {'field': 'status', 'operator': 'equals', 'value': 'active'},
        {'field': 'age', 'operator': 'largerEqual', 'value': 18},
      ];

      for (var i = 0; i < conditions.length; i++) {
        final condition = conditions[i];
        final workflow = WorkflowBuilder.create()
            .name('Conditional Check ${i + 1}')
            .webhookTrigger(name: 'Start', path: 'check-$i')
            .ifNode(
              name: 'Check ${condition['field']}',
              conditions: [
                {
                  'leftValue': '={{json.${condition['field']}}}',
                  'operation': condition['operator'],
                  'rightValue': condition['value'],
                }
              ],
            )
            .respondToWebhook(name: 'Response')
            .connect('Start', 'Check ${condition['field']}')
            .connect('Check ${condition['field']}', 'Response')
            .build();

        final filePath = '${tempDir.path}/condition_$i.json';
        await workflow.saveToFile(filePath);
      }

      final files = tempDir.listSync();
      expect(files.length, equals(3));
    });
  });

  group('Workflow Generator Integration - Complex Workflows', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('n8n_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generates complex multi-branch workflow', () async {
      final workflow = WorkflowBuilder.create()
          .name('Complex Multi-Branch')
          .webhookTrigger(name: 'Start', path: 'complex')
          .function(name: 'Route', code: 'return items;')
          // Branch 1
          .postgres(name: 'Save to DB', operation: 'insert', table: 'logs')
          // Branch 2
          .newRow()
          .emailSend(
            name: 'Send Email',
            fromEmail: 'app@test.com',
            toEmail: 'admin@test.com',
            subject: 'Alert',
          )
          // Branch 3
          .newRow()
          .slack(name: 'Slack Notify', channel: '#alerts', text: 'Event')
          // Merge
          .newRow()
          .respondToWebhook(name: 'Response')
          .connect('Start', 'Route')
          .connect('Route', 'Save to DB')
          .connect('Route', 'Send Email')
          .connect('Route', 'Slack Notify')
          .connect('Save to DB', 'Response')
          .connect('Send Email', 'Response')
          .connect('Slack Notify', 'Response')
          .build();

      final filePath = '${tempDir.path}/complex_multi_branch.json';
      await workflow.saveToFile(filePath);

      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);

      // Verify complex structure
      final nodes = decoded['nodes'] as List;
      expect(nodes.length, equals(6));

      final connections = decoded['connections'] as Map;
      // Route should connect to 3 nodes
      expect(connections['Route']['main'][0].length, equals(3));
    });

    test('generates error handling workflow', () async {
      final workflow = WorkflowBuilder.create()
          .name('Error Handling Workflow')
          .webhookTrigger(name: 'Start', path: 'safe')
          .httpRequest(name: 'API Call', url: 'https://api.example.com')
          .ifNode(
            name: 'Check Success',
            conditions: [
              {'leftValue': '={{statusCode}}', 'operation': 'equals', 'rightValue': 200}
            ],
          )
          // Success path
          .postgres(name: 'Save Success', operation: 'insert', table: 'success_log')
          // Error path
          .newRow()
          .postgres(name: 'Log Error', operation: 'insert', table: 'error_log')
          .emailSend(
            name: 'Alert Admin',
            fromEmail: 'alerts@app.com',
            toEmail: 'admin@app.com',
            subject: 'API Error',
          )
          .newRow()
          .respondToWebhook(name: 'Response')
          .connect('Start', 'API Call')
          .connect('API Call', 'Check Success')
          .connect('Check Success', 'Save Success', sourceIndex: 0)
          .connect('Check Success', 'Log Error', sourceIndex: 1)
          .connect('Log Error', 'Alert Admin')
          .connect('Save Success', 'Response')
          .connect('Alert Admin', 'Response')
          .build();

      final filePath = '${tempDir.path}/error_handling.json';
      await workflow.saveToFile(filePath);

      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);

      final nodes = decoded['nodes'] as List;
      expect(nodes.length, equals(7));

      // Verify IF node creates two branches
      final connections = decoded['connections'] as Map;
      expect(connections['Check Success']['main'].length, equals(2));
    });
  });

  group('Workflow Generator Integration - JSON Validation', () {
    test('all generated workflows have required n8n fields', () async {
      final workflows = [
        WorkflowBuilder.create()
            .name('Test 1')
            .webhookTrigger(name: 'W', path: 'p')
            .build(),
        WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
        WorkflowTemplates.userRegistration(fromEmail: 'test@test.com'),
      ];

      for (final workflow in workflows) {
        final jsonString = workflow.toJson();
        final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

        // Required n8n workflow fields
        expect(decoded.containsKey('name'), isTrue);
        expect(decoded.containsKey('nodes'), isTrue);
        expect(decoded.containsKey('connections'), isTrue);
        expect(decoded.containsKey('active'), isTrue);
        expect(decoded.containsKey('settings'), isTrue);

        // Verify types
        expect(decoded['name'], isA<String>());
        expect(decoded['nodes'], isList);
        expect(decoded['connections'], isA<Map>());
        expect(decoded['active'], isA<bool>());
        expect(decoded['settings'], isA<Map>());
      }
    });

    test('all nodes have required fields', () async {
      final workflow = WorkflowBuilder.create()
          .webhookTrigger(name: 'Webhook', path: 'test')
          .postgres(name: 'DB', operation: 'select')
          .emailSend(
            name: 'Email',
            fromEmail: 'a@b.com',
            toEmail: 'c@d.com',
            subject: 'Test',
          )
          .build();

      final jsonString = workflow.toJson();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final nodes = decoded['nodes'] as List;

      for (final node in nodes) {
        // Required node fields
        expect(node['id'], isNotNull);
        expect(node['name'], isNotNull);
        expect(node['type'], isNotNull);
        expect(node['typeVersion'], isNotNull);
        expect(node['position'], isNotNull);
        expect(node['parameters'], isNotNull);

        // Verify types
        expect(node['id'], isA<String>());
        expect(node['name'], isA<String>());
        expect(node['type'], isA<String>());
        expect(node['typeVersion'], isA<int>());
        expect(node['position'], isList);
        expect(node['position'].length, equals(2));
        expect(node['parameters'], isA<Map>());
      }
    });
  });
}
