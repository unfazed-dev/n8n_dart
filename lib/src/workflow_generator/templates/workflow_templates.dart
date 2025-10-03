/// Pre-built n8n Workflow Templates
///
/// Ready-to-use workflow templates for common use cases

import '../workflow_builder.dart';
import '../models/workflow_models.dart';

/// Collection of pre-built workflow templates
class WorkflowTemplates {
  /// Create a simple CRUD API workflow (Create/Read/Update/Delete)
  static N8nWorkflow crudApi({
    required String resourceName,
    required String tableName,
    String webhookPath = 'api',
  }) {
    return WorkflowBuilder.create()
        .name('${resourceName.toUpperCase()} CRUD API')
        .tags(['api', 'crud', 'database'])
        .active(false)
        // Webhook trigger
        .webhookTrigger(
          name: 'Webhook',
          path: '$webhookPath/$resourceName',
          method: 'POST',
        )
        // Switch based on HTTP method
        .function(
          name: 'Route Request',
          code: '''
const method = \$input.item.json.headers['x-method'] || 'GET';
const id = \$input.item.json.query?.id;

return [{
  json: {
    method: method,
    id: id,
    body: \$input.item.json.body
  }
}];
''',
        )
        // CREATE
        .postgres(
          name: 'Create $resourceName',
          operation: 'insert',
          table: tableName,
        )
        // READ
        .newRow()
        .postgres(
          name: 'Read $resourceName',
          operation: 'select',
          table: tableName,
        )
        // UPDATE
        .newRow()
        .postgres(
          name: 'Update $resourceName',
          operation: 'update',
          table: tableName,
        )
        // DELETE
        .newRow()
        .postgres(
          name: 'Delete $resourceName',
          operation: 'delete',
          table: tableName,
        )
        // Response
        .newRow()
        .respondToWebhook(
          name: 'Send Response',
          responseCode: 200,
        )
        // Connect nodes
        .connect('Webhook', 'Route Request')
        .connect('Route Request', 'Create $resourceName')
        .connect('Route Request', 'Read $resourceName')
        .connect('Route Request', 'Update $resourceName')
        .connect('Route Request', 'Delete $resourceName')
        .connect('Create $resourceName', 'Send Response')
        .connect('Read $resourceName', 'Send Response')
        .connect('Update $resourceName', 'Send Response')
        .connect('Delete $resourceName', 'Send Response')
        .build();
  }

  /// Create a user registration workflow with email confirmation
  static N8nWorkflow userRegistration({
    String webhookPath = 'auth/register',
    String tableName = 'users',
    required String fromEmail,
  }) {
    return WorkflowBuilder.create()
        .name('User Registration Workflow')
        .tags(['auth', 'registration', 'email'])
        .active(false)
        .webhookTrigger(
          name: 'Registration Webhook',
          path: webhookPath,
          method: 'POST',
        )
        .function(
          name: 'Validate Input',
          code: '''
const { email, password, name } = \$input.item.json.body;

if (!email || !password || !name) {
  throw new Error('Missing required fields');
}

// Simple email validation
if (!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+\$/.test(email)) {
  throw new Error('Invalid email format');
}

return [{
  json: {
    email,
    name,
    password_hash: password, // In production, hash this!
    created_at: new Date().toISOString()
  }
}];
''',
        )
        .postgres(
          name: 'Save User',
          operation: 'insert',
          table: tableName,
        )
        .function(
          name: 'Generate Token',
          code: '''
const userId = \$input.item.json.id;
const token = Math.random().toString(36).substr(2);

return [{
  json: {
    userId,
    token,
    email: \$input.item.json.email,
    name: \$input.item.json.name
  }
}];
''',
        )
        .emailSend(
          name: 'Send Welcome Email',
          fromEmail: fromEmail,
          toEmail: r'={{$json.email}}',
          subject: 'Welcome to Our Platform!',
          message: r'''
Hello {{$json.name}},

Welcome to our platform! Your account has been created successfully.

Best regards,
The Team
''',
        )
        .respondToWebhook(
          name: 'Return Success',
          responseCode: 201,
          responseBody: {
            'message': 'User registered successfully',
            'userId': r'={{$json.userId}}',
          },
        )
        .connectSequence([
          'Registration Webhook',
          'Validate Input',
          'Save User',
          'Generate Token',
          'Send Welcome Email',
          'Return Success',
        ])
        .build();
  }

