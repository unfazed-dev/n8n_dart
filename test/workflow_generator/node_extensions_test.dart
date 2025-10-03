import 'dart:convert';
import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowBuilder Extension - webhookTrigger', () {
    test('creates webhook trigger with required parameters', () {
      final workflow = WorkflowBuilder.create()
          .webhookTrigger(
            name: 'Webhook',
            path: 'test-webhook',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.name, equals('Webhook'));
      expect(node.type, equals('n8n-nodes-base.webhook'));
      expect(node.parameters['path'], equals('test-webhook'));
      expect(node.parameters['method'], equals('POST'));
      expect(node.parameters['authentication'], equals('none'));
    });

    test('creates webhook with custom method', () {
      final workflow = WorkflowBuilder.create()
          .webhookTrigger(
            name: 'GET Webhook',
            path: 'get-data',
            method: 'GET',
          )
          .build();

      expect(workflow.nodes[0].parameters['method'], equals('GET'));
    });

    test('creates webhook with authentication', () {
      final workflow = WorkflowBuilder.create()
          .webhookTrigger(
            name: 'Secure Webhook',
            path: 'secure',
            authentication: 'headerAuth',
          )
          .build();

      expect(workflow.nodes[0].parameters['authentication'], equals('headerAuth'));
    });

    test('creates webhook with additional parameters', () {
      final workflow = WorkflowBuilder.create()
          .webhookTrigger(
            name: 'Custom Webhook',
            path: 'custom',
            additionalParams: {
              'responseMode': 'lastNode',
              'options': {},
            },
          )
          .build();

      expect(workflow.nodes[0].parameters['responseMode'], equals('lastNode'));
    });
  });

  group('WorkflowBuilder Extension - httpRequest', () {
    test('creates HTTP GET request', () {
      final workflow = WorkflowBuilder.create()
          .httpRequest(
            name: 'Fetch Data',
            url: 'https://api.example.com/data',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.httpRequest'));
      expect(node.parameters['url'], equals('https://api.example.com/data'));
      expect(node.parameters['method'], equals('GET'));
    });

    test('creates HTTP POST request with body', () {
      final workflow = WorkflowBuilder.create()
          .httpRequest(
            name: 'Send Data',
            url: 'https://api.example.com/create',
            method: 'POST',
            body: {'name': 'test', 'value': 123},
          )
          .build();

      expect(workflow.nodes[0].parameters['method'], equals('POST'));
      expect(workflow.nodes[0].parameters['body'], isNotNull);
    });

    test('creates HTTP request with headers', () {
      final workflow = WorkflowBuilder.create()
          .httpRequest(
            name: 'Authenticated Request',
            url: 'https://api.example.com/secure',
            headers: {
              'Authorization': 'Bearer token123',
              'Content-Type': 'application/json',
            },
          )
          .build();

      final headers = workflow.nodes[0].parameters['headers'];
      expect(headers['Authorization'], equals('Bearer token123'));
      expect(headers['Content-Type'], equals('application/json'));
    });
  });

  group('WorkflowBuilder Extension - postgres', () {
    test('creates postgres insert operation', () {
      final workflow = WorkflowBuilder.create()
          .postgres(
            name: 'Insert User',
            operation: 'insert',
            table: 'users',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.postgres'));
      expect(node.parameters['operation'], equals('insert'));
      expect(node.parameters['table'], equals('users'));
      expect(node.credentials, isNotNull);
    });

    test('creates postgres select with query', () {
      final workflow = WorkflowBuilder.create()
          .postgres(
            name: 'Query Users',
            operation: 'select',
            query: 'SELECT * FROM users WHERE active = true',
          )
          .build();

      expect(workflow.nodes[0].parameters['query'], contains('SELECT'));
    });

    test('creates postgres with additional parameters', () {
      final workflow = WorkflowBuilder.create()
          .postgres(
            name: 'Custom Query',
            operation: 'executeQuery',
            additionalParams: {'timeout': 5000, 'returnAll': true},
          )
          .build();

      expect(workflow.nodes[0].parameters['timeout'], equals(5000));
      expect(workflow.nodes[0].parameters['returnAll'], isTrue);
    });

    test('includes postgres credentials', () {
      final workflow = WorkflowBuilder.create()
          .postgres(
            name: 'DB Operation',
            operation: 'update',
          )
          .build();

      expect(workflow.nodes[0].credentials!['postgres'], isNotNull);
    });
  });

  group('WorkflowBuilder Extension - emailSend', () {
    test('creates email node with required fields', () {
      final workflow = WorkflowBuilder.create()
          .emailSend(
            name: 'Send Email',
            fromEmail: 'sender@example.com',
            toEmail: 'recipient@example.com',
            subject: 'Test Email',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.emailSend'));
      expect(node.parameters['fromEmail'], equals('sender@example.com'));
      expect(node.parameters['toEmail'], equals('recipient@example.com'));
      expect(node.parameters['subject'], equals('Test Email'));
    });

    test('creates email with message body', () {
      final workflow = WorkflowBuilder.create()
          .emailSend(
            name: 'Welcome Email',
            fromEmail: 'noreply@app.com',
            toEmail: 'user@example.com',
            subject: 'Welcome!',
            message: 'Thank you for signing up!',
          )
          .build();

      expect(workflow.nodes[0].parameters['message'], contains('Thank you'));
    });

    test('creates email with additional parameters', () {
      final workflow = WorkflowBuilder.create()
          .emailSend(
            name: 'Custom Email',
            fromEmail: 'app@test.com',
            toEmail: 'user@test.com',
            subject: 'Test',
            additionalParams: {'cc': 'admin@test.com', 'attachments': []},
          )
          .build();

      expect(workflow.nodes[0].parameters['cc'], equals('admin@test.com'));
      expect(workflow.nodes[0].parameters['attachments'], isList);
    });
  });

  group('WorkflowBuilder Extension - function', () {
    test('creates function node with code', () {
      const code = 'return items.map(item => ({ json: { ...item.json, processed: true } }));';

      final workflow = WorkflowBuilder.create()
          .function(
            name: 'Transform Data',
            code: code,
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.function'));
      expect(node.parameters['functionCode'], equals(code));
    });
  });

  group('WorkflowBuilder Extension - ifNode', () {
    test('creates IF node with conditions', () {
      final workflow = WorkflowBuilder.create()
          .ifNode(
            name: 'Check Value',
            conditions: [
              {
                'leftValue': '={{json.amount}}',
                'operation': 'larger',
                'rightValue': 100,
              }
            ],
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.if'));
      expect(node.parameters['conditions'], isList);
      expect(node.parameters['conditions'].length, equals(1));
    });

    test('creates IF node with multiple conditions', () {
      final workflow = WorkflowBuilder.create()
          .ifNode(
            name: 'Complex Check',
            conditions: [
              {'leftValue': '={{json.age}}', 'operation': 'largerEqual', 'rightValue': 18},
              {'leftValue': '={{json.status}}', 'operation': 'equals', 'rightValue': 'active'},
            ],
          )
          .build();

      expect(workflow.nodes[0].parameters['conditions'].length, equals(2));
    });
  });

  group('WorkflowBuilder Extension - setNode', () {
    test('creates SET node with values', () {
      final workflow = WorkflowBuilder.create()
          .setNode(
            name: 'Set Variables',
            values: {
              'userId': '={{json.id}}',
              'timestamp': '={{new Date().toISOString()}}',
            },
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.set'));
      expect(node.parameters['values'], isNotNull);
      expect(node.parameters['values']['userId'], isNotNull);
    });
  });

  group('WorkflowBuilder Extension - waitNode', () {
    test('creates wait node for webhook', () {
      final workflow = WorkflowBuilder.create()
          .waitNode(
            name: 'Wait for Input',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.wait'));
      expect(node.parameters['resume'], equals('webhook'));
    });

    test('creates wait node with custom type', () {
      final workflow = WorkflowBuilder.create()
          .waitNode(
            name: 'Wait for Time',
            waitType: 'timeInterval',
          )
          .build();

      expect(workflow.nodes[0].parameters['resume'], equals('timeInterval'));
    });

    test('creates wait node with additional parameters', () {
      final workflow = WorkflowBuilder.create()
          .waitNode(
            name: 'Custom Wait',
            additionalParams: {'amount': 5, 'unit': 'minutes'},
          )
          .build();

      expect(workflow.nodes[0].parameters['amount'], equals(5));
      expect(workflow.nodes[0].parameters['unit'], equals('minutes'));
    });
  });

  group('WorkflowBuilder Extension - respondToWebhook', () {
    test('creates respond node with default status', () {
      final workflow = WorkflowBuilder.create()
          .respondToWebhook(
            name: 'Send Response',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.respondToWebhook'));
      expect(node.parameters['respondWith'], equals('json'));
      expect(node.parameters['responseCode'], equals(200));
    });

    test('creates respond node with custom status and body', () {
      final workflow = WorkflowBuilder.create()
          .respondToWebhook(
            name: 'Created Response',
            responseCode: 201,
            responseBody: {
              'status': 'created',
              'id': '={{json.id}}',
            },
          )
          .build();

      expect(workflow.nodes[0].parameters['responseCode'], equals(201));
      expect(workflow.nodes[0].parameters['responseBody'], isNotNull);
    });
  });

  group('WorkflowBuilder Extension - slack', () {
    test('creates slack message node', () {
      final workflow = WorkflowBuilder.create()
          .slack(
            name: 'Notify Team',
            channel: '#general',
            text: 'New order received',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.slack'));
      expect(node.parameters['channel'], equals('#general'));
      expect(node.parameters['text'], equals('New order received'));
      expect(node.credentials!['slackApi'], isNotNull);
    });

    test('creates slack with additional params', () {
      final workflow = WorkflowBuilder.create()
          .slack(
            name: 'Rich Message',
            channel: '#alerts',
            text: 'Alert',
            additionalParams: {
              'attachments': [],
              'otherOptions': {},
            },
          )
          .build();

      expect(workflow.nodes[0].parameters.containsKey('attachments'), isTrue);
    });
  });

  group('WorkflowBuilder Extension - stripe', () {
    test('creates stripe charge node', () {
      final workflow = WorkflowBuilder.create()
          .stripe(
            name: 'Process Payment',
            resource: 'charge',
            operation: 'create',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.stripe'));
      expect(node.parameters['resource'], equals('charge'));
      expect(node.parameters['operation'], equals('create'));
      expect(node.credentials!['stripeApi'], isNotNull);
    });

    test('creates stripe with amount parameter', () {
      final workflow = WorkflowBuilder.create()
          .stripe(
            name: 'Charge Card',
            resource: 'charge',
            operation: 'create',
            additionalParams: {
              'amount': '={{json.total * 100}}',
              'currency': 'usd',
            },
          )
          .build();

      expect(workflow.nodes[0].parameters['amount'], isNotNull);
      expect(workflow.nodes[0].parameters['currency'], equals('usd'));
    });
  });

  group('WorkflowBuilder Extension - googleSheets', () {
    test('creates google sheets append operation', () {
      final workflow = WorkflowBuilder.create()
          .googleSheets(
            name: 'Add Row',
            operation: 'append',
            spreadsheetId: 'sheet-123',
            sheetName: 'Data',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.googleSheets'));
      expect(node.parameters['operation'], equals('append'));
      expect(node.parameters['spreadsheetId'], equals('sheet-123'));
      expect(node.parameters['sheetName'], equals('Data'));
      expect(node.credentials!['googleSheetsOAuth2Api'], isNotNull);
    });

    test('creates google sheets with additional parameters', () {
      final workflow = WorkflowBuilder.create()
          .googleSheets(
            name: 'Update Sheet',
            operation: 'update',
            spreadsheetId: 'sheet-456',
            additionalParams: {'range': 'A1:Z100', 'valueInputMode': 'RAW'},
          )
          .build();

      expect(workflow.nodes[0].parameters['range'], equals('A1:Z100'));
      expect(workflow.nodes[0].parameters['valueInputMode'], equals('RAW'));
    });
  });

  group('WorkflowBuilder Extension - mongodb', () {
    test('creates mongodb find operation', () {
      final workflow = WorkflowBuilder.create()
          .mongodb(
            name: 'Find Documents',
            operation: 'find',
            collection: 'users',
            query: {'status': 'active'},
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.mongodb'));
      expect(node.parameters['operation'], equals('find'));
      expect(node.parameters['collection'], equals('users'));
      expect(node.parameters['query'], isNotNull);
      expect(node.credentials!['mongoDB'], isNotNull);
    });

    test('creates mongodb with additional parameters', () {
      final workflow = WorkflowBuilder.create()
          .mongodb(
            name: 'Custom Query',
            operation: 'aggregate',
            collection: 'orders',
            additionalParams: {'pipeline': [], 'options': {}},
          )
          .build();

      expect(workflow.nodes[0].parameters['pipeline'], isList);
      expect(workflow.nodes[0].parameters['options'], isMap);
    });
  });

  group('WorkflowBuilder Extension - awsS3', () {
    test('creates S3 upload operation', () {
      final workflow = WorkflowBuilder.create()
          .awsS3(
            name: 'Upload to S3',
            operation: 'upload',
            bucketName: 'my-bucket',
            fileName: 'file.txt',
          )
          .build();

      final node = workflow.nodes[0];
      expect(node.type, equals('n8n-nodes-base.awsS3'));
      expect(node.parameters['operation'], equals('upload'));
      expect(node.parameters['bucketName'], equals('my-bucket'));
      expect(node.parameters['fileName'], equals('file.txt'));
      expect(node.credentials!['aws'], isNotNull);
    });

    test('creates S3 with additional parameters', () {
      final workflow = WorkflowBuilder.create()
          .awsS3(
            name: 'Upload Custom',
            operation: 'upload',
            bucketName: 'files',
            additionalParams: {'acl': 'public-read', 'region': 'us-west-2'},
          )
          .build();

      expect(workflow.nodes[0].parameters['acl'], equals('public-read'));
      expect(workflow.nodes[0].parameters['region'], equals('us-west-2'));
    });
  });

  group('WorkflowBuilder Extension - Complete Workflows', () {
    test('builds complete workflow using extensions', () {
      final workflow = WorkflowBuilder.create()
          .name('Complete Extension Test')
          .webhookTrigger(name: 'Trigger', path: 'test')
          .function(name: 'Transform', code: 'return items;')
          .postgres(name: 'Save', operation: 'insert', table: 'data')
          .emailSend(
            name: 'Notify',
            fromEmail: 'app@example.com',
            toEmail: 'admin@example.com',
            subject: 'Data Saved',
          )
          .respondToWebhook(name: 'Response')
          .connectSequence(['Trigger', 'Transform', 'Save', 'Notify', 'Response'])
          .build();

      expect(workflow.nodes.length, equals(5));
      expect(workflow.connections.keys.length, equals(4));

      // Verify node types
      expect(workflow.nodes[0].type, equals('n8n-nodes-base.webhook'));
      expect(workflow.nodes[1].type, equals('n8n-nodes-base.function'));
      expect(workflow.nodes[2].type, equals('n8n-nodes-base.postgres'));
      expect(workflow.nodes[3].type, equals('n8n-nodes-base.emailSend'));
      expect(workflow.nodes[4].type, equals('n8n-nodes-base.respondToWebhook'));
    });

    test('validates generated workflow JSON structure', () {
      final jsonString = WorkflowBuilder.create()
          .name('JSON Validation')
          .webhookTrigger(name: 'Start', path: 'validate')
          .httpRequest(name: 'Fetch', url: 'https://api.example.com')
          .respondToWebhook(name: 'End')
          .connectSequence(['Start', 'Fetch', 'End'])
          .buildJson();

      final decoded = jsonDecode(jsonString);

      expect(decoded, isA<Map>());
      expect(decoded['name'], equals('JSON Validation'));
      expect(decoded['nodes'], isList);
      expect(decoded['nodes'].length, equals(3));
      expect(decoded['connections'], isA<Map>());
      expect(decoded['settings'], isA<Map>());
    });
  });

  group('WorkflowBuilder Extension - Parameter Validation', () {
    test('all extensions create valid parameters', () {
      final workflow = WorkflowBuilder.create()
          .webhookTrigger(name: 'W', path: 'p')
          .httpRequest(name: 'H', url: 'http://test.com')
          .postgres(name: 'P', operation: 'select')
          .emailSend(name: 'E', fromEmail: 'a@b.com', toEmail: 'c@d.com', subject: 'S')
          .function(name: 'F', code: 'return items;')
          .ifNode(name: 'I', conditions: [])
          .setNode(name: 'S', values: {})
          .waitNode(name: 'Wt')
          .respondToWebhook(name: 'R')
          .slack(name: 'Sl', channel: '#ch', text: 'txt')
          .stripe(name: 'St', resource: 'charge', operation: 'create')
          .googleSheets(name: 'G', operation: 'append')
          .mongodb(name: 'M', operation: 'find')
          .awsS3(name: 'A', operation: 'upload')
          .build();

      // Verify all nodes have valid parameters
      for (final node in workflow.nodes) {
        expect(node.parameters, isNotNull);
        expect(node.parameters, isA<Map<String, dynamic>>());
      }
    });
  });

  group('WorkflowBuilder Extension - Credentials Handling', () {
    test('nodes with credentials include them correctly', () {
      final workflow = WorkflowBuilder.create()
          .postgres(name: 'DB', operation: 'select')
          .slack(name: 'Slack', channel: '#ch', text: 'txt')
          .stripe(name: 'Stripe', resource: 'charge', operation: 'create')
          .googleSheets(name: 'Sheets', operation: 'append')
          .mongodb(name: 'Mongo', operation: 'find')
          .awsS3(name: 'S3', operation: 'upload')
          .build();

      final credentialedNodes = workflow.nodes.where((n) => n.credentials != null);
      expect(credentialedNodes.length, equals(6));

      // Verify each has appropriate credential type
      expect(workflow.nodes[0].credentials!.keys, contains('postgres'));
      expect(workflow.nodes[1].credentials!.keys, contains('slackApi'));
      expect(workflow.nodes[2].credentials!.keys, contains('stripeApi'));
      expect(workflow.nodes[3].credentials!.keys, contains('googleSheetsOAuth2Api'));
      expect(workflow.nodes[4].credentials!.keys, contains('mongoDB'));
      expect(workflow.nodes[5].credentials!.keys, contains('aws'));
    });
  });
}
