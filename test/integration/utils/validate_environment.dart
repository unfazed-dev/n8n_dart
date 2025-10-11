#!/usr/bin/env dart

/// Environment validation script for CI/CD integration tests
///
/// This script validates that all required environment variables are set
/// and that the configuration is valid before running integration tests.
///
/// Usage:
/// ```bash
/// dart run test/integration/utils/validate_environment.dart
/// ```
///
/// Exit codes:
/// - 0: All validations passed
/// - 1: Validation failed
library;

import 'dart:io';

import '../config/test_config.dart';

void main() async {
  print('🔍 Validating integration test environment...\n');

  var hasErrors = false;

  try {
    // Check if running in CI environment
    final isCI = Platform.environment['CI'] == 'true';
    print('Environment: ${isCI ? 'CI/CD' : 'Local'}');

    // Load configuration
    print('\n📋 Loading configuration...');
    final config = isCI ? TestConfig.fromEnvironment() : TestConfig.load();

    print('✅ Configuration loaded successfully');
    print('   Base URL: ${config.baseUrl}');
    print('   API Key: ${config.apiKey != null ? '***configured***' : '❌ missing'}');
    print('   Timeout: ${config.timeoutSeconds}s');
    print('   Polling interval: ${config.pollingIntervalMs}ms');

    // Validate configuration
    print('\n🔧 Validating configuration...');
    final errors = config.validate();

    if (errors.isNotEmpty) {
      print('❌ Configuration validation failed:');
      for (final error in errors) {
        print('   - $error');
      }
      hasErrors = true;
    } else {
      print('✅ Configuration is valid');
    }

    // Check workflow configuration
    print('\n🔄 Checking workflow configuration...');
    final workflowIds = [
      ('Simple', config.simpleWorkflowId, config.simpleWebhookPath),
      ('Wait Node', config.waitNodeWorkflowId, config.waitNodeWebhookPath),
      ('Slow', config.slowWorkflowId, config.slowWebhookPath),
      ('Error', config.errorWorkflowId, config.errorWebhookPath),
    ];

    var autoDiscoveryNeeded = false;
    for (final (name, id, path) in workflowIds) {
      if (id == 'auto') {
        print('   $name: auto-discovery (path: $path)');
        autoDiscoveryNeeded = true;
      } else {
        print('   $name: $id (path: $path)');
      }
    }

    if (autoDiscoveryNeeded) {
      if (config.apiKey == null) {
        print('❌ API key required for auto-discovery');
        hasErrors = true;
      } else {
        print('✅ Auto-discovery will be used (requires API key)');
      }
    } else {
      print('✅ All workflow IDs configured');
    }

    // Check Supabase credentials (optional)
    print('\n🗄️  Checking Supabase credentials...');
    if (config.hasSupabaseCredentials) {
      print('✅ Supabase credentials configured');
      print('   URL: ${config.supabaseUrl}');
      print('   Database host: ${config.supabaseDbHost}');
    } else {
      print('ℹ️  Supabase credentials not configured (optional for Phase 3)');
    }

    // Check test flags
    print('\n🚩 Test execution flags...');
    print('   Run integration tests: ${config.runIntegrationTests}');
    print('   Skip slow tests: ${config.skipSlowTests}');

    if (!config.runIntegrationTests) {
      print('⚠️  Integration tests are disabled (CI_RUN_INTEGRATION_TESTS=false)');
    }

    // Final summary
    print('\n${'=' * 60}');
    if (hasErrors) {
      print('❌ Environment validation FAILED');
      print('=' * 60);
      exit(1);
    } else {
      print('✅ Environment validation PASSED');
      print('=' * 60);
      print('\n✨ Ready to run integration tests!');
      exit(0);
    }
  } catch (e, stackTrace) {
    print('\n❌ Fatal error during validation:');
    print(e);
    print('\nStack trace:');
    print(stackTrace);
    exit(1);
  }
}
