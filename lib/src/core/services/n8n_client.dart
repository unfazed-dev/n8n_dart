import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../configuration/n8n_configuration.dart';
import '../exceptions/error_handling.dart';
import '../models/n8n_models.dart';

/// Pure Dart n8n client for workflow automation
///
/// Core HTTP client for n8n operations without Flutter dependencies.
/// Suitable for Dart CLI applications, backend services, and Flutter apps.
///
/// Features:
/// - HTTP-based workflow operations (start, status, resume, cancel)
/// - Intelligent error handling with retry logic
/// - Webhook validation
/// - Connection health checks
///
/// Usage:
/// ```dart
/// final client = N8nClient(
///   config: N8nConfigProfiles.production(
///     baseUrl: 'https://n8n.example.com',
///     apiKey: 'your-api-key',
///   ),
/// );
///
/// final executionId = await client.startWorkflow('webhook-id', {'data': 'value'});
/// ```
class N8nClient {
  final N8nServiceConfig config;
  final http.Client? _customHttpClient;
  late final http.Client _httpClient;
  late final N8nErrorHandler _errorHandler;

  N8nClient({
    required this.config,
    http.Client? httpClient,
  }) : _customHttpClient = httpClient {
    _httpClient = _customHttpClient ?? http.Client();
    _errorHandler = N8nErrorHandler(config.retry);

    // Validate configuration
    final errors = config.validate();
    if (errors.isNotEmpty) {
      throw ArgumentError('Invalid configuration:\n${errors.join('\n')}');
    }
  }

  /// Start a workflow execution
  ///
  /// [webhookId] - The webhook ID to trigger
  /// [initialData] - Optional initial data for the workflow
  ///
  /// Returns the execution ID
  ///
  /// Throws [N8nException] on failure
  Future<String> startWorkflow(
    String webhookId,
    Map<String, dynamic>? initialData,
  ) async {
    if (webhookId.isEmpty) {
      throw N8nException.workflow('Webhook ID cannot be empty');
    }

    final url = Uri.parse('${config.baseUrl}/api/start-workflow/$webhookId');
    final headers = _buildHeaders();
    final body = json.encode({'body': initialData ?? {}});

    final response = await _errorHandler.executeWithRetry(() async {
      return _httpClient
          .post(url, headers: headers, body: body)
          .timeout(config.webhook.timeout);
    });

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final executionId = responseData['executionId'] as String?;

      if (executionId != null) {
        return executionId;
      } else {
        throw N8nException.serverError(
          'No execution ID returned from server',
          statusCode: response.statusCode,
        );
      }
    } else {
      throw N8nException.serverError(
        'Failed to start workflow: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Get execution status
  ///
  /// [executionId] - The execution ID to check
  ///
  /// Returns the current execution status
  ///
  /// Throws [N8nException] on failure
  Future<WorkflowExecution> getExecutionStatus(String executionId) async {
    if (executionId.isEmpty) {
      throw N8nException.workflow('Execution ID cannot be empty');
    }

    final url = Uri.parse('${config.baseUrl}/api/execution/$executionId');
    final headers = _buildHeaders();

    final response = await _errorHandler.executeWithRetry(() async {
      return _httpClient
          .get(url, headers: headers)
          .timeout(config.webhook.timeout);
    });

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body) as Map<String, dynamic>;
      final validationResult = WorkflowExecution.fromJsonSafe(responseData);

      if (validationResult.isValid) {
        return validationResult.value!;
      } else {
        throw N8nException.workflow(
          'Invalid execution data: ${validationResult.errors.join(', ')}',
        );
      }
    } else if (response.statusCode == 404) {
      throw N8nException.workflow(
        'Execution not found: $executionId',
      );
    } else {
      throw N8nException.serverError(
        'Failed to get execution status: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Resume a workflow with user input
  ///
  /// [executionId] - The execution ID to resume
  /// [inputData] - User input data for the wait node
  ///
  /// Returns true if successfully resumed
  ///
  /// Throws [N8nException] on failure
  Future<bool> resumeWorkflow(
    String executionId,
    Map<String, dynamic> inputData,
  ) async {
    if (executionId.isEmpty) {
      throw N8nException.workflow('Execution ID cannot be empty');
    }

    if (inputData.isEmpty) {
      throw N8nException.workflow('Input data cannot be empty');
    }

    final url = Uri.parse('${config.baseUrl}/api/resume-workflow/$executionId');
    final headers = _buildHeaders();
    final body = json.encode({'body': inputData});

    final response = await _errorHandler.executeWithRetry(() async {
      return _httpClient
          .post(url, headers: headers, body: body)
          .timeout(config.webhook.timeout);
    });

    if (response.statusCode == 200) {
      return true;
    } else {
      throw N8nException.serverError(
        'Failed to resume workflow: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Cancel a workflow execution
  ///
  /// [executionId] - The execution ID to cancel
  ///
  /// Returns true if successfully cancelled
  ///
  /// Throws [N8nException] on failure
  Future<bool> cancelWorkflow(String executionId) async {
    if (executionId.isEmpty) {
      throw N8nException.workflow('Execution ID cannot be empty');
    }

    final url = Uri.parse('${config.baseUrl}/api/cancel-workflow/$executionId');
    final headers = _buildHeaders();

    final response = await _errorHandler.executeWithRetry(() async {
      return _httpClient
          .delete(url, headers: headers)
          .timeout(config.webhook.timeout);
    });

    if (response.statusCode == 200) {
      return true;
    } else {
      throw N8nException.serverError(
        'Failed to cancel workflow: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Validate a webhook ID
  ///
  /// [webhookId] - The webhook ID to validate
  ///
  /// Returns true if the webhook is valid
  ///
  /// Throws [N8nException] on failure
  Future<bool> validateWebhook(String webhookId) async {
    if (webhookId.isEmpty) {
      return false;
    }

    try {
      final url = Uri.parse('${config.baseUrl}/api/validate-webhook/$webhookId');
      final headers = _buildHeaders();

      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(config.webhook.timeout);

      return response.statusCode == 200;
    } catch (error) {
      return false;
    }
  }

  /// Test connection to n8n server
  ///
  /// Returns true if connection is successful
  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('${config.baseUrl}/api/health');
      final headers = _buildHeaders();

      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (error) {
      return false;
    }
  }

  /// Build HTTP headers for requests
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add authentication headers if configured
    if (config.security.apiKey != null) {
      headers['Authorization'] = 'Bearer ${config.security.apiKey}';
    }

    // Add custom headers
    headers.addAll(config.security.customHeaders);

    return headers;
  }

  /// Dispose resources
  void dispose() {
    // Only close if we created the client
    if (_customHttpClient == null) {
      _httpClient.close();
    }
  }
}
