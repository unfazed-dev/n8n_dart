#!/usr/bin/env dart

/// Execution cleanup script for CI/CD
///
/// This script cleans up old test executions on the n8n cloud instance
/// to prevent accumulation of test data.
///
/// Usage:
/// ```bash
/// dart run test/integration/utils/cleanup_executions.dart
/// ```
///
/// Environment variables:
/// - MAX_EXECUTIONS_AGE_DAYS: Maximum age of executions to keep (default: 7)
///
/// Exit codes:
/// - 0: Cleanup completed successfully
/// - 1: Error during cleanup

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:n8n_dart/n8n_dart.dart';

import '../config/test_config.dart';

void main() async {
  print('🧹 Cleaning up old test executions...\n');

  try {
    // Load configuration
    final isCI = Platform.environment['CI'] == 'true';
    final config = isCI ? TestConfig.fromEnvironment() : TestConfig.load();

    if (config.apiKey == null) {
      print('⚠️  API key not configured, skipping cleanup');
      print('   (Cleanup requires API access to n8n cloud)');
      exit(0);
    }

    // Get max age from environment
    final maxAgeDays = int.tryParse(
          Platform.environment['MAX_EXECUTIONS_AGE_DAYS'] ?? '7',
        ) ??
        7;

    final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));

    print('🔧 Configuration:');
    print('   Base URL: ${config.baseUrl}');
    print('   Max age: $maxAgeDays days');
    print('   Cutoff date: ${cutoffDate.toIso8601String()}');
    print('');

    // Create discovery service to get workflow IDs
    print('🔎 Discovering test workflows...');
    final discovery = N8nDiscoveryService(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey!,
    );

    List<String> workflowIds;
    try {
      final workflows = await discovery.discoverAllWorkflows();
      workflowIds = workflows.values.map((w) => w.id).toList();
      print('   Found ${workflowIds.length} workflow(s)');
    } finally {
      discovery.dispose();
    }

    if (workflowIds.isEmpty) {
      print('\nℹ️  No workflows found, nothing to clean up');
      exit(0);
    }

    // Clean up executions for each workflow
    var totalDeleted = 0;

    for (final workflowId in workflowIds) {
      print('\n📄 Processing workflow: $workflowId');

      // Get executions for this workflow
      final executions = await _getExecutions(
        config.baseUrl,
        config.apiKey!,
        workflowId,
      );

      print('   Found ${executions.length} execution(s)');

      // Filter old executions
      final oldExecutions = executions.where((exec) {
        final execTime = DateTime.parse(exec['startedAt'] as String);
        return execTime.isBefore(cutoffDate);
      }).toList();

      if (oldExecutions.isEmpty) {
        print('   ✅ No old executions to delete');
        continue;
      }

      print('   🗑️  Deleting ${oldExecutions.length} old execution(s)...');

      // Delete old executions
      var deleted = 0;
      for (final exec in oldExecutions) {
        final execId = exec['id'] as String;
        final success = await _deleteExecution(
          config.baseUrl,
          config.apiKey!,
          execId,
        );

        if (success) {
          deleted++;
        } else {
          print('      ⚠️  Failed to delete execution: $execId');
        }
      }

      print('   ✅ Deleted $deleted execution(s)');
      totalDeleted += deleted;
    }

    // Summary
    print('\n${'=' * 60}');
    print('✅ Cleanup completed successfully');
    print('=' * 60);
    print('   Total executions deleted: $totalDeleted');
    print('   Workflows processed: ${workflowIds.length}');

    exit(0);
  } catch (e, stackTrace) {
    print('\n❌ Error during cleanup:');
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

/// Get all executions for a workflow
Future<List<Map<String, dynamic>>> _getExecutions(
  String baseUrl,
  String apiKey,
  String workflowId,
) async {
  final url = Uri.parse('$baseUrl/api/v1/executions').replace(
    queryParameters: {
      'workflowId': workflowId,
      'limit': '100', // Get up to 100 executions
    },
  );

  final response = await http.get(
    url,
    headers: {
      'X-N8N-API-KEY': apiKey,
      'Accept': 'application/json',
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final executions = data['data'] as List<dynamic>? ?? [];
    return executions.cast<Map<String, dynamic>>();
  } else {
    throw Exception(
      'Failed to get executions: ${response.statusCode} ${response.body}',
    );
  }
}

/// Delete an execution
Future<bool> _deleteExecution(
  String baseUrl,
  String apiKey,
  String executionId,
) async {
  final url = Uri.parse('$baseUrl/api/v1/executions/$executionId');

  try {
    final response = await http.delete(
      url,
      headers: {
        'X-N8N-API-KEY': apiKey,
        'Accept': 'application/json',
      },
    );

    return response.statusCode == 200 || response.statusCode == 204;
  } catch (e) {
    return false;
  }
}

