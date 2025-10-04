/// n8n Workflow Builder
///
/// Provides a fluent API for building n8n workflows programmatically
library;

import 'models/workflow_models.dart';

/// Builder class for creating n8n workflows with a fluent API
class WorkflowBuilder {
  String _name = 'Untitled Workflow';
  bool _active = false;
  double _version = 1;
  WorkflowSettings _settings = const WorkflowSettings();
  final List<WorkflowNode> _nodes = [];
  final Map<String, Map<String, List<List<NodeConnection>>>> _connections = {};
  final List<String> _tags = [];
  Map<String, dynamic>? _staticData;

  double _currentX = 100;
  double _currentY = 200;
  final double _horizontalSpacing = 250;
  final double _verticalSpacing = 100;

  /// Set workflow name
  WorkflowBuilder name(String name) {
    _name = name;
    return this;
  }

  /// Set workflow as active
  WorkflowBuilder active([bool isActive = true]) {
    _active = isActive;
    return this;
  }

  /// Set workflow version
  WorkflowBuilder version(double version) {
    _version = version;
    return this;
  }

  /// Set workflow settings
  WorkflowBuilder settings(WorkflowSettings settings) {
    _settings = settings;
    return this;
  }

  /// Add a tag to the workflow
  WorkflowBuilder tag(String tag) {
    _tags.add(tag);
    return this;
  }

  /// Add multiple tags to the workflow
  WorkflowBuilder tags(List<String> tags) {
    _tags.addAll(tags);
    return this;
  }

  /// Set static data
  WorkflowBuilder staticData(Map<String, dynamic> data) {
    _staticData = data;
    return this;
  }

  /// Add a custom node to the workflow
  WorkflowBuilder addNode(WorkflowNode node) {
    _nodes.add(node);
    return this;
  }

  /// Add a node with auto-positioning
  WorkflowBuilder node({
    required String name,
    required String type,
    int typeVersion = 1,
    Map<String, dynamic> parameters = const {},
    Map<String, dynamic>? credentials,
    bool? disabled,
    String? notes,
  }) {
    final position = NodePosition(_currentX, _currentY);
    _currentX += _horizontalSpacing;

    final node = WorkflowNode(
      name: name,
      type: type,
      typeVersion: typeVersion,
      position: position,
      parameters: parameters,
      credentials: credentials,
      disabled: disabled,
      notes: notes,
    );

    _nodes.add(node);
    return this;
  }

  /// Connect two nodes
  WorkflowBuilder connect(
    String sourceNodeName,
    String targetNodeName, {
    String outputType = 'main',
    int sourceIndex = 0,
    int targetIndex = 0,
  }) {
    // Ensure source node has connection map
    _connections.putIfAbsent(sourceNodeName, () => {});
    _connections[sourceNodeName]!.putIfAbsent(outputType, () => [[]]);

    // Ensure the output index exists
    while (_connections[sourceNodeName]![outputType]!.length <= sourceIndex) {
      _connections[sourceNodeName]![outputType]!.add([]);
    }

    // Add connection
    _connections[sourceNodeName]![outputType]![sourceIndex].add(
      NodeConnection(
        node: targetNodeName,
        index: targetIndex,
      ),
    );

    return this;
  }

  /// Connect nodes in sequence
  WorkflowBuilder connectSequence(List<String> nodeNames) {
    for (var i = 0; i < nodeNames.length - 1; i++) {
      connect(nodeNames[i], nodeNames[i + 1]);
    }
    return this;
  }

  /// Reset positioning (start new row)
  WorkflowBuilder newRow() {
    _currentX = 100;
    _currentY += _verticalSpacing;
    return this;
  }

  /// Set custom position for next node
  WorkflowBuilder position(double x, double y) {
    _currentX = x;
    _currentY = y;
    return this;
  }

  /// Build the workflow
  N8nWorkflow build() {
    return N8nWorkflow(
      name: _name,
      active: _active,
      version: _version,
      settings: _settings,
      nodes: _nodes,
      connections: _connections,
      tags: _tags.isEmpty ? null : _tags,
      staticData: _staticData,
    );
  }

  /// Build and return JSON string
  String buildJson() {
    return build().toJson();
  }

  /// Build and save to file
  Future<void> buildAndSave(String filePath) async {
    final workflow = build();
    await workflow.saveToFile(filePath);
  }

  /// Create a new builder instance
  static WorkflowBuilder create() => WorkflowBuilder();
}

