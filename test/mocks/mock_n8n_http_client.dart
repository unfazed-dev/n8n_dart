import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Mock HTTP client for testing n8n operations
///
/// Provides comprehensive mocking capabilities for HTTP requests with:
/// - Response mocking by path
/// - Sequential responses for multiple calls
/// - Error simulation
/// - Request counting and tracking
/// - Callback hooks for verification
class MockN8nHttpClient extends http.BaseClient {
  final Map<String, Map<String, dynamic>> _responses = {};
  final Map<String, List<Map<String, dynamic>>> _sequentialResponses = {};
  final Map<String, int> _sequentialIndexes = {};
  final Map<String, Exception> _errors = {};
  final Map<String, int> _requestCounts = {};
  final Map<String, List<Function(http.Request)>> _requestCallbacks = {};
  final List<http.Request> _requestHistory = [];

  /// Mock a successful response for a specific path
  void mockResponse(String path, Map<String, dynamic> response,
      {int statusCode = 200}) {
    _responses[path] = {
      'body': response,
      'statusCode': statusCode,
    };
  }

  /// Mock sequential responses for multiple calls to the same path
  void mockSequentialResponses(String path, List<Map<String, dynamic>> responses,
      {int statusCode = 200}) {
    _sequentialResponses[path] = responses.map((response) {
      return {
        'body': response,
        'statusCode': statusCode,
      };
    }).toList();
    _sequentialIndexes[path] = 0;
  }

  /// Mock an error response for a specific path
  void mockError(String path, Exception error) {
    _errors[path] = error;
  }

  /// Register a callback to be invoked when a request is made to a path
  void onRequest(String path, Function(http.Request) callback) {
    _requestCallbacks.putIfAbsent(path, () => []);
    _requestCallbacks[path]!.add(callback);
  }

  /// Get the number of requests made to a specific path
  int requestCount(String path) {
    return _requestCounts[path] ?? 0;
  }

  /// Get all requests made to a specific path
  List<http.Request> getRequestsTo(String path) {
    return _requestHistory.where((req) => _matchesPath(req.url, path)).toList();
  }

  /// Get all requests made
  List<http.Request> get allRequests => List.unmodifiable(_requestHistory);

  /// Clear all mocks and history
  void reset() {
    _responses.clear();
    _sequentialResponses.clear();
    _sequentialIndexes.clear();
    _errors.clear();
    _requestCounts.clear();
    _requestCallbacks.clear();
    _requestHistory.clear();
  }

  /// Mock health check endpoint
  void mockHealthCheck(bool isHealthy) {
    mockResponse('/api/health', {'status': 'ok'},
        statusCode: isHealthy ? 200 : 500);
  }

  /// Mock workflow start endpoint
  void mockStartWorkflow(String webhookId, String executionId,
      {int statusCode = 200}) {
    mockResponse('/api/start-workflow/$webhookId',
        {'executionId': executionId}, statusCode: statusCode);
  }

  /// Mock execution status endpoint
  void mockExecutionStatus(String executionId, Map<String, dynamic> execution,
      {int statusCode = 200}) {
    mockResponse(
        '/api/execution/$executionId', execution, statusCode: statusCode);
  }

  /// Mock resume workflow endpoint
  void mockResumeWorkflow(String executionId, {int statusCode = 200}) {
    mockResponse(
        '/api/resume-workflow/$executionId', {'success': true},
        statusCode: statusCode);
  }

  /// Mock cancel workflow endpoint
  void mockCancelWorkflow(String executionId, {int statusCode = 200}) {
    mockResponse(
        '/api/cancel-workflow/$executionId', {'success': true},
        statusCode: statusCode);
  }

  /// Mock webhook validation endpoint
  void mockWebhookValidation(String webhookId, bool isValid) {
    mockResponse('/api/validate-webhook/$webhookId', {'valid': isValid},
        statusCode: isValid ? 200 : 404);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final req = request as http.Request;
    _requestHistory.add(req);

    // Extract path from URL
    final path = req.url.path;

    // Increment request count
    _requestCounts[path] = (_requestCounts[path] ?? 0) + 1;

    // Trigger callbacks
    if (_requestCallbacks.containsKey(path)) {
      for (final callback in _requestCallbacks[path]!) {
        callback(req);
      }
    }

    // Check for error mock
    if (_errors.containsKey(path)) {
      throw _errors[path]!;
    }

    // Check for sequential responses
    if (_sequentialResponses.containsKey(path)) {
      final index = _sequentialIndexes[path]!;
      final responses = _sequentialResponses[path]!;

      if (index < responses.length) {
        final response = responses[index];
        _sequentialIndexes[path] = index + 1;

        return http.StreamedResponse(
          Stream.value(utf8.encode(json.encode(response['body']))),
          response['statusCode'] as int,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }
    }

    // Check for single response mock
    if (_responses.containsKey(path)) {
      final response = _responses[path]!;
      return http.StreamedResponse(
        Stream.value(utf8.encode(json.encode(response['body']))),
        response['statusCode'] as int,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    }

    // Default 404 response
    return http.StreamedResponse(
      Stream.value(utf8.encode(json.encode({'error': 'Not found'}))),
      404,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }

  /// Check if URL matches path pattern
  bool _matchesPath(Uri url, String pattern) {
    // Simple path matching - can be enhanced for wildcard support
    return url.path == pattern ||
        url.path.startsWith(pattern) ||
        pattern.contains('*') && _matchesWildcard(url.path, pattern);
  }

  /// Wildcard path matching
  bool _matchesWildcard(String path, String pattern) {
    final regex = RegExp(
      '^${pattern.replaceAll('*', '.*')}\$',
    );
    return regex.hasMatch(path);
  }
}
