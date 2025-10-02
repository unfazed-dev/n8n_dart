import 'package:n8n_dart/n8n_dart.dart';

/// Example usage of n8n_dart package
///
/// This example demonstrates:
/// 1. Creating an n8n client
/// 2. Testing connection
/// 3. Starting a workflow
/// 4. Polling for execution status
/// 5. Handling wait nodes
/// 6. Resuming workflows
/// 7. Proper cleanup
void main() async {
  print('🚀 n8n_dart Example\n');

  // 1. Create client with development configuration
  print('Creating n8n client...');
  final client = N8nClient(
    config: N8nConfigProfiles.development(
      baseUrl: 'http://localhost:5678', // Change to your n8n server URL
    ),
  );

  try {
    // 2. Test connection
    print('\n📡 Testing connection to n8n server...');
    final isHealthy = await client.testConnection();

    if (!isHealthy) {
      print('❌ Cannot connect to n8n server');
      print('Make sure n8n is running at http://localhost:5678');
      return;
    }

    print('✅ Connected to n8n server');

    // 3. Validate webhook (optional)
    const webhookId = 'my-webhook-id'; // Change to your webhook ID
    print('\n🔍 Validating webhook: $webhookId');
    final isValid = await client.validateWebhook(webhookId);

    if (!isValid) {
      print('❌ Webhook not found: $webhookId');
      print('Please create a workflow with a webhook trigger');
      return;
    }

    print('✅ Webhook is valid');

    // 4. Start workflow
    print('\n▶️  Starting workflow...');
    final workflowData = {
      'name': 'John Doe',
      'email': 'john@example.com',
      'action': 'process',
      'timestamp': DateTime.now().toIso8601String(),
    };

    final executionId = await client.startWorkflow(webhookId, workflowData);
    print('✅ Workflow started with execution ID: $executionId');

    // 5. Poll for execution status
    print('\n⏳ Polling for execution status...\n');

    var pollCount = 0;
    const maxPolls = 30; // Prevent infinite loop

    while (pollCount < maxPolls) {
      pollCount++;
      await Future.delayed(const Duration(seconds: 2));

      try {
        final execution = await client.getExecutionStatus(executionId);

        print('Poll #$pollCount - Status: ${execution.status} '
            '(Duration: ${execution.duration.inSeconds}s)');

        // Check if finished
        if (execution.isFinished) {
          print('\n✅ Workflow completed!');
          print('   Status: ${execution.status}');
          print('   Duration: ${execution.duration.inSeconds}s');

          if (execution.isSuccessful) {
            print('   Result: ${execution.data}');
          } else if (execution.isFailed) {
            print('   Error: ${execution.error}');
          }

          break;
        }

        // Handle wait nodes
        if (execution.waitingForInput && execution.waitNodeData != null) {
          print('\n⏸️  Workflow is waiting for user input');
          final waitNode = execution.waitNodeData!;

          print('   Node: ${waitNode.nodeName}');
          if (waitNode.description != null) {
            print('   Description: ${waitNode.description}');
          }

          print('   Required fields:');
          for (final field in waitNode.fields) {
            final requiredMark = field.required ? '*' : ' ';
            print('     [$requiredMark] ${field.label} (${field.type})');
            if (field.placeholder != null) {
              print('         Placeholder: ${field.placeholder}');
            }
          }

          // Simulate user input
          print('\n   Providing simulated user input...');
          final userInput = <String, dynamic>{};

          for (final field in waitNode.fields) {
            switch (field.type) {
              case FormFieldType.email:
                userInput[field.name] = 'user@example.com';
                break;
              case FormFieldType.number:
                userInput[field.name] = '42';
                break;
              case FormFieldType.checkbox:
                userInput[field.name] = 'true';
                break;
              case FormFieldType.select:
                if (field.options != null && field.options!.isNotEmpty) {
                  userInput[field.name] = field.options!.first;
                }
                break;
              default:
                userInput[field.name] = field.defaultValue ?? 'Sample value';
            }
          }

          // Validate input
          final validationResult = waitNode.validateFormData(userInput);

          if (validationResult.isValid) {
            print('   ✅ Input validated successfully');
            print('   Resuming workflow...');

            await client.resumeWorkflow(executionId, userInput);
            print('   ✅ Workflow resumed');
          } else {
            print('   ❌ Validation failed:');
            for (final error in validationResult.errors) {
              print('      - $error');
            }
            break;
          }
        }
      } on N8nException catch (e) {
        print('❌ Error: ${e.message}');
        print('   Type: ${e.type}');
        if (e.isRetryable) {
          print('   This error is retryable, continuing...');
          continue;
        } else {
          print('   This error is not retryable, stopping.');
          break;
        }
      }
    }

    if (pollCount >= maxPolls) {
      print('\n⚠️  Max polls reached. Cancelling workflow...');
      await client.cancelWorkflow(executionId);
      print('✅ Workflow cancelled');
    }
  } catch (error) {
    print('\n❌ Unexpected error: $error');
  } finally {
    // 7. Cleanup
    print('\n🧹 Cleaning up...');
    client.dispose();
    print('✅ Client disposed');
  }

  print('\n✨ Example completed\n');
}