  /// Create a file upload processing workflow
  static N8nWorkflow fileUpload({
    String webhookPath = 'upload',
    required String s3Bucket,
  }) {
    return WorkflowBuilder.create()
        .name('File Upload & Processing')
        .tags(['file', 'upload', 's3'])
        .active(false)
        .webhookTrigger(
          name: 'Upload Webhook',
          path: webhookPath,
          method: 'POST',
        )
        .function(
          name: 'Extract File Data',
          code: '''
const { filename, fileData, mimeType } = \$input.item.json.body;

return [{
  json: {
    filename,
    fileData,
    mimeType,
    uploadedAt: new Date().toISOString()
  }
}];
''',
        )
        .awsS3(
          name: 'Upload to S3',
          operation: 'upload',
          bucketName: s3Bucket,
        )
        .postgres(
          name: 'Save Metadata',
          operation: 'insert',
          table: 'files',
        )
        .slack(
          name: 'Notify Team',
          channel: '#uploads',
          text: r'New file uploaded: {{$json.filename}}',
        )
        .respondToWebhook(
          name: 'Return Success',
          responseCode: 200,
          responseBody: {
            'message': 'File uploaded successfully',
            'fileUrl': r'={{$json.url}}',
          },
        )
        .connectSequence([
          'Upload Webhook',
          'Extract File Data',
          'Upload to S3',
          'Save Metadata',
          'Notify Team',
          'Return Success',
        ])
        .build();
  }

  /// Create an order processing workflow with payment
  static N8nWorkflow orderProcessing({
    String webhookPath = 'orders',
    required String notificationEmail,
  }) {
    return WorkflowBuilder.create()
        .name('Order Processing & Payment')
        .tags(['ecommerce', 'payment', 'orders'])
        .active(false)
        .webhookTrigger(
          name: 'Order Webhook',
          path: webhookPath,
          method: 'POST',
        )
        .function(
          name: 'Calculate Total',
          code: '''
const { items, userId } = \$input.item.json.body;
const total = items.reduce((sum, item) => sum + (item.price * item.quantity), 0);

return [{
  json: {
    userId,
    items,
    total,
    orderId: 'ORD-' + Date.now()
  }
}];
''',
        )
        .stripe(
          name: 'Process Payment',
          resource: 'charge',
          operation: 'create',
          additionalParams: {
            'amount': r'={{$json.total}}',
            'currency': 'usd',
          },
        )
        .ifNode(
          name: 'Payment Success?',
          conditions: [
            {
              'leftValue': r'={{$json.status}}',
              'operation': 'equals',
              'rightValue': 'succeeded',
            }
          ],
        )
        // Success path
        .postgres(
          name: 'Save Order',
          operation: 'insert',
          table: 'orders',
        )
        .emailSend(
          name: 'Send Confirmation',
          fromEmail: notificationEmail,
          toEmail: r'={{$json.customerEmail}}',
          subject: r'Order Confirmation - {{$json.orderId}}',
          message: 'Your order has been confirmed!',
        )
        // Failure path
        .newRow()
        .emailSend(
          name: 'Send Error Email',
          fromEmail: notificationEmail,
          toEmail: notificationEmail,
          subject: r'Payment Failed - {{$json.orderId}}',
          message: r'Payment failed for order {{$json.orderId}}',
        )
        .newRow()
        .respondToWebhook(
          name: 'Return Response',
          responseCode: 200,
        )
        .connect('Order Webhook', 'Calculate Total')
        .connect('Calculate Total', 'Process Payment')
        .connect('Process Payment', 'Payment Success?')
        .connect('Payment Success?', 'Save Order', sourceIndex: 0)
        .connect('Save Order', 'Send Confirmation')
        .connect('Send Confirmation', 'Return Response')
        .connect('Payment Success?', 'Send Error Email', sourceIndex: 1)
        .connect('Send Error Email', 'Return Response')
        .build();
  }

  /// Create a multi-step form workflow with wait nodes
  static N8nWorkflow multiStepForm({
    String webhookPath = 'form/start',
    required String tableName,
  }) {
    return WorkflowBuilder.create()
        .name('Multi-Step Form Workflow')
        .tags(['form', 'wait', 'multi-step'])
        .active(false)
        .webhookTrigger(
          name: 'Start Form',
          path: webhookPath,
          method: 'POST',
        )
        .function(
          name: 'Initialize Form',
          code: '''
return [{
  json: {
    formId: 'FORM-' + Date.now(),
    step1Data: \$input.item.json.body
  }
}];
''',
        )
        .waitNode(
          name: 'Wait for Step 2',
          waitType: 'webhook',
        )
        .function(
          name: 'Process Step 2',
          code: '''
return [{
  json: {
    ...\$input.item.json,
    step2Data: \$input.item.json.body
  }
}];
''',
        )
        .waitNode(
          name: 'Wait for Step 3',
          waitType: 'webhook',
        )
        .function(
          name: 'Process Step 3',
          code: '''
return [{
  json: {
    ...\$input.item.json,
    step3Data: \$input.item.json.body,
    completedAt: new Date().toISOString()
  }
}];
''',
        )
        .postgres(
          name: 'Save Form Data',
          operation: 'insert',
          table: tableName,
        )
        .respondToWebhook(
          name: 'Send Completion',
          responseCode: 200,
          responseBody: {
            'message': 'Form completed successfully',
            'formId': r'={{$json.formId}}',
          },
        )
        .connectSequence([
          'Start Form',
          'Initialize Form',
          'Wait for Step 2',
          'Process Step 2',
          'Wait for Step 3',
          'Process Step 3',
          'Save Form Data',
          'Send Completion',
        ])
        .build();
  }

