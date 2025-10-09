/// Template Validation Integration Tests
///
/// Tests all 8 pre-built workflow templates for:
/// - Valid JSON generation
/// - Proper node structure
/// - Correct connections
/// - Export/import roundtrip
/// - Template-specific requirements
@TestOn('vm')
library;

import 'dart:convert';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import 'utils/template_helpers.dart';

void main() {
  group('Template Validation - All Templates', () {
    group('Template 1: CRUD API', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.crudApi(
          resourceName: 'users',
          tableName: 'users',
          webhookPath: 'api/users',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        expect(() => jsonDecode(json), returnsNormally);

        final map = jsonDecode(json) as Map<String, dynamic>;
        validateWorkflowJson(map);
      });

      test('has correct name pattern', () {
        expect(workflow.name, equals('USERS CRUD API'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['api', 'crud', 'database']);
      });

      test('has minimum required nodes', () {
        // Webhook, Route Request, 4x CRUD operations, Response = 7 nodes minimum
        helper.expectMinimumNodes(7);
      });

      test('has webhook trigger', () {
        expect(hasWebhookTrigger(workflow), isTrue);
      });

      test('has database nodes', () {
        expect(hasDatabaseNode(workflow), isTrue);
      });

      test('has respond to webhook node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.respondToWebhook'), isTrue);
      });

      test('has connections between nodes', () {
        helper.expectHasConnections();
      });

      test('has function node for routing', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.function'), isTrue);
      });

      test('has correct webhook path in parameters', () {
        final webhookNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.webhook',
        );
        expect(webhookNode.parameters['path'], equals('api/users/users'));
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('crud_api.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });
    });

    group('Template 2: User Registration', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.userRegistration(
          fromEmail: 'noreply@example.com',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('User Registration Workflow'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['auth', 'registration', 'email']);
      });

      test('has minimum required nodes', () {
        // Webhook, Validate, Save, Generate Token, Email, Response = 6 nodes minimum
        helper.expectMinimumNodes(6);
      });

      test('has webhook trigger', () {
        expect(hasWebhookTrigger(workflow), isTrue);
      });

      test('has database node', () {
        expect(hasDatabaseNode(workflow), isTrue);
      });

      test('has email node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.emailSend'), isTrue);
      });

      test('has validation function', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.function'), isTrue);
      });

      test('has sequential connections', () {
        helper.expectHasConnections();

        // Verify specific connections
        TemplateAssertions.assertHasConnection(
          workflow,
          'Registration Webhook',
          'Validate Input',
        );
        TemplateAssertions.assertHasConnection(
          workflow,
          'Validate Input',
          'Save User',
        );
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('user_registration.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });
    });

    group('Template 3: File Upload', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.fileUpload(
          s3Bucket: 'my-test-bucket',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('File Upload & Processing'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['file', 'upload', 's3']);
      });

      test('has minimum required nodes', () {
        // Webhook, Extract, S3, Save Metadata, Notify, Response = 6 nodes minimum
        helper.expectMinimumNodes(6);
      });

      test('has webhook trigger', () {
        expect(hasWebhookTrigger(workflow), isTrue);
      });

      test('has AWS S3 node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.awsS3'), isTrue);
      });

      test('has database node for metadata', () {
        expect(hasDatabaseNode(workflow), isTrue);
      });

      test('has Slack notification node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.slack'), isTrue);
      });

      test('has sequential connections', () {
        helper.expectHasConnections();
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('file_upload.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });
    });

    group('Template 4: Order Processing', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.orderProcessing(
          notificationEmail: 'orders@example.com',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('Order Processing & Payment'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['ecommerce', 'payment', 'orders']);
      });

      test('has minimum required nodes', () {
        // Webhook, Calculate, Payment, IF, Save, 2x Email, Response = 8 nodes minimum
        helper.expectMinimumNodes(8);
      });

      test('has webhook trigger', () {
        expect(hasWebhookTrigger(workflow), isTrue);
      });

      test('has Stripe payment node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.stripe'), isTrue);
      });

      test('has IF conditional node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.if'), isTrue);
      });

      test('has database node', () {
        expect(hasDatabaseNode(workflow), isTrue);
      });

      test('has email nodes for notifications', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.emailSend'), isTrue);
      });

      test('has branching connections (success and failure paths)', () {
        helper.expectHasConnections();

        // Verify IF node has two output paths
        final ifNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.if',
        );
        final connections = workflow.connections[ifNode.name];
        expect(connections, isNotNull);
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('order_processing.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });
    });

    group('Template 5: Multi-Step Form (Has Wait Nodes!)', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.multiStepForm(
          tableName: 'forms',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('Multi-Step Form Workflow'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['form', 'wait', 'multi-step']);
      });

      test('has minimum required nodes', () {
        // Webhook, Initialize, Wait, Process, Wait, Process, Save, Response = 8 nodes minimum
        helper.expectMinimumNodes(8);
      });

      test('has webhook trigger', () {
        expect(hasWebhookTrigger(workflow), isTrue);
      });

      test('has WAIT NODES (critical for Phase 3!)', () {
        expect(hasWaitNode(workflow), isTrue);

        // Count wait nodes - should have at least 2
        final waitNodeCount = workflow.nodes.where(
          (n) => n.type == 'n8n-nodes-base.wait',
        ).length;
        expect(waitNodeCount, greaterThanOrEqualTo(2));
      });

      test('has database node for form data', () {
        expect(hasDatabaseNode(workflow), isTrue);
      });

      test('has function nodes for processing', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.function'), isTrue);
      });

      test('has sequential connections through wait nodes', () {
        helper.expectHasConnections();

        // Verify connections through wait nodes
        TemplateAssertions.assertHasConnection(
          workflow,
          'Initialize Form',
          'Wait for Step 2',
        );
        TemplateAssertions.assertHasConnection(
          workflow,
          'Wait for Step 2',
          'Process Step 2',
        );
      });

      test('wait nodes have correct resume type', () {
        final waitNodes = workflow.nodes.where(
          (n) => n.type == 'n8n-nodes-base.wait',
        );

        for (final waitNode in waitNodes) {
          expect(waitNode.parameters['resume'], equals('webhook'));
        }
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('multi_step_form.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });
    });

    group('Template 6: Scheduled Report', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.scheduledReport(
          reportName: 'Weekly Sales',
          recipients: 'team@example.com',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('Scheduled Weekly Sales Report'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['report', 'scheduled', 'email']);
      });

      test('has minimum required nodes', () {
        // Schedule Trigger, Fetch Data, Generate Report, Send Email = 4 nodes minimum
        helper.expectMinimumNodes(4);
      });

      test('has schedule trigger', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.scheduleTrigger'), isTrue);
      });

      test('has database node for data fetching', () {
        expect(hasDatabaseNode(workflow), isTrue);
      });

      test('has function node for report generation', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.function'), isTrue);
      });

      test('has email node for sending report', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.emailSend'), isTrue);
      });

      test('has sequential connections', () {
        helper.expectHasConnections();
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('scheduled_report.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });
    });

    group('Template 7: Data Sync', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.dataSync(
          sourceName: 'CRM',
          targetName: 'Database',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('CRM to Database Data Sync'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['sync', 'scheduled', 'integration']);
      });

      test('has minimum required nodes', () {
        // Schedule Trigger, Fetch, Transform, Send, Notify = 5 nodes minimum
        helper.expectMinimumNodes(5);
      });

      test('has schedule trigger', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.scheduleTrigger'), isTrue);
      });

      test('has HTTP request nodes', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.httpRequest'), isTrue);

        // Should have at least 2 HTTP nodes (fetch and send)
        final httpCount = workflow.nodes.where(
          (n) => n.type == 'n8n-nodes-base.httpRequest',
        ).length;
        expect(httpCount, greaterThanOrEqualTo(2));
      });

      test('has function node for data transformation', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.function'), isTrue);
      });

      test('has Slack notification node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.slack'), isTrue);
      });

      test('has sequential connections', () {
        helper.expectHasConnections();
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('data_sync.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });
    });

    group('Template 8: Webhook Logger', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.webhookLogger(
          spreadsheetId: 'test-spreadsheet-id',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('Webhook Event Logger'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['logging', 'google-sheets', 'webhook']);
      });

      test('has minimum required nodes', () {
        // Webhook, Format, Append to Sheet, Acknowledge = 4 nodes minimum
        helper.expectMinimumNodes(4);
      });

      test('has webhook trigger', () {
        expect(hasWebhookTrigger(workflow), isTrue);
      });

      test('has Google Sheets node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.googleSheets'), isTrue);
      });

      test('has function node for formatting', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.function'), isTrue);
      });

      test('has respond to webhook node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.respondToWebhook'), isTrue);
      });

      test('has sequential connections', () {
        helper.expectHasConnections();
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('webhook_logger.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });
    });

    group('Template Summary Statistics', () {
      test('all 8 templates generate valid JSON', () {
        final templates = [
          WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
          WorkflowTemplates.userRegistration(fromEmail: 'test@example.com'),
          WorkflowTemplates.fileUpload(s3Bucket: 'test-bucket'),
          WorkflowTemplates.orderProcessing(notificationEmail: 'test@example.com'),
          WorkflowTemplates.multiStepForm(tableName: 'test'),
          WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@example.com'),
          WorkflowTemplates.dataSync(sourceName: 'Source', targetName: 'Target'),
          WorkflowTemplates.webhookLogger(spreadsheetId: 'test-id'),
        ];

        for (final template in templates) {
          final json = template.toJson();
          expect(() => jsonDecode(json), returnsNormally);
        }
      });

      test('all templates have unique names', () {
        final templates = [
          WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
          WorkflowTemplates.userRegistration(fromEmail: 'test@example.com'),
          WorkflowTemplates.fileUpload(s3Bucket: 'test-bucket'),
          WorkflowTemplates.orderProcessing(notificationEmail: 'test@example.com'),
          WorkflowTemplates.multiStepForm(tableName: 'test'),
          WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@example.com'),
          WorkflowTemplates.dataSync(sourceName: 'Source', targetName: 'Target'),
          WorkflowTemplates.webhookLogger(spreadsheetId: 'test-id'),
        ];

        final names = templates.map((t) => t.name).toSet();
        expect(names.length, equals(8), reason: 'All templates should have unique names');
      });

      test('all templates have at least one tag', () {
        final templates = [
          WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
          WorkflowTemplates.userRegistration(fromEmail: 'test@example.com'),
          WorkflowTemplates.fileUpload(s3Bucket: 'test-bucket'),
          WorkflowTemplates.orderProcessing(notificationEmail: 'test@example.com'),
          WorkflowTemplates.multiStepForm(tableName: 'test'),
          WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@example.com'),
          WorkflowTemplates.dataSync(sourceName: 'Source', targetName: 'Target'),
          WorkflowTemplates.webhookLogger(spreadsheetId: 'test-id'),
        ];

        for (final template in templates) {
          expect(template.tags, isNotNull);
          expect(template.tags, isNotEmpty);
        }
      });

      test('count total nodes across all templates', () {
        final templates = [
          WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
          WorkflowTemplates.userRegistration(fromEmail: 'test@example.com'),
          WorkflowTemplates.fileUpload(s3Bucket: 'test-bucket'),
          WorkflowTemplates.orderProcessing(notificationEmail: 'test@example.com'),
          WorkflowTemplates.multiStepForm(tableName: 'test'),
          WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@example.com'),
          WorkflowTemplates.dataSync(sourceName: 'Source', targetName: 'Target'),
          WorkflowTemplates.webhookLogger(spreadsheetId: 'test-id'),
        ];

        var totalNodes = 0;
        for (final template in templates) {
          totalNodes += template.nodes.length;
        }

        expect(totalNodes, greaterThan(30), reason: 'Should have significant node coverage across all templates');
      });
    });

    group('Template 9: AI Chatbot with UI (Option 1)', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.aiChatbotWithUI(
          systemPrompt: 'You are a helpful test assistant.',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('AI Chatbot with UI'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['ai', 'chat', 'langchain', 'openai']);
      });

      test('has minimum required nodes', () {
        // Chat Trigger, AI Agent, OpenAI Model, Memory = 4 nodes
        helper.expectMinimumNodes(4);
      });

      test('has Chat Trigger node', () {
        expect(
          workflow.nodes.any((n) => n.type == 'n8n-nodes-langchain.chatTrigger'),
          isTrue,
        );
      });

      test('has AI Agent node', () {
        expect(
          workflow.nodes.any((n) => n.type == 'n8n-nodes-langchain.agent'),
          isTrue,
        );
      });

      test('has OpenAI Chat Model node', () {
        expect(
          workflow.nodes.any((n) => n.type == 'n8n-nodes-langchain.lmChatOpenAi'),
          isTrue,
        );
      });

      test('has Memory node when enabled', () {
        expect(
          workflow.nodes.any((n) => n.type == 'n8n-nodes-langchain.memoryBufferWindow'),
          isTrue,
        );
      });

      test('does not have Memory node when disabled', () {
        final workflowNoMemory = WorkflowTemplates.aiChatbotWithUI(
          enableMemory: false,
        );

        expect(
          workflowNoMemory.nodes.any((n) => n.type == 'n8n-nodes-langchain.memoryBufferWindow'),
          isFalse,
        );
      });

      test('has connections between nodes', () {
        helper.expectHasConnections();
      });

      test('Chat Trigger connects to AI Agent', () {
        TemplateAssertions.assertHasConnection(
          workflow,
          'Chat Trigger',
          'AI Agent',
        );
      });

      test('OpenAI model has correct parameters', () {
        final openaiNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-langchain.lmChatOpenAi',
        );

        expect(openaiNode.parameters['model'], equals('gpt-3.5-turbo'));
        expect(openaiNode.parameters['options']['temperature'], equals(0.7));
        expect(openaiNode.parameters['options']['maxTokens'], equals(1000));
      });

      test('AI Agent has correct system prompt', () {
        final agentNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-langchain.agent',
        );

        expect(agentNode.parameters['text'], equals('You are a helpful test assistant.'));
        expect(agentNode.parameters['options']['systemMessage'], equals('You are a helpful test assistant.'));
      });

      test('Chat Trigger has correct mode', () {
        final chatTrigger = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-langchain.chatTrigger',
        );

        expect(chatTrigger.parameters['mode'], equals('hostedChat'));
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('ai_chatbot_ui.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });

      test('supports different models', () {
        final gpt4Workflow = WorkflowTemplates.aiChatbotWithUI(
          modelName: 'gpt-4',
        );

        final openaiNode = gpt4Workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-langchain.lmChatOpenAi',
        );

        expect(openaiNode.parameters['model'], equals('gpt-4'));
      });

      test('supports custom temperature settings', () {
        final customWorkflow = WorkflowTemplates.aiChatbotWithUI(
          temperature: 0.2,
        );

        final openaiNode = customWorkflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-langchain.lmChatOpenAi',
        );

        expect(openaiNode.parameters['options']['temperature'], equals(0.2));
      });
    });

    group('Template 10: AI Chatbot with Webhook (Option 2)', () {
      late N8nWorkflow workflow;
      late TemplateTestHelper helper;

      setUp(() {
        workflow = WorkflowTemplates.aiChatbotWebhook(
          systemPrompt: 'You are a helpful API assistant.',
        );
        helper = createTemplateHelper(workflow);
      });

      test('generates valid workflow structure', () {
        validateWorkflowStructure(workflow);
      });

      test('generates valid JSON', () {
        final json = workflow.toJson();
        TemplateAssertions.assertValidJson(json);
      });

      test('has correct name', () {
        expect(workflow.name, equals('AI Chatbot API'));
      });

      test('has correct tags', () {
        TemplateAssertions.assertHasTags(workflow, ['ai', 'chat', 'webhook', 'api', 'langchain']);
      });

      test('has minimum required nodes', () {
        // Webhook, Parse Input, AI Response, Respond = 4 nodes minimum
        helper.expectMinimumNodes(4);
      });

      test('has webhook trigger', () {
        expect(hasWebhookTrigger(workflow), isTrue);
      });

      test('has respond to webhook node', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.respondToWebhook'), isTrue);
      });

      test('has function nodes for processing', () {
        expect(hasNodeType(workflow, 'n8n-nodes-base.function'), isTrue);

        // Should have at least 2 function nodes (Parse Input + AI Response)
        final functionCount = workflow.nodes.where(
          (n) => n.type == 'n8n-nodes-base.function',
        ).length;
        expect(functionCount, greaterThanOrEqualTo(2));
      });

      test('has sequential connections', () {
        helper.expectHasConnections();

        // Verify specific connection chain
        TemplateAssertions.assertHasConnection(
          workflow,
          'Chat Endpoint',
          'Parse Input',
        );
        TemplateAssertions.assertHasConnection(
          workflow,
          'Parse Input',
          'AI Response',
        );
        TemplateAssertions.assertHasConnection(
          workflow,
          'AI Response',
          'Send Response',
        );
      });

      test('webhook has correct path', () {
        final webhookNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.webhook',
        );

        expect(webhookNode.parameters['path'], equals('chat'));
      });

      test('webhook uses POST method', () {
        final webhookNode = workflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.webhook',
        );

        expect(webhookNode.parameters['method'], equals('POST'));
      });

      test('Parse Input function handles message extraction', () {
        final parseNode = workflow.nodes.firstWhere(
          (n) => n.name == 'Parse Input',
        );

        expect(parseNode.type, equals('n8n-nodes-base.function'));
        expect(parseNode.parameters['functionCode'], contains('message'));
        expect(parseNode.parameters['functionCode'], contains('sessionId'));
        expect(parseNode.parameters['functionCode'], contains('context'));
      });

      test('AI Response function formats output', () {
        final responseNode = workflow.nodes.firstWhere(
          (n) => n.name == 'AI Response',
        );

        expect(responseNode.type, equals('n8n-nodes-base.function'));
        expect(responseNode.parameters['functionCode'], contains('output'));
        expect(responseNode.parameters['functionCode'], contains('sessionId'));
        expect(responseNode.parameters['functionCode'], contains('timestamp'));
      });

      test('exports and imports correctly (roundtrip)', () async {
        await validateRoundtrip(workflow);
      });

      test('saves to file successfully', () async {
        await helper.validateAndSave('ai_chatbot_webhook.json');
      });

      test('all nodes have valid positions', () {
        TemplateAssertions.assertAllNodesHavePositions(workflow);
      });

      test('supports custom webhook paths', () {
        final customWorkflow = WorkflowTemplates.aiChatbotWebhook(
          webhookPath: 'api/chat/v1',
        );

        final webhookNode = customWorkflow.nodes.firstWhere(
          (n) => n.type == 'n8n-nodes-base.webhook',
        );

        expect(webhookNode.parameters['path'], equals('api/chat/v1'));
      });

      test('AI Response includes model name in output', () {
        final responseNode = workflow.nodes.firstWhere(
          (n) => n.name == 'AI Response',
        );

        expect(responseNode.parameters['functionCode'], contains('gpt-3.5-turbo'));
      });
    });

    group('Template Summary Statistics (Including AI Templates)', () {
      test('all 10 templates generate valid JSON', () {
        final templates = [
          WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
          WorkflowTemplates.userRegistration(fromEmail: 'test@example.com'),
          WorkflowTemplates.fileUpload(s3Bucket: 'test-bucket'),
          WorkflowTemplates.orderProcessing(notificationEmail: 'test@example.com'),
          WorkflowTemplates.multiStepForm(tableName: 'test'),
          WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@example.com'),
          WorkflowTemplates.dataSync(sourceName: 'Source', targetName: 'Target'),
          WorkflowTemplates.webhookLogger(spreadsheetId: 'test-id'),
          WorkflowTemplates.aiChatbotWithUI(),
          WorkflowTemplates.aiChatbotWebhook(),
        ];

        for (final template in templates) {
          final json = template.toJson();
          expect(() => jsonDecode(json), returnsNormally);
        }
      });

      test('all 10 templates have unique names', () {
        final templates = [
          WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
          WorkflowTemplates.userRegistration(fromEmail: 'test@example.com'),
          WorkflowTemplates.fileUpload(s3Bucket: 'test-bucket'),
          WorkflowTemplates.orderProcessing(notificationEmail: 'test@example.com'),
          WorkflowTemplates.multiStepForm(tableName: 'test'),
          WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@example.com'),
          WorkflowTemplates.dataSync(sourceName: 'Source', targetName: 'Target'),
          WorkflowTemplates.webhookLogger(spreadsheetId: 'test-id'),
          WorkflowTemplates.aiChatbotWithUI(),
          WorkflowTemplates.aiChatbotWebhook(),
        ];

        final names = templates.map((t) => t.name).toSet();
        expect(names.length, equals(10), reason: 'All 10 templates should have unique names');
      });

      test('AI templates use correct node types', () {
        final chatUI = WorkflowTemplates.aiChatbotWithUI();
        final chatWebhook = WorkflowTemplates.aiChatbotWebhook();

        // Chat UI should have langchain nodes
        expect(
          chatUI.nodes.any((n) => n.type.contains('langchain')),
          isTrue,
          reason: 'Chat UI template should use langchain nodes',
        );

        // Webhook should have webhook and function nodes
        expect(
          chatWebhook.nodes.any((n) => n.type == 'n8n-nodes-base.webhook'),
          isTrue,
          reason: 'Webhook template should have webhook trigger',
        );
      });
    });
  });
}
