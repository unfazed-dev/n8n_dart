/// Reactive Workflow Builder with real-time validation
///
/// Provides a reactive interface for building n8n workflows with:
/// - Live validation streams
/// - Real-time workflow updates
/// - Debounced workflow building
/// - Multi-subscriber support with shareReplay
library;

import 'package:rxdart/rxdart.dart';

import 'models/workflow_models.dart';

/// Live workflow builder with validation stream
///
/// Features:
/// - BehaviorSubject for nodes and validation state
/// - Debounced workflow building (300ms)
/// - Reactive validation on every change
/// - shareReplay for efficient multi-subscriber support
class ReactiveWorkflowBuilder {
  final BehaviorSubject<List<WorkflowNode>> _nodes$ =
      BehaviorSubject.seeded([]);
  final BehaviorSubject<List<String>> _validationErrors$ =
      BehaviorSubject.seeded([]);
  final BehaviorSubject<Map<String, List<NodeConnection>>> _connections$ =
      BehaviorSubject.seeded({});

  String _workflowName = 'Untitled Workflow';
  bool _isActive = false;
  final List<String> _tags = [];

  /// Stream of current nodes
  Stream<List<WorkflowNode>> get nodes$ => _nodes$.stream;

  /// Stream of validation errors
  Stream<List<String>> get validationErrors$ => _validationErrors$.stream;

  /// Stream of connections
  Stream<Map<String, List<NodeConnection>>> get connections$ =>
      _connections$.stream;

  /// Stream of valid workflow state (true if no errors)
  Stream<bool> get isValid$ =>
      _validationErrors$.stream.map((errors) => errors.isEmpty);

  /// Stream of node count
  Stream<int> get nodeCount$ => _nodes$.stream.map((nodes) => nodes.length);

  /// Stream of built workflow (updates on any change)
  ///
  /// - Debounces changes by 300ms to avoid excessive rebuilding
  /// - Uses shareReplay to cache last emission for new subscribers
  /// - Only emits when workflow is valid
  Stream<N8nWorkflow> get workflow$ => Rx.combineLatest3<List<WorkflowNode>,
          Map<String, List<NodeConnection>>, List<String>, N8nWorkflow>(
        _nodes$.stream,
        _connections$.stream,
        _validationErrors$.stream,
        (nodes, connections, errors) {
          if (errors.isNotEmpty) {
            throw WorkflowValidationException(errors);
          }
          return _buildWorkflow(nodes, connections);
        },
      ).debounceTime(const Duration(milliseconds: 300)).shareReplay(maxSize: 1);

  /// Stream of workflow metadata (name, active status, tags)
  Stream<WorkflowMetadata> get metadata$ => Stream.value(WorkflowMetadata(
        name: _workflowName,
        active: _isActive,
        tags: List.unmodifiable(_tags),
      ));

  /// Set workflow name
  void setName(String name) {
    _workflowName = name;
  }

  /// Set active status
  void setActive(bool active) {
    _isActive = active;
  }

  /// Add tag
  void addTag(String tag) {
    if (!_tags.contains(tag)) {
      _tags.add(tag);
    }
  }

  /// Remove tag
  void removeTag(String tag) {
    _tags.remove(tag);
  }

  /// Add node with reactive validation
  void addNode(WorkflowNode node) {
    final current = _nodes$.value;

    // Check for duplicate node name
    if (current.any((n) => n.name == node.name)) {
      _validationErrors$.add([
        ..._validationErrors$.value,
        'Duplicate node name: ${node.name}'
      ]);
      return;
    }

    _nodes$.add([...current, node]);
    _validate();
  }

  /// Remove node
  void removeNode(String nodeName) {
    final current = _nodes$.value;
    _nodes$.add(current.where((n) => n.name != nodeName).toList());

    // Remove connections involving this node
    final currentConnections = _connections$.value;
    final updatedConnections = Map<String, List<NodeConnection>>.from(currentConnections);
    updatedConnections.remove(nodeName);

    // Remove connections TO this node
    for (final key in updatedConnections.keys) {
      updatedConnections[key] = updatedConnections[key]!
          .where((conn) => conn.node != nodeName)
          .toList();
    }

    _connections$.add(updatedConnections);
    _validate();
  }

  /// Update node
  void updateNode(String nodeName, WorkflowNode updated) {
    final nodes = _nodes$.value;
    final index = nodes.indexWhere((n) => n.name == nodeName);

    if (index != -1) {
      final updatedNodes = List<WorkflowNode>.from(nodes);
      updatedNodes[index] = updated;
      _nodes$.add(updatedNodes);
      _validate();
    } else {
      _validationErrors$.add([
        ..._validationErrors$.value,
        'Node not found: $nodeName'
      ]);
    }
  }

  /// Connect two nodes
  void connect({
    required String fromNode,
    required String toNode,
    String fromOutput = 'main',
    String toInput = 'main',
    int fromOutputIndex = 0,
    int toInputIndex = 0,
  }) {
    final nodes = _nodes$.value;

    // Validate nodes exist
    if (!nodes.any((n) => n.name == fromNode)) {
      _validationErrors$.add([
        ..._validationErrors$.value,
        'Source node not found: $fromNode'
      ]);
      return;
    }

    if (!nodes.any((n) => n.name == toNode)) {
      _validationErrors$.add([
        ..._validationErrors$.value,
        'Target node not found: $toNode'
      ]);
      return;
    }

    final connection = NodeConnection(
      node: toNode,
      type: toInput,
      index: toInputIndex,
    );

    final current = _connections$.value;
    final updated = Map<String, List<NodeConnection>>.from(current);
    final key = '$fromNode-$fromOutput-$fromOutputIndex';

    if (!updated.containsKey(key)) {
      updated[key] = [];
    }

    updated[key]!.add(connection);
    _connections$.add(updated);
    _validate();
  }