  /// Create a scheduled report generation workflow
  static N8nWorkflow scheduledReport({
    required String reportName,
    required String recipients,
    String schedule = '0 9 * * 1', // Every Monday at 9 AM
  }) {
    return WorkflowBuilder.create()
        .name('Scheduled $reportName Report')
        .tags(['report', 'scheduled', 'email'])
        .active(false)
        .node(
          name: 'Schedule Trigger',
          type: 'n8n-nodes-base.scheduleTrigger',
          parameters: {
            'rule': {
              'interval': [
                {'field': 'cronExpression', 'expression': schedule}
              ]
            }
          },
        )
        .postgres(
          name: 'Fetch Data',
          operation: 'select',
          query: 'SELECT * FROM analytics WHERE created_at >= NOW() - INTERVAL \'7 days\'',
        )
        .function(
          name: 'Generate Report',
          code: '''
const data = \$input.all();
const report = {
  totalRecords: data.length,
  summary: 'Weekly report generated',
  date: new Date().toISOString()
};

return [{
  json: {
    report,
    reportHtml: '<h1>Weekly Report</h1><p>Total: ' + data.length + '</p>'
  }
}];
''',
        )
        .emailSend(
          name: 'Send Report',
          fromEmail: 'reports@example.com',
          toEmail: recipients,
          subject: 'Weekly $reportName Report',
          message: r'={{$json.reportHtml}}',
        )
        .connectSequence([
          'Schedule Trigger',
          'Fetch Data',
          'Generate Report',
          'Send Report',
        ])
        .build();
  }

  /// Create a data sync workflow
  static N8nWorkflow dataSync({
    required String sourceName,
    required String targetName,
    String schedule = '0 */6 * * *', // Every 6 hours
  }) {
    return WorkflowBuilder.create()
        .name('$sourceName to $targetName Data Sync')
        .tags(['sync', 'scheduled', 'integration'])
        .active(false)
        .node(
          name: 'Schedule Trigger',
          type: 'n8n-nodes-base.scheduleTrigger',
          parameters: {
            'rule': {
              'interval': [
                {'field': 'cronExpression', 'expression': schedule}
              ]
            }
          },
        )
        .httpRequest(
          name: 'Fetch from $sourceName',
          url: 'https://api.source.com/data',
          method: 'GET',
        )
        .function(
          name: 'Transform Data',
          code: '''
const items = \$input.all();
return items.map(item => ({
  json: {
    ...item.json,
    syncedAt: new Date().toISOString()
  }
}));
''',
        )
        .httpRequest(
          name: 'Send to $targetName',
          url: 'https://api.target.com/data',
          method: 'POST',
        )
        .slack(
          name: 'Notify Success',
          channel: '#sync-logs',
          text: r'Data sync completed: {{$json.recordsProcessed}} records',
        )
        .connectSequence([
          'Schedule Trigger',
          'Fetch from $sourceName',
          'Transform Data',
          'Send to $targetName',
          'Notify Success',
        ])
        .build();
  }

  /// Create a webhook to Google Sheets logger
  static N8nWorkflow webhookLogger({
    String webhookPath = 'log',
    required String spreadsheetId,
    String sheetName = 'Logs',
  }) {
    return WorkflowBuilder.create()
        .name('Webhook Event Logger')
        .tags(['logging', 'google-sheets', 'webhook'])
        .active(false)
        .webhookTrigger(
          name: 'Log Webhook',
          path: webhookPath,
          method: 'POST',
        )
        .function(
          name: 'Format Log Entry',
          code: '''
return [{
  json: {
    timestamp: new Date().toISOString(),
    event: \$input.item.json.body.event,
    data: JSON.stringify(\$input.item.json.body),
    source: \$input.item.json.headers['x-source'] || 'unknown'
  }
}];
''',
        )
        .googleSheets(
          name: 'Append to Sheet',
          operation: 'append',
          spreadsheetId: spreadsheetId,
          sheetName: sheetName,
        )
        .respondToWebhook(
          name: 'Acknowledge',
          responseCode: 200,
          responseBody: {'status': 'logged'},
        )
        .connectSequence([
          'Log Webhook',
          'Format Log Entry',
          'Append to Sheet',
          'Acknowledge',
        ])
        .build();
  }
}
