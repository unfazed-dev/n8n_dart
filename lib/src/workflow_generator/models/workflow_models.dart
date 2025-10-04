/// n8n Workflow JSON Generator Models
///
/// This file contains models for programmatically generating n8n workflow JSON files
/// that can be imported directly into n8n platform.
library;

import 'dart:convert';
import 'dart:io';

/// Represents a position in the n8n workflow canvas
class NodePosition {
  final double x;
  final double y;

  const NodePosition(this.x, this.y);

  List<double> toJson() => [x, y];
}

/// Represents a connection between two nodes
class NodeConnection {
  final String node;
  final String type;
  final int index;

  const NodeConnection({
    required this.node,
    this.type = 'main',
    this.index = 0,
  });

  Map<String, dynamic> toJson() => {
        'node': node,
        'type': type,
        'index': index,
      };
}

/// Represents a node in the workflow
class WorkflowNode {
  final String id;
  final String name;
  final String type;
  final int typeVersion;
  final NodePosition position;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic>? credentials;
  final bool? disabled;
  final bool? alwaysOutputData;
  final String? notes;
  final String? notesInFlow;

  WorkflowNode({
    required this.name, required this.type, required this.position, String? id,
    this.typeVersion = 1,
    this.parameters = const {},
    this.credentials,
    this.disabled,
    this.alwaysOutputData,
    this.notes,
    this.notesInFlow,
  }) : id = id ?? _generateNodeId();

  static int _idCounter = 0;

  static String _generateNodeId() {
    _idCounter++;
    return '${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'type': type,
      'typeVersion': typeVersion,
      'position': position.toJson(),
      'parameters': parameters,
    };

    if (credentials != null) json['credentials'] = credentials;
    if (disabled != null) json['disabled'] = disabled;
    if (alwaysOutputData != null) {
      json['alwaysOutputData'] = alwaysOutputData;
    }
    if (notes != null) json['notes'] = notes;
    if (notesInFlow != null) json['notesInFlow'] = notesInFlow;

    return json;
  }
}

/// Represents workflow settings
class WorkflowSettings {
  final String executionMode;
  final String timezone;
  final int? executionTimeout;
  final bool? saveExecutionProgress;
  final bool? saveManualExecutions;
  final bool? saveDataErrorExecution;
  final bool? saveDataSuccessExecution;

  const WorkflowSettings({
    this.executionMode = 'sequential',
    this.timezone = 'UTC',
    this.executionTimeout,
    this.saveExecutionProgress,
    this.saveManualExecutions,
    this.saveDataErrorExecution,
    this.saveDataSuccessExecution,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'executionMode': executionMode,
      'timezone': timezone,
    };

    if (executionTimeout != null) json['executionTimeout'] = executionTimeout;
    if (saveExecutionProgress != null) {
      json['saveExecutionProgress'] = saveExecutionProgress;
    }
    if (saveManualExecutions != null) {
      json['saveManualExecutions'] = saveManualExecutions;
    }
    if (saveDataErrorExecution != null) {
      json['saveDataErrorExecution'] = saveDataErrorExecution;
    }
    if (saveDataSuccessExecution != null) {
      json['saveDataSuccessExecution'] = saveDataSuccessExecution;
    }

    return json;
  }
}

/// Represents a complete n8n workflow
class N8nWorkflow {
  final String? id;
  final String name;
  final bool active;
  final double version;
  final WorkflowSettings settings;
  final List<WorkflowNode> nodes;
  final Map<String, Map<String, List<List<NodeConnection>>>> connections;
  final List<String>? tags;
  final Map<String, dynamic>? staticData;
  final String? pinData;

  const N8nWorkflow({
    required this.name, required this.nodes, required this.connections, this.id,
    this.active = false,
    this.version = 1.0,
    this.settings = const WorkflowSettings(),
    this.tags,
    this.staticData,
    this.pinData,
  });

  /// Convert workflow to JSON string
  String toJson() {
    final json = _toJsonMap();
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  /// Convert workflow to JSON Map
  Map<String, dynamic> _toJsonMap() {
    final json = <String, dynamic>{
      'name': name,
      'active': active,
      'version': version,
      'nodes': nodes.map((node) => node.toJson()).toList(),
      'connections': _connectionsToJson(),
      'settings': settings.toJson(),
    };

    if (id != null) json['id'] = id;
    if (tags != null && tags!.isNotEmpty) json['tags'] = tags;
    if (staticData != null) json['staticData'] = staticData;
    if (pinData != null) json['pinData'] = pinData;

    return json;
  }

  Map<String, dynamic> _connectionsToJson() {
    final result = <String, dynamic>{};

    connections.forEach((sourceNode, outputs) {
      final outputsJson = <String, dynamic>{};

      outputs.forEach((outputType, connectionsList) {
        outputsJson[outputType] = connectionsList
            .map((conns) => conns.map((conn) => conn.toJson()).toList())
            .toList();
      });

      result[sourceNode] = outputsJson;
    });

    return result;
  }

  /// Save workflow to file
  Future<void> saveToFile(String filePath) async {
    final file = File(filePath);
    await file.writeAsString(toJson());
  }

  /// Create workflow from JSON string
  static N8nWorkflow fromJson(String jsonString) {
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return fromJsonMap(json);
  }

  /// Create workflow from JSON Map
  static N8nWorkflow fromJsonMap(Map<String, dynamic> json) {
    // Parse nodes
    final nodesList = (json['nodes'] as List)
        .map((nodeJson) => WorkflowNode(
              id: nodeJson['id'],
              name: nodeJson['name'],
              type: nodeJson['type'],
              typeVersion: nodeJson['typeVersion'] ?? 1,
              position: NodePosition(
                (nodeJson['position'][0] as num).toDouble(),
                (nodeJson['position'][1] as num).toDouble(),
              ),
              parameters:
                  Map<String, dynamic>.from(nodeJson['parameters'] ?? {}),
              credentials: nodeJson['credentials'] != null
                  ? Map<String, dynamic>.from(nodeJson['credentials'])
                  : null,
              disabled: nodeJson['disabled'],
              alwaysOutputData: nodeJson['alwaysOutputData'],
              notes: nodeJson['notes'],
              notesInFlow: nodeJson['notesInFlow'],
            ))
        .toList();

    // Parse connections
    final connectionsMap = <String,
        Map<String, List<List<NodeConnection>>>>{};

    final connectionsJson = json['connections'] as Map<String, dynamic>?;
    if (connectionsJson != null) {
      connectionsJson.forEach((sourceNode, outputs) {
        final outputsMap = <String, List<List<NodeConnection>>>{};

        (outputs as Map<String, dynamic>).forEach((outputType, connsList) {
          final connectionsList = (connsList as List)
              .map((conns) => (conns as List)
                  .map((conn) => NodeConnection(
                        node: conn['node'],
                        type: conn['type'] ?? 'main',
                        index: conn['index'] ?? 0,
                      ))
                  .toList())
              .toList();

          outputsMap[outputType] = connectionsList;
        });

        connectionsMap[sourceNode] = outputsMap;
      });
    }

    return N8nWorkflow(
      id: json['id'],
      name: json['name'],
      active: json['active'] ?? false,
      version: (json['version'] ?? 1.0).toDouble(),
      settings: WorkflowSettings(
        executionMode: json['settings']?['executionMode'] ?? 'sequential',
        timezone: json['settings']?['timezone'] ?? 'UTC',
      ),
      nodes: nodesList,
      connections: connectionsMap,
      tags: (json['tags'] as List?)?.cast<String>(),
      staticData: json['staticData'],
      pinData: json['pinData'],
    );
  }
}