  /// Disconnect nodes
  void disconnect({
    required String fromNode,
    required String toNode,
  }) {
    final current = _connections$.value;
    final updated = Map<String, List<NodeConnection>>.from(current);

    for (final key in updated.keys.toList()) {
      if (key.startsWith('$fromNode-')) {
        updated[key] = updated[key]!.where((conn) => conn.node != toNode).toList();
        if (updated[key]!.isEmpty) {
          updated.remove(key);
        }
      }
    }

    _connections$.add(updated);
    _validate();
  }

  /// Clear all nodes and connections
  void clear() {
    _nodes$.add([]);
    _connections$.add({});
    _validationErrors$.add([]);
  }

  /// Reactive validation
  ///
  /// Validates:
  /// - At least one node exists
  /// - No disconnected nodes (except trigger nodes)
  /// - No duplicate node names
  /// - All connections reference existing nodes
  /// - At least one trigger/webhook node exists
  void _validate() {
    final errors = <String>[];
    final nodes = _nodes$.value;
    final connections = _connections$.value;

    if (nodes.isEmpty) {
      errors.add('Workflow must have at least one node');
      _validationErrors$.add(errors);
      return;
    }

    // Check for duplicate node names (should be caught earlier, but double-check)
    final nodeNames = nodes.map((n) => n.name).toList();
    final uniqueNames = nodeNames.toSet();
    if (nodeNames.length != uniqueNames.length) {
      errors.add('Duplicate node names found');
    }

    // Check for at least one trigger/webhook node
    final hasTrigger = nodes.any((node) =>
        node.type.contains('Trigger') ||
        node.type.contains('Webhook') ||
        node.type == 'n8n-nodes-base.webhook');

    if (!hasTrigger) {
      errors.add('Workflow must have at least one trigger or webhook node');
    }

    // Check for disconnected nodes (nodes with no incoming or outgoing connections)
    // Trigger nodes don't need incoming connections
    for (final node in nodes) {
      final isTrigger = node.type.contains('Trigger') ||
          node.type.contains('Webhook') ||
          node.type == 'n8n-nodes-base.webhook';

      final hasOutgoing = connections.keys.any((key) => key.startsWith('${node.name}-'));
      final hasIncoming = connections.values.any(
        (connList) => connList.any((conn) => conn.node == node.name),
      );

      if (!isTrigger && !hasIncoming && nodes.length > 1) {
        errors.add('Node "${node.name}" has no incoming connections');
      }

      if (!hasOutgoing && nodes.length > 1) {
        // Check if it's a terminal node (like Respond to Webhook)
        final isTerminal = node.type == 'n8n-nodes-base.respondToWebhook' ||
            node.type.contains('Respond');

        if (!isTerminal) {
          errors.add('Node "${node.name}" has no outgoing connections');
        }
      }
    }

    // Validate all connections reference existing nodes
    for (final entry in connections.entries) {
      final fromNode = entry.key.split('-')[0];
      if (!nodes.any((n) => n.name == fromNode)) {
        errors.add('Connection references non-existent source node: $fromNode');
      }

      for (final conn in entry.value) {
        if (!nodes.any((n) => n.name == conn.node)) {
          errors.add('Connection references non-existent target node: ${conn.node}');
        }
      }
    }

    _validationErrors$.add(errors);
  }

  /// Build workflow from current nodes and connections
  N8nWorkflow _buildWorkflow(
    List<WorkflowNode> nodes,
    Map<String, List<NodeConnection>> connections,
  ) {
    // Convert flat connection map to n8n format
    final n8nConnections = <String, Map<String, List<List<NodeConnection>>>>{};

    for (final entry in connections.entries) {
      final parts = entry.key.split('-');
      final nodeName = parts[0];
      final outputType = parts.length > 1 ? parts[1] : 'main';
      final outputIndex = parts.length > 2 ? int.parse(parts[2]) : 0;

      if (!n8nConnections.containsKey(nodeName)) {
        n8nConnections[nodeName] = {};
      }

      if (!n8nConnections[nodeName]!.containsKey(outputType)) {
        n8nConnections[nodeName]![outputType] = [];
      }

      while (n8nConnections[nodeName]![outputType]!.length <= outputIndex) {
        n8nConnections[nodeName]![outputType]!.add([]);
      }

      n8nConnections[nodeName]![outputType]![outputIndex].addAll(entry.value);
    }

    return N8nWorkflow(
      name: _workflowName,
      nodes: nodes,
      connections: n8nConnections,
      active: _isActive,
      tags: _tags,
    );
  }

  /// Dispose all resources
  void dispose() {
    _nodes$.close();
    _validationErrors$.close();
    _connections$.close();
  }
}

/// Workflow metadata
class WorkflowMetadata {
  final String name;
  final bool active;
  final List<String> tags;

  const WorkflowMetadata({
    required this.name,
    required this.active,
    required this.tags,
  });
}

/// Exception thrown when workflow validation fails
class WorkflowValidationException implements Exception {
  final List<String> errors;

  const WorkflowValidationException(this.errors);

  @override
  String toString() => 'WorkflowValidationException: ${errors.join(', ')}';
}