/// Extension methods for WorkflowBuilder
extension WorkflowBuilderExtensions on WorkflowBuilder {
  /// Add webhook trigger node
  WorkflowBuilder webhookTrigger({
    required String name,
    required String path,
    String method = 'POST',
    String authentication = 'none',
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'path': path,
      'method': method,
      'authentication': authentication,
    };

    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.webhook',
      parameters: params,
    );
  }

  /// Add HTTP Request node
  WorkflowBuilder httpRequest({
    required String name,
    required String url,
    String method = 'GET',
    Map<String, dynamic>? headers,
    dynamic body,
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'url': url,
      'method': method,
    };

    if (headers != null) {
      params['headers'] = headers;
    }
    if (body != null) {
      params['body'] = body;
    }
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.httpRequest',
      parameters: params,
    );
  }

  /// Add PostgreSQL node
  WorkflowBuilder postgres({
    required String name,
    required String operation,
    String? table,
    String? query,
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'operation': operation,
    };

    if (table != null) params['table'] = table;
    if (query != null) params['query'] = query;
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.postgres',
      parameters: params,
      credentials: {'postgres': {'id': 'credential_id', 'name': 'PostgreSQL'}},
    );
  }

  /// Add Email Send node
  WorkflowBuilder emailSend({
    required String name,
    required String fromEmail,
    required String toEmail,
    required String subject,
    String? message,
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'fromEmail': fromEmail,
      'toEmail': toEmail,
      'subject': subject,
    };

    if (message != null) params['message'] = message;
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.emailSend',
      parameters: params,
    );
  }

  /// Add Function node
  WorkflowBuilder function({
    required String name,
    required String code,
  }) {
    return node(
      name: name,
      type: 'n8n-nodes-base.function',
      parameters: {'functionCode': code},
    );
  }

  /// Add IF node (conditional logic)
  WorkflowBuilder ifNode({
    required String name,
    required List<Map<String, dynamic>> conditions,
  }) {
    return node(
      name: name,
      type: 'n8n-nodes-base.if',
      parameters: {'conditions': conditions},
    );
  }

  /// Add Set node (data transformation)
  WorkflowBuilder setNode({
    required String name,
    required Map<String, dynamic> values,
  }) {
    return node(
      name: name,
      type: 'n8n-nodes-base.set',
      parameters: {'values': values},
    );
  }

  /// Add Wait node
  WorkflowBuilder waitNode({
    required String name,
    String waitType = 'webhook',
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'resume': waitType,
    };

    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.wait',
      parameters: params,
    );
  }

  /// Add Respond to Webhook node
  WorkflowBuilder respondToWebhook({
    required String name,
    int responseCode = 200,
    Map<String, dynamic>? responseBody,
  }) {
    final params = <String, dynamic>{
      'respondWith': 'json',
      'responseCode': responseCode,
    };

    if (responseBody != null) {
      params['responseBody'] = responseBody;
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.respondToWebhook',
      parameters: params,
    );
  }

  /// Add Slack node
  WorkflowBuilder slack({
    required String name,
    required String channel,
    required String text,
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'channel': channel,
      'text': text,
    };

    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.slack',
      parameters: params,
      credentials: {'slackApi': {'id': 'credential_id', 'name': 'Slack'}},
    );
  }

  /// Add Stripe node
  WorkflowBuilder stripe({
    required String name,
    required String resource,
    required String operation,
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'resource': resource,
      'operation': operation,
    };

    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.stripe',
      parameters: params,
      credentials: {'stripeApi': {'id': 'credential_id', 'name': 'Stripe'}},
    );
  }

  /// Add Google Sheets node
  WorkflowBuilder googleSheets({
    required String name,
    required String operation,
    String? spreadsheetId,
    String? sheetName,
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'operation': operation,
    };

    if (spreadsheetId != null) params['spreadsheetId'] = spreadsheetId;
    if (sheetName != null) params['sheetName'] = sheetName;
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.googleSheets',
      parameters: params,
      credentials: {
        'googleSheetsOAuth2Api': {
          'id': 'credential_id',
          'name': 'Google Sheets'
        }
      },
    );
  }

  /// Add MongoDB node
  WorkflowBuilder mongodb({
    required String name,
    required String operation,
    String? collection,
    Map<String, dynamic>? query,
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'operation': operation,
    };

    if (collection != null) params['collection'] = collection;
    if (query != null) params['query'] = query;
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.mongodb',
      parameters: params,
      credentials: {'mongoDB': {'id': 'credential_id', 'name': 'MongoDB'}},
    );
  }

  /// Add AWS S3 node
  WorkflowBuilder awsS3({
    required String name,
    required String operation,
    String? bucketName,
    String? fileName,
    Map<String, dynamic>? additionalParams,
  }) {
    final params = <String, dynamic>{
      'operation': operation,
    };

    if (bucketName != null) params['bucketName'] = bucketName;
    if (fileName != null) params['fileName'] = fileName;
    if (additionalParams != null) {
      params.addAll(additionalParams);
    }

    return node(
      name: name,
      type: 'n8n-nodes-base.awsS3',
      parameters: params,
      credentials: {'aws': {'id': 'credential_id', 'name': 'AWS'}},
    );
  }
}
