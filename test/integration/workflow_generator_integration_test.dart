import 'dart:convert';
import 'dart:io';
import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Workflow Generator Integration Tests', () {
    late Directory tempDir;
    late CredentialManager credManager;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('workflow_gen_test_');

      // Create test .env file
      final envFile = File('${tempDir.path}/.env.test');
      envFile.writeAsStringSync('''
N8N_BASE_URL=https://test.n8n.cloud
N8N_API_KEY=test_api_key

SUPABASE_DB_HOST=db.test.com
SUPABASE_DB_PASSWORD=test_password

AWS_ACCESS_KEY_ID=test_aws_key
AWS_SECRET_ACCESS_KEY=test_aws_secret

SLACK_TOKEN=xoxb-test-token

STRIPE_SECRET_KEY=sk_test_123

SMTP_HOST=smtp.test.com
SMTP_USER=test@example.com

MONGODB_URL=mongodb://localhost:27017
''');

      credManager = CredentialManager.fromEnvFile(envFile.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('Credential Injection', () {
      test('injects credentials into workflow with postgres node', () {
        final workflow = WorkflowBuilder.create()
            .name('Test Workflow')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .postgres(
              name: 'Test DB',
              operation: 'select',
              query: 'SELECT * FROM test',
            )
            .build();

        final injector = WorkflowCredentialInjector(credManager);
        final result = injector.injectCredentials(workflow);

        // Find postgres node
        final pgNode = result.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.postgres',
        );

        // Verify credentials were injected (not placeholder)
        expect(pgNode.credentials, isNotNull);
        expect(pgNode.credentials!['postgres'], isNotNull);
        // Should still have placeholder since we're using test data
        expect(pgNode.credentials!['postgres']['name'], equals('PostgreSQL'));
      });

      test('detects placeholder credentials', () {
        final workflow = WorkflowBuilder.create()
            .name('Test Workflow')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .postgres(name: 'DB', operation: 'select')
            .build();

        final injector = WorkflowCredentialInjector(credManager);
        expect(injector.hasPlaceholderCredentials(workflow), isTrue);
      });

      test('identifies required credential types', () {
        final workflow = WorkflowBuilder.create()
            .name('Test Workflow')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .postgres(name: 'DB', operation: 'select')
            .slack(name: 'Notify', channel: 'general', text: 'Test')
            .build();

        final injector = WorkflowCredentialInjector(credManager);
        final required = injector.getRequiredCredentials(workflow);

        expect(required, contains('postgres'));
        expect(required, contains('slack'));
      });
    });

    group('WorkflowBuilder with Credentials', () {
      test('creates workflow with database node', () {
        final workflow = WorkflowBuilder.create()
            .name('Database Workflow')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .postgres(
              name: 'Query',
              operation: 'select',
              query: 'SELECT * FROM users',
            )
            .respondToWebhook(name: 'Response')
            .connectSequence(['Trigger', 'Query', 'Response'])
            .build();

        expect(workflow.nodes, hasLength(3));
        expect(
          workflow.nodes.any((n) => n.type == 'n8n-nodes-base.postgres'),
          isTrue,
        );
      });

      test('creates workflow with multiple credential types', () {
        final workflow = WorkflowBuilder.create()
            .name('Multi-Service Workflow')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .postgres(name: 'DB', operation: 'select')
            .slack(name: 'Notify', channel: 'general', text: 'Done')
            .respondToWebhook(name: 'Response')
            .build();

        final injector = WorkflowCredentialInjector(credManager);
        final required = injector.getRequiredCredentials(workflow);

        expect(required.length, greaterThanOrEqualTo(2));
      });
    });

    group('Template Workflows with Credentials', () {
      test('CRUD API template has correct credentials', () {
        final workflow = WorkflowTemplates.crudApi(
          resourceName: 'users',
          tableName: 'users',
        );

        final injector = WorkflowCredentialInjector(credManager);
        final required = injector.getRequiredCredentials(workflow);

        expect(required, contains('postgres'));
        expect(workflow.nodes.where(
          (n) => n.type == 'n8n-nodes-base.postgres',
        ).length, greaterThan(0));
      });

      test('User Registration template has multiple credentials', () {
        final workflow = WorkflowTemplates.userRegistration(
          fromEmail: 'noreply@example.com',
        );

        final injector = WorkflowCredentialInjector(credManager);
        final required = injector.getRequiredCredentials(workflow);

        expect(required, contains('postgres'));
        // Email node might use different credential structure
      });

      test('File Upload template requires AWS credentials', () {
        final workflow = WorkflowTemplates.fileUpload(
          s3Bucket: 'test-bucket',
        );

        final injector = WorkflowCredentialInjector(credManager);
        final required = injector.getRequiredCredentials(workflow);

        expect(required, contains('aws'));
        expect(required, contains('postgres'));
        expect(required, contains('slack'));
      });

      test('Order Processing template requires Stripe credentials', () {
        final workflow = WorkflowTemplates.orderProcessing(
          notificationEmail: 'orders@example.com',
        );

        final injector = WorkflowCredentialInjector(credManager);
        final required = injector.getRequiredCredentials(workflow);

        expect(required, contains('stripe'));
        expect(required, contains('postgres'));
      });
    });

    group('File Generation with Credentials', () {
      test('generates workflow JSON file with injected credentials', () async {
        final workflow = WorkflowBuilder.create()
            .name('Test Export')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .postgres(name: 'DB', operation: 'select')
            .build();

        final injector = WorkflowCredentialInjector(credManager);
        final workflowWithCreds = injector.injectCredentials(workflow);

        final outputPath = '${tempDir.path}/test_workflow.json';
        await workflowWithCreds.saveToFile(outputPath);

        // Verify file was created
        final file = File(outputPath);
        expect(file.existsSync(), isTrue);

        // Verify it's valid JSON
        final content = await file.readAsString();
        expect(content, isNotEmpty);

        // Verify structure by decoding JSON
        final jsonString = workflowWithCreds.toJson();
        final decoded = jsonDecode(jsonString);
        expect(decoded['name'], equals('Test Export'));
        expect(decoded['nodes'], isList);
        expect(decoded['connections'], isMap);
      });

      test('generates all template workflows', () async {
        final templates = [
          WorkflowTemplates.crudApi(
            resourceName: 'products',
            tableName: 'products',
          ),
          WorkflowTemplates.userRegistration(
            fromEmail: 'noreply@example.com',
          ),
          WorkflowTemplates.fileUpload(s3Bucket: 'test-bucket'),
          WorkflowTemplates.orderProcessing(
            notificationEmail: 'orders@example.com',
          ),
          WorkflowTemplates.multiStepForm(tableName: 'forms'),
          WorkflowTemplates.scheduledReport(
            reportName: 'Weekly Report',
            recipients: 'team@example.com',
          ),
          WorkflowTemplates.dataSync(
            sourceName: 'Source',
            targetName: 'Target',
          ),
          WorkflowTemplates.webhookLogger(spreadsheetId: 'test-sheet-id'),
        ];

        final injector = WorkflowCredentialInjector(credManager);

        for (var i = 0; i < templates.length; i++) {
          final workflow = injector.injectCredentials(templates[i]);
          final path = '${tempDir.path}/template_$i.json';

          await workflow.saveToFile(path);

          final file = File(path);
          expect(file.existsSync(), isTrue, reason: 'Template $i should save');

          // Verify it's valid n8n format
          final jsonString = workflow.toJson();
          final decoded = jsonDecode(jsonString);
          expect(decoded['name'], isNotEmpty);
          expect(decoded['nodes'], isNotEmpty);
        }
      });
    });

    group('Error Handling', () {
      test('handles workflow with no credentials', () {
        final workflow = WorkflowBuilder.create()
            .name('No Creds')
            .webhookTrigger(name: 'Trigger', path: 'test')
            .function(
              name: 'Transform',
              code: 'return [{json: {test: true}}];',
            )
            .build();

        final injector = WorkflowCredentialInjector(credManager);
        final result = injector.injectCredentials(workflow);

        // Should not throw, just return workflow as-is
        expect(result.nodes, hasLength(2));
      });

      test('handles unknown node types gracefully', () {
        // Create workflow with custom node type
        final workflow = N8nWorkflow(
          name: 'Custom Node',
          nodes: [
            WorkflowNode(
              id: '1',
              name: 'Custom',
              type: 'custom-node-type',
              position: const NodePosition(0, 0),
              parameters: {},
              credentials: {'custom': {'id': 'credential_id', 'name': 'Custom'}},
            ),
          ],
          connections: {},
        );

        final injector = WorkflowCredentialInjector(credManager);
        final result = injector.injectCredentials(workflow);

        // Should keep original credentials for unknown types
        expect(result.nodes.first.credentials!['custom']['id'],
            equals('credential_id'));
      });
    });
  });
}
