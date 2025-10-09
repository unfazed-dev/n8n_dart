/// n8n workflow and execution discovery service
///
/// Provides methods to automatically discover workflow IDs and execution IDs
/// from the n8n API without requiring manual configuration.
///
/// This service is useful for:
/// - Finding workflows by webhook path
/// - Finding workflows by name
/// - Retrieving recent execution IDs
/// - Auto-discovery in tests and dynamic environments
///
/// Usage:
/// ```dart
/// final discoveryService = N8nDiscoveryService(
///   baseUrl: 'https://n8n.example.com',
///   apiKey: 'your-api-key',
/// );
///
/// // Find workflow by webhook path
/// final workflowId = await discoveryService.findWorkflowByWebhookPath('api/users');
///
/// // Get recent executions
/// final executions = await discoveryService.getRecentExecutions(workflowId, limit: 5);
///
/// // Find latest successful execution
/// final latestId = await discoveryService.getLatestExecution(
///   workflowId,
///   status: ExecutionStatus.success,
/// );
/// ```
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/n8n_models.dart';

/// Information about a discovered workflow
class WorkflowInfo {
  /// The unique workflow ID
  final String id;

  /// The workflow name
  final String name;

  /// The webhook path (e.g., 'api/users')
  final String webhookPath;

  /// The HTTP method for the webhook (GET, POST, etc.)
  final String httpMethod;

  const WorkflowInfo({
    required this.id,
    required this.name,
    required this.webhookPath,
    required this.httpMethod,
  });

  @override
  String toString() =>
      'WorkflowInfo(id: $id, name: $name, webhook: $httpMethod /$webhookPath)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkflowInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          webhookPath == other.webhookPath;

  @override
  int get hashCode => id.hashCode ^ webhookPath.hashCode;
}

/// Discovery service for finding workflows and executions in n8n
class N8nDiscoveryService {
  final String baseUrl;
  final String apiKey;
  final http.Client? httpClient;

  N8nDiscoveryService({
    required this.baseUrl,
    required this.apiKey,
    this.httpClient,
  });

  http.Client get _client => httpClient ?? http.Client();

  /// Find workflow ID by webhook path
  ///
  /// Searches through all active workflows to find one with a webhook node
  /// that matches the given path.
  ///
  /// Parameters:
  /// - [webhookPath]: The webhook path to search for (e.g., 'api/users')
  /// - [activeOnly]: Only search active workflows (default: true)
  ///
  /// Returns the workflow ID if found, null otherwise.
  Future<String?> findWorkflowByWebhookPath(
    String webhookPath, {
    bool activeOnly = true,
  }) async {
    try {
      // Fetch all workflows
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/workflows'),
        headers: {'X-N8N-API-KEY': apiKey},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final workflows = data['data'] as List<dynamic>;

      // Search for workflow with matching webhook path
      for (final workflow in workflows) {
        final workflowMap = workflow as Map<String, dynamic>;
        final isActive = workflowMap['active'] as bool? ?? false;

        if (activeOnly && !isActive) continue;

        // Check if this workflow has the matching webhook
        final workflowId = workflowMap['id'] as String;
        final detailResponse = await _client.get(
          Uri.parse('$baseUrl/api/v1/workflows/$workflowId'),
          headers: {'X-N8N-API-KEY': apiKey},
        );

        if (detailResponse.statusCode != 200) continue;

        final workflowDetail =
            json.decode(detailResponse.body) as Map<String, dynamic>;
        final nodes = workflowDetail['nodes'] as List<dynamic>;

        for (final node in nodes) {
          final nodeMap = node as Map<String, dynamic>;
          if (nodeMap['type'] == 'n8n-nodes-base.webhook') {
            final parameters = nodeMap['parameters'] as Map<String, dynamic>?;
            final path = parameters?['path'] as String?;

            if (path == webhookPath) {
              return workflowId;
            }
          }
        }
      }

      return null;
    } catch (e) {
      // Silent fail - return null to indicate not found
      return null;
    }
  }

