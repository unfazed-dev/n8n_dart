#!/usr/bin/env dart

/// Workflow verification script for CI/CD
///
/// This script verifies that all required test workflows exist and are active
/// on the n8n cloud instance before running integration tests.
///
/// Usage:
/// ```bash
/// dart run test/integration/utils/verify_workflows.dart
/// ```
///
/// Exit codes:
/// - 0: All workflows verified successfully
/// - 1: One or more workflows missing or inactive

import 'dart:io';

import 'package:n8n_dart/n8n_dart.dart';

import '../config/test_config.dart';

void main() async {
  print('🔍 Verifying n8n workflows...\n');

  var hasErrors = false;

  try {
    // Load configuration
    final isCI = Platform.environment['CI'] == 'true';
    final config = isCI ? TestConfig.fromEnvironment() : TestConfig.load();

    if (config.apiKey == null) {
      print('⚠️  API key not configured, skipping workflow verification');
      print('   Workflows will be discovered during test execution');
      exit(0);
    }

    // Create discovery service
    print('📡 Connecting to n8n cloud...');
    print('   Base URL: ${config.baseUrl}\n');

    final discovery = N8nDiscoveryService(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey!,
    );

    try {
      // Discover all workflows
      print('🔎 Discovering workflows with webhooks...');
      final workflows = await discovery.discoverAllWorkflows();

      if (workflows.isEmpty) {
        print('❌ No workflows with webhooks found!');
        print('   Please ensure test workflows are created and active');
        hasErrors = true;
      } else {
        print('✅ Found ${workflows.length} workflow(s) with webhooks:\n');
        for (final workflow in workflows.values) {
          print('   📄 ${workflow.name}');
          print('      ID: ${workflow.id}');
          print('      Webhook: ${workflow.httpMethod} ${workflow.webhookPath}');
          print('');
        }
      }

      // Verify required workflows
      print('🎯 Verifying required test workflows...');

      final requiredPaths = [
        config.simpleWebhookPath,
        config.waitNodeWebhookPath,
        config.slowWebhookPath,
        config.errorWebhookPath,
      ];

      for (final path in requiredPaths) {
        final workflowId = await discovery.findWorkflowByWebhookPath(path);

        if (workflowId != null) {
          final workflow = workflows[workflowId] ??
              WorkflowInfo(
                id: workflowId,
                name: 'Unknown',
                webhookPath: path,
                httpMethod: 'POST',
              );
          print('   ✅ $path → ${workflow.name} ($workflowId)');
        } else {
          print('   ❌ $path → NOT FOUND');
          hasErrors = true;
        }
      }

      // Check workflow activation status
      print('\n🔄 Checking workflow activation...');
      final activeWorkflows = await discovery.listActiveWorkflows();
      print('   Active workflows: ${activeWorkflows.length}');

      for (final path in requiredPaths) {
        final workflowId = await discovery.findWorkflowByWebhookPath(path);
        if (workflowId != null) {
          final isActive = activeWorkflows.containsKey(workflowId);
          if (!isActive) {
            print('   ⚠️  Workflow $workflowId is INACTIVE');
            print('      Please activate it in n8n cloud');
          }
        }
      }
    } finally {
      discovery.dispose();
    }

    // Final summary
    print('\n${'=' * 60}');
    if (hasErrors) {
      print('❌ Workflow verification FAILED');
      print('=' * 60);
      print('\n💡 Troubleshooting:');
      print('   1. Ensure all test workflows are created in n8n cloud');
      print('   2. Verify workflows have webhook triggers configured');
      print('   3. Check that workflows are active (not paused)');
      print('   4. Confirm webhook paths match configuration');
      print('\n📚 See test/integration/README.md for setup instructions');
      exit(1);
    } else {
      print('✅ Workflow verification PASSED');
      print('=' * 60);
      print('\n✨ All test workflows are ready!');
      exit(0);
    }
  } catch (e, stackTrace) {
    print('\n❌ Fatal error during verification:');
    print(e);
    print('\nStack trace:');
    print(stackTrace);
    print('\n💡 This usually means:');
    print('   - Cannot connect to n8n cloud instance');
    print('   - Invalid API key');
    print('   - Network connectivity issues');
    exit(1);
  }
}
