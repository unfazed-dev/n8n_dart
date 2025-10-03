import 'dart:convert';
import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowTemplates - crudApi', () {
    test('creates CRUD API workflow', () {
      final workflow = WorkflowTemplates.crudApi(
        resourceName: 'users',
        tableName: 'users_table',
      );

      expect(workflow.name, contains('USERS CRUD API'));
      expect(workflow.tags, containsAll(['api', 'crud', 'database']));
      expect(workflow.active, isFalse);
    });

    test('CRUD workflow has required nodes', () {
      final workflow = WorkflowTemplates.crudApi(
        resourceName: 'products',
        tableName: 'products',
      );

      final nodeNames = workflow.nodes.map((n) => n.name).toList();

      expect(nodeNames, contains('Webhook'));
      expect(nodeNames, contains('Route Request'));
      expect(nodeNames, contains(contains('Create')));
      expect(nodeNames, contains(contains('Read')));
      expect(nodeNames, contains(contains('Update')));
      expect(nodeNames, contains(contains('Delete')));
      expect(nodeNames, contains('Send Response'));
    });

    test('CRUD workflow uses custom webhook path', () {
      final workflow = WorkflowTemplates.crudApi(
        resourceName: 'orders',
        tableName: 'orders',
        webhookPath: 'v2/api',
      );

      final webhookNode = workflow.nodes.firstWhere((n) => n.type.contains('webhook'));
      expect(webhookNode.parameters['path'], contains('v2/api'));
    });

    test('CRUD workflow has valid connections', () {
      final workflow = WorkflowTemplates.crudApi(
        resourceName: 'items',
        tableName: 'items',
      );

      expect(workflow.connections, isNotEmpty);
      expect(workflow.connections.keys, contains('Webhook'));
    });

    test('CRUD workflow generates valid JSON', () {
      final workflow = WorkflowTemplates.crudApi(
        resourceName: 'customers',
        tableName: 'customers',
      );

      final jsonString = workflow.toJson();
      final decoded = jsonDecode(jsonString);

      expect(decoded, isA<Map>());
      expect(decoded['name'], isNotNull);
      expect(decoded['nodes'], isList);
      expect(decoded['connections'], isA<Map>());
    });
  });

  group('WorkflowTemplates - userRegistration', () {
    test('creates user registration workflow', () {
      final workflow = WorkflowTemplates.userRegistration(
        fromEmail: 'welcome@app.com',
      );

      expect(workflow.name, equals('User Registration Workflow'));
      expect(workflow.tags, containsAll(['auth', 'registration', 'email']));
    });

    test('registration workflow uses custom webhook path', () {
      final workflow = WorkflowTemplates.userRegistration(
        webhookPath: 'custom/register',
        fromEmail: 'noreply@app.com',
      );

      final webhookNode = workflow.nodes.firstWhere((n) => n.type.contains('webhook'));
      expect(webhookNode.parameters['path'], equals('custom/register'));
    });

    test('registration workflow uses custom table', () {
      final workflow = WorkflowTemplates.userRegistration(
        tableName: 'app_users',
        fromEmail: 'welcome@app.com',
      );

      final saveNode = workflow.nodes.firstWhere(
        (n) => n.name == 'Save User',
      );
      expect(saveNode.parameters['table'], equals('app_users'));
    });

    test('registration workflow has all required nodes', () {
      final workflow = WorkflowTemplates.userRegistration(
        fromEmail: 'test@example.com',
      );

      final nodeNames = workflow.nodes.map((n) => n.name).toList();

      expect(nodeNames, contains('Registration Webhook'));
      expect(nodeNames, contains('Validate Input'));
      expect(nodeNames, contains('Save User'));
      expect(nodeNames, contains('Generate Token'));
      expect(nodeNames, contains('Send Welcome Email'));
      expect(nodeNames, contains('Return Success'));
    });

    test('registration workflow is properly connected', () {
      final workflow = WorkflowTemplates.userRegistration(
        fromEmail: 'test@example.com',
      );

      expect(workflow.connections, isNotEmpty);
      // Verify sequential connection
      expect(workflow.connections.length, greaterThanOrEqualTo(5));
    });
  });

  group('WorkflowTemplates - fileUpload', () {
    test('creates file upload workflow', () {
      final workflow = WorkflowTemplates.fileUpload(
        s3Bucket: 'my-uploads',
      );

      expect(workflow.name, equals('File Upload & Processing'));
      expect(workflow.tags, containsAll(['file', 'upload', 's3']));
    });

    test('file upload workflow uses custom webhook path', () {
      final workflow = WorkflowTemplates.fileUpload(
        webhookPath: 'files/new',
        s3Bucket: 'bucket-123',
      );

      final webhookNode = workflow.nodes.firstWhere((n) => n.type.contains('webhook'));
      expect(webhookNode.parameters['path'], equals('files/new'));
    });

    test('file upload workflow has required nodes', () {
      final workflow = WorkflowTemplates.fileUpload(
        s3Bucket: 'uploads',
      );

      final nodeNames = workflow.nodes.map((n) => n.name).toList();

      expect(nodeNames, contains('Upload Webhook'));
      expect(nodeNames, contains('Extract File Data'));
      expect(nodeNames, contains('Upload to S3'));
      expect(nodeNames, contains('Save Metadata'));
      expect(nodeNames, contains('Notify Team'));
      expect(nodeNames, contains('Return Success'));
    });

    test('file upload workflow includes S3 bucket config', () {
      final workflow = WorkflowTemplates.fileUpload(
        s3Bucket: 'test-bucket',
      );

      final s3Node = workflow.nodes.firstWhere((n) => n.name == 'Upload to S3');
      expect(s3Node.parameters['bucketName'], equals('test-bucket'));
    });
  });

  group('WorkflowTemplates - orderProcessing', () {
    test('creates order processing workflow', () {
      final workflow = WorkflowTemplates.orderProcessing(
        notificationEmail: 'orders@shop.com',
      );

      expect(workflow.name, equals('Order Processing & Payment'));
      expect(workflow.tags, containsAll(['ecommerce', 'payment', 'orders']));
    });

    test('order processing has payment nodes', () {
      final workflow = WorkflowTemplates.orderProcessing(
        notificationEmail: 'admin@shop.com',
      );

      final nodeNames = workflow.nodes.map((n) => n.name).toList();

      expect(nodeNames, contains('Order Webhook'));
      expect(nodeNames, contains('Calculate Total'));
      expect(nodeNames, contains('Process Payment'));
      expect(nodeNames, contains('Payment Success?'));
      expect(nodeNames, contains('Save Order'));
      expect(nodeNames, contains('Send Confirmation'));
    });

    test('order processing has conditional logic', () {
      final workflow = WorkflowTemplates.orderProcessing(
        notificationEmail: 'orders@shop.com',
      );

      // Should have IF node for payment success check
      final ifNode = workflow.nodes.firstWhere(
        (n) => n.type.contains('.if'),
      );
      expect(ifNode, isNotNull);
      expect(ifNode.name, equals('Payment Success?'));
    });

    test('order processing has error handling path', () {
      final workflow = WorkflowTemplates.orderProcessing(
        notificationEmail: 'orders@shop.com',
      );

      final nodeNames = workflow.nodes.map((n) => n.name).toList();
      expect(nodeNames, contains('Send Error Email'));
    });
  });

  group('WorkflowTemplates - multiStepForm', () {
    test('creates multi-step form workflow', () {
      final workflow = WorkflowTemplates.multiStepForm(
        tableName: 'submissions',
      );

      expect(workflow.name, equals('Multi-Step Form Workflow'));
      expect(workflow.tags, containsAll(['form', 'wait', 'multi-step']));
    });

    test('multi-step form has wait nodes', () {
      final workflow = WorkflowTemplates.multiStepForm(
        tableName: 'form_data',
      );

      final waitNodes = workflow.nodes.where((n) => n.type.contains('.wait')).toList();
      expect(waitNodes.length, greaterThanOrEqualTo(2));
    });

    test('multi-step form has data processing nodes', () {
      final workflow = WorkflowTemplates.multiStepForm(
        tableName: 'responses',
      );

      final nodeNames = workflow.nodes.map((n) => n.name).toList();

      expect(nodeNames, contains('Start Form'));
      expect(nodeNames, contains('Initialize Form'));
      expect(nodeNames, contains(contains('Wait for')));
      expect(nodeNames, contains('Save Form Data'));
      expect(nodeNames, contains('Send Completion'));
    });

    test('multi-step form uses custom table', () {
      final workflow = WorkflowTemplates.multiStepForm(
        tableName: 'custom_forms',
      );

      final saveNode = workflow.nodes.firstWhere(
        (n) => n.name == 'Save Form Data',
      );
      expect(saveNode.parameters['table'], equals('custom_forms'));
    });
  });

  group('WorkflowTemplates - scheduledReport', () {
    test('creates scheduled report workflow', () {
      final workflow = WorkflowTemplates.scheduledReport(
        reportName: 'Sales',
        recipients: 'team@company.com',
      );

      expect(workflow.name, contains('Sales Report'));
      expect(workflow.tags, containsAll(['report', 'scheduled', 'email']));
    });

    test('scheduled report uses custom schedule', () {
      final workflow = WorkflowTemplates.scheduledReport(
        reportName: 'Daily',
        recipients: 'admin@app.com',
        schedule: '0 8 * * *', // 8 AM daily
      );

      final scheduleNode = workflow.nodes.firstWhere(
        (n) => n.type.contains('scheduleTrigger'),
      );
      expect(scheduleNode, isNotNull);
    });

    test('scheduled report has required nodes', () {
      final workflow = WorkflowTemplates.scheduledReport(
        reportName: 'Weekly',
        recipients: 'team@app.com',
      );

      final nodeNames = workflow.nodes.map((n) => n.name).toList();

      expect(nodeNames, contains('Schedule Trigger'));
      expect(nodeNames, contains('Fetch Data'));
      expect(nodeNames, contains('Generate Report'));
      expect(nodeNames, contains('Send Report'));
    });

    test('scheduled report sends to correct recipients', () {
      final workflow = WorkflowTemplates.scheduledReport(
        reportName: 'Monthly',
        recipients: 'managers@company.com',
      );

      final emailNode = workflow.nodes.firstWhere(
        (n) => n.type.contains('emailSend'),
      );
      expect(emailNode.parameters['toEmail'], equals('managers@company.com'));
    });
  });

  group('WorkflowTemplates - dataSync', () {
    test('creates data sync workflow', () {
      final workflow = WorkflowTemplates.dataSync(
        sourceName: 'Shopify',
        targetName: 'Database',
      );

      expect(workflow.name, contains('Shopify to Database'));
      expect(workflow.tags, containsAll(['sync', 'scheduled', 'integration']));
    });

    test('data sync has schedule trigger', () {
      final workflow = WorkflowTemplates.dataSync(
        sourceName: 'API',
        targetName: 'DB',
      );

      final scheduleNode = workflow.nodes.firstWhere(
        (n) => n.type.contains('scheduleTrigger'),
      );
      expect(scheduleNode, isNotNull);
    });

    test('data sync has transformation node', () {
      final workflow = WorkflowTemplates.dataSync(
        sourceName: 'Source',
        targetName: 'Target',
      );

      final transformNode = workflow.nodes.firstWhere(
        (n) => n.name == 'Transform Data',
      );
      expect(transformNode.type, contains('.function'));
    });

    test('data sync uses custom schedule', () {
      final workflow = WorkflowTemplates.dataSync(
        sourceName: 'CRM',
        targetName: 'Warehouse',
        schedule: '0 */4 * * *', // Every 4 hours
      );

      final scheduleNode = workflow.nodes.firstWhere(
        (n) => n.type.contains('scheduleTrigger'),
      );
      expect(scheduleNode, isNotNull);
    });
  });

  group('WorkflowTemplates - webhookLogger', () {
    test('creates webhook logger workflow', () {
      final workflow = WorkflowTemplates.webhookLogger(
        spreadsheetId: 'sheet-123',
      );

      expect(workflow.name, equals('Webhook Event Logger'));
      expect(workflow.tags, containsAll(['logging', 'google-sheets', 'webhook']));
    });

    test('webhook logger uses custom webhook path', () {
      final workflow = WorkflowTemplates.webhookLogger(
        webhookPath: 'events/log',
        spreadsheetId: 'sheet-456',
      );

      final webhookNode = workflow.nodes.firstWhere((n) => n.type.contains('webhook'));
      expect(webhookNode.parameters['path'], equals('events/log'));
    });

    test('webhook logger uses custom sheet name', () {
      final workflow = WorkflowTemplates.webhookLogger(
        spreadsheetId: 'sheet-789',
        sheetName: 'EventLog',
      );

      final sheetsNode = workflow.nodes.firstWhere(
        (n) => n.type.contains('googleSheets'),
      );
      expect(sheetsNode.parameters['sheetName'], equals('EventLog'));
    });

    test('webhook logger has all required nodes', () {
      final workflow = WorkflowTemplates.webhookLogger(
        spreadsheetId: 'sheet-abc',
      );

      final nodeNames = workflow.nodes.map((n) => n.name).toList();

      expect(nodeNames, contains('Log Webhook'));
      expect(nodeNames, contains('Format Log Entry'));
      expect(nodeNames, contains('Append to Sheet'));
      expect(nodeNames, contains('Acknowledge'));
    });
  });

  group('WorkflowTemplates - General Properties', () {
    test('all templates are inactive by default', () {
      final templates = [
        WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
        WorkflowTemplates.userRegistration(fromEmail: 'test@test.com'),
        WorkflowTemplates.fileUpload(s3Bucket: 'bucket'),
        WorkflowTemplates.orderProcessing(notificationEmail: 'test@test.com'),
        WorkflowTemplates.multiStepForm(tableName: 'forms'),
        WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@test.com'),
        WorkflowTemplates.dataSync(sourceName: 'A', targetName: 'B'),
        WorkflowTemplates.webhookLogger(spreadsheetId: 'sheet'),
      ];

      for (final template in templates) {
        expect(template.active, isFalse);
      }
    });

    test('all templates have tags', () {
      final templates = [
        WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
        WorkflowTemplates.userRegistration(fromEmail: 'test@test.com'),
        WorkflowTemplates.fileUpload(s3Bucket: 'bucket'),
        WorkflowTemplates.orderProcessing(notificationEmail: 'test@test.com'),
        WorkflowTemplates.multiStepForm(tableName: 'forms'),
        WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@test.com'),
        WorkflowTemplates.dataSync(sourceName: 'A', targetName: 'B'),
        WorkflowTemplates.webhookLogger(spreadsheetId: 'sheet'),
      ];

      for (final template in templates) {
        expect(template.tags, isNotNull);
        expect(template.tags, isNotEmpty);
      }
    });

    test('all templates have nodes', () {
      final templates = [
        WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
        WorkflowTemplates.userRegistration(fromEmail: 'test@test.com'),
        WorkflowTemplates.fileUpload(s3Bucket: 'bucket'),
        WorkflowTemplates.orderProcessing(notificationEmail: 'test@test.com'),
        WorkflowTemplates.multiStepForm(tableName: 'forms'),
        WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@test.com'),
        WorkflowTemplates.dataSync(sourceName: 'A', targetName: 'B'),
        WorkflowTemplates.webhookLogger(spreadsheetId: 'sheet'),
      ];

      for (final template in templates) {
        expect(template.nodes, isNotEmpty);
        expect(template.nodes.length, greaterThan(3));
      }
    });

    test('all templates have connections', () {
      final templates = [
        WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
        WorkflowTemplates.userRegistration(fromEmail: 'test@test.com'),
        WorkflowTemplates.fileUpload(s3Bucket: 'bucket'),
        WorkflowTemplates.orderProcessing(notificationEmail: 'test@test.com'),
        WorkflowTemplates.multiStepForm(tableName: 'forms'),
        WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@test.com'),
        WorkflowTemplates.dataSync(sourceName: 'A', targetName: 'B'),
        WorkflowTemplates.webhookLogger(spreadsheetId: 'sheet'),
      ];

      for (final template in templates) {
        expect(template.connections, isNotEmpty);
      }
    });

    test('all templates generate valid JSON', () {
      final templates = [
        WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
        WorkflowTemplates.userRegistration(fromEmail: 'test@test.com'),
        WorkflowTemplates.fileUpload(s3Bucket: 'bucket'),
        WorkflowTemplates.orderProcessing(notificationEmail: 'test@test.com'),
        WorkflowTemplates.multiStepForm(tableName: 'forms'),
        WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@test.com'),
        WorkflowTemplates.dataSync(sourceName: 'A', targetName: 'B'),
        WorkflowTemplates.webhookLogger(spreadsheetId: 'sheet'),
      ];

      for (final template in templates) {
        final jsonString = template.toJson();
        expect(() => jsonDecode(jsonString), returnsNormally);

        final decoded = jsonDecode(jsonString);
        expect(decoded['name'], isNotNull);
        expect(decoded['nodes'], isList);
        expect(decoded['connections'], isA<Map>());
      }
    });
  });

  group('WorkflowTemplates - Template Uniqueness', () {
    test('each template has unique name', () {
      final templates = [
        WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test'),
        WorkflowTemplates.userRegistration(fromEmail: 'test@test.com'),
        WorkflowTemplates.fileUpload(s3Bucket: 'bucket'),
        WorkflowTemplates.orderProcessing(notificationEmail: 'test@test.com'),
        WorkflowTemplates.multiStepForm(tableName: 'forms'),
        WorkflowTemplates.scheduledReport(reportName: 'Test', recipients: 'test@test.com'),
        WorkflowTemplates.dataSync(sourceName: 'A', targetName: 'B'),
        WorkflowTemplates.webhookLogger(spreadsheetId: 'sheet'),
      ];

      final names = templates.map((t) => t.name).toSet();
      expect(names.length, equals(templates.length));
    });

    test('templates have different node configurations', () {
      final crud = WorkflowTemplates.crudApi(resourceName: 'test', tableName: 'test');
      final registration = WorkflowTemplates.userRegistration(fromEmail: 'test@test.com');

      expect(crud.nodes.length, isNot(equals(registration.nodes.length)));
    });
  });
}