  /// Find workflow ID by name
  ///
  /// Searches through all workflows to find one with a matching name.
  ///
  /// Parameters:
  /// - [name]: The workflow name to search for
  /// - [activeOnly]: Only search active workflows (default: true)
  /// - [exactMatch]: Use exact match instead of contains (default: true)
  ///
  /// Returns the workflow ID if found, null otherwise.
  Future<String?> findWorkflowByName(
    String name, {
    bool activeOnly = true,
    bool exactMatch = true,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/workflows'),
        headers: {'X-N8N-API-KEY': apiKey},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final workflows = data['data'] as List<dynamic>;

      for (final workflow in workflows) {
        final workflowMap = workflow as Map<String, dynamic>;
        final isActive = workflowMap['active'] as bool? ?? false;
        final workflowName = workflowMap['name'] as String? ?? '';

        if (activeOnly && !isActive) continue;

        final matches = exactMatch
            ? workflowName == name
            : workflowName.toLowerCase().contains(name.toLowerCase());

        if (matches) {
          return workflowMap['id'] as String;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get recent execution IDs for a workflow
  ///
  /// Fetches a list of execution IDs for the specified workflow,
  /// ordered by most recent first.
  ///
  /// Parameters:
  /// - [workflowId]: The workflow ID to fetch executions for
  /// - [limit]: Maximum number of executions to return (default: 10)
  /// - [status]: Filter by execution status (optional)
  ///
  /// Returns a list of execution IDs.
  Future<List<String>> getRecentExecutions(
    String workflowId, {
    int limit = 10,
    WorkflowStatus? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'workflowId': workflowId,
        'limit': limit.toString(),
      };

      if (status != null) {
        queryParams['status'] = _statusToString(status);
      }

      final uri = Uri.parse('$baseUrl/api/v1/executions')
          .replace(queryParameters: queryParams);

      final response = await _client.get(
        uri,
        headers: {'X-N8N-API-KEY': apiKey},
      );

      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final executions = data['data'] as List<dynamic>;

      return executions
          .map((e) => (e as Map<String, dynamic>)['id'] as String)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get the latest execution ID for a workflow
  ///
  /// Convenience method that returns just the most recent execution ID.
  ///
  /// Returns the execution ID if found, null otherwise.
  Future<String?> getLatestExecution(
    String workflowId, {
    WorkflowStatus? status,
  }) async {
    final executions = await getRecentExecutions(
      workflowId,
      limit: 1,
      status: status,
    );

    return executions.isEmpty ? null : executions.first;
  }

  /// Get recent executions by webhook path
  ///
  /// Convenience method that finds the workflow by webhook path first,
  /// then fetches recent executions.
  Future<List<String>> getRecentExecutionsByWebhookPath(
    String webhookPath, {
    int limit = 10,
    WorkflowStatus? status,
  }) async {
    final workflowId = await findWorkflowByWebhookPath(webhookPath);

    if (workflowId == null) {
      return [];
    }

    return getRecentExecutions(
      workflowId,
      limit: limit,
      status: status,
    );
  }

  /// Get recent executions by workflow name
  ///
  /// Convenience method that finds the workflow by name first,
  /// then fetches recent executions.
  Future<List<String>> getRecentExecutionsByWorkflowName(
    String workflowName, {
    int limit = 10,
    WorkflowStatus? status,
    bool exactMatch = true,
  }) async {
    final workflowId = await findWorkflowByName(
      workflowName,
      exactMatch: exactMatch,
    );

    if (workflowId == null) {
      return [];
    }

    return getRecentExecutions(
      workflowId,
      limit: limit,
      status: status,
    );
  }

  /// List all active workflows
  ///
  /// Returns a map of workflow ID to workflow name for all active workflows.
  Future<Map<String, String>> listActiveWorkflows() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/workflows'),
        headers: {'X-N8N-API-KEY': apiKey},
      );

      if (response.statusCode != 200) {
        return {};
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final workflows = data['data'] as List<dynamic>;

      final result = <String, String>{};
      for (final workflow in workflows) {
        final workflowMap = workflow as Map<String, dynamic>;
        final isActive = workflowMap['active'] as bool? ?? false;

        if (isActive) {
          final id = workflowMap['id'] as String;
          final name = workflowMap['name'] as String? ?? '';
          result[id] = name;
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  /// Discover ALL workflows with their webhook paths
  ///
  /// This method scans all active workflows and extracts webhook information.
  /// Returns a map where:
  /// - Key: webhook path (e.g., 'api/users')
  /// - Value: WorkflowInfo object with workflow ID, name, and webhook details
  ///
  /// This allows developers to discover all available workflows without
  /// manually configuring anything!
  ///
  /// Example:
  /// ```dart
  /// final workflows = await service.discoverAllWorkflows();
  /// for (final entry in workflows.entries) {
  ///   print('Webhook: ${entry.key}');
  ///   print('Workflow: ${entry.value.name} (${entry.value.id})');
  /// }
  /// ```
  Future<Map<String, WorkflowInfo>> discoverAllWorkflows() async {
    try {
      // Get all active workflows
      final response = await _client.get(
        Uri.parse('$baseUrl/api/v1/workflows'),
        headers: {'X-N8N-API-KEY': apiKey},
      );

      if (response.statusCode != 200) {
        return {};
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final workflows = data['data'] as List<dynamic>;

      final result = <String, WorkflowInfo>{};

      // For each active workflow, fetch details and extract webhook paths
      for (final workflow in workflows) {
        final workflowMap = workflow as Map<String, dynamic>;
        final isActive = workflowMap['active'] as bool? ?? false;

        if (!isActive) continue;

        final workflowId = workflowMap['id'] as String;
        final workflowName = workflowMap['name'] as String? ?? '';

        // Fetch workflow details to get nodes
        final detailResponse = await _client.get(
          Uri.parse('$baseUrl/api/v1/workflows/$workflowId'),
          headers: {'X-N8N-API-KEY': apiKey},
        );

        if (detailResponse.statusCode != 200) continue;

        final workflowDetail =
            json.decode(detailResponse.body) as Map<String, dynamic>;
        final nodes = workflowDetail['nodes'] as List<dynamic>;

        // Extract webhook paths from this workflow
        for (final node in nodes) {
          final nodeMap = node as Map<String, dynamic>;
          if (nodeMap['type'] == 'n8n-nodes-base.webhook') {
            final parameters = nodeMap['parameters'] as Map<String, dynamic>?;
            final path = parameters?['path'] as String?;
            final httpMethod =
                parameters?['httpMethod'] as String? ?? 'GET';

            if (path != null && path.isNotEmpty) {
              result[path] = WorkflowInfo(
                id: workflowId,
                name: workflowName,
                webhookPath: path,
                httpMethod: httpMethod,
              );
            }
          }
        }
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  /// Convert WorkflowStatus enum to n8n API status string
  String _statusToString(WorkflowStatus status) {
    switch (status) {
      case WorkflowStatus.new_:
        return 'new';
      case WorkflowStatus.running:
        return 'running';
      case WorkflowStatus.success:
        return 'success';
      case WorkflowStatus.error:
        return 'error';
      case WorkflowStatus.waiting:
        return 'waiting';
      case WorkflowStatus.canceled:
        return 'canceled';
      case WorkflowStatus.crashed:
        return 'crashed';
      case WorkflowStatus.unknown:
        return 'unknown';
    }
  }

  /// Dispose of resources
  void dispose() {
    if (httpClient == null) {
      _client.close();
    }
  }
}
