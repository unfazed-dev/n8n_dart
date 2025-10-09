/// Template Validation Helpers
///
/// Utilities for validating workflow templates and their JSON structure
library;

import 'dart:convert';
import 'dart:io';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

/// Helper functions for template validation

/// Validate basic workflow structure
void validateWorkflowStructure(N8nWorkflow workflow) {
  expect(workflow.name, isNotEmpty, reason: 'Workflow name should not be empty');
  expect(workflow.nodes, isNotEmpty, reason: 'Workflow should have at least one node');
}

/// Validate workflow JSON structure
void validateWorkflowJson(Map<String, dynamic> json) {
  expect(json, containsPair('name', isNotEmpty));
  expect(json, containsPair('active', isA<bool>()));
  expect(json, containsPair('nodes', isA<List>()));
  expect(json, containsPair('connections', isA<Map>()));
  expect(json, containsPair('settings', isA<Map>()));
}

/// Validate node structure
void validateNode(Map<String, dynamic> node) {
  expect(node, containsPair('id', isNotEmpty));
  expect(node, containsPair('name', isNotEmpty));
  expect(node, containsPair('type', isNotEmpty));
  expect(node, containsPair('typeVersion', isA<int>()));
  expect(node, containsPair('position', isA<List>()));
  expect(node, containsPair('parameters', isA<Map>()));
}

/// Validate connections structure
void validateConnections(Map<String, dynamic> connections) {
  for (final entry in connections.entries) {
    final sourceNode = entry.key;
    final outputs = entry.value as Map<String, dynamic>;

    expect(sourceNode, isNotEmpty, reason: 'Source node name should not be empty');

    for (final outputEntry in outputs.entries) {
      final outputType = outputEntry.key;
      final connectionsList = outputEntry.value as List;

      expect(outputType, isNotEmpty, reason: 'Output type should not be empty');
      expect(connectionsList, isNotEmpty, reason: 'Connections list should not be empty');

      for (final conns in connectionsList) {
        expect(conns, isA<List>(), reason: 'Connections should be a list');

        for (final conn in conns as List) {
          expect(conn, containsPair('node', isNotEmpty));
          expect(conn, containsPair('type', isNotEmpty));
          expect(conn, containsPair('index', isA<int>()));
        }
      }
    }
  }
}

/// Count nodes by type
Map<String, int> countNodeTypes(N8nWorkflow workflow) {
  final counts = <String, int>{};

  for (final node in workflow.nodes) {
    counts[node.type] = (counts[node.type] ?? 0) + 1;
  }

  return counts;
}

/// Check if workflow has specific node type
bool hasNodeType(N8nWorkflow workflow, String nodeType) {
  return workflow.nodes.any((node) => node.type == nodeType);
}

/// Check if workflow has webhook trigger
bool hasWebhookTrigger(N8nWorkflow workflow) {
  return hasNodeType(workflow, 'n8n-nodes-base.webhook');
}

/// Check if workflow has wait node
bool hasWaitNode(N8nWorkflow workflow) {
  return hasNodeType(workflow, 'n8n-nodes-base.wait');
}

/// Check if workflow has database node
bool hasDatabaseNode(N8nWorkflow workflow) {
  return hasNodeType(workflow, 'n8n-nodes-base.postgres') ||
      hasNodeType(workflow, 'n8n-nodes-base.mysql') ||
      hasNodeType(workflow, 'n8n-nodes-base.mongodb');
}

/// Save workflow to JSON file
Future<void> saveWorkflowToFile(
  N8nWorkflow workflow,
  String filename,
) async {
  final file = File('test/generated_workflows/$filename');
  await workflow.saveToFile(file.path);
}

/// Load workflow from JSON file
Future<N8nWorkflow> loadWorkflowFromFile(String filename) async {
  final file = File('test/generated_workflows/$filename');
  final content = await file.readAsString();
  return N8nWorkflow.fromJson(content);
}

/// Validate JSON export/import roundtrip
Future<void> validateRoundtrip(N8nWorkflow workflow) async {
  // Export to JSON
  final json1 = workflow.toJson();
  final map1 = jsonDecode(json1) as Map<String, dynamic>;

  // Import from JSON
  final imported = N8nWorkflow.fromJson(json1);

  // Export again
  final json2 = imported.toJson();
  final map2 = jsonDecode(json2) as Map<String, dynamic>;

  // Compare critical fields
  expect(map2['name'], equals(map1['name']));
  expect(map2['active'], equals(map1['active']));
  expect((map2['nodes'] as List).length, equals((map1['nodes'] as List).length));

  // Validate connections match
  final conn1 = map1['connections'] as Map<String, dynamic>;
  final conn2 = map2['connections'] as Map<String, dynamic>;
  expect(conn2.keys.length, equals(conn1.keys.length));
}

/// Template test helper class
class TemplateTestHelper {
  final N8nWorkflow workflow;
  final Map<String, dynamic> json;

  TemplateTestHelper(this.workflow)
      : json = jsonDecode(workflow.toJson()) as Map<String, dynamic>;

  /// Validate complete template structure
  void validateComplete() {
    validateWorkflowStructure(workflow);
    validateWorkflowJson(json);

    // Validate all nodes
    final nodes = json['nodes'] as List;
    for (final node in nodes) {
      validateNode(node as Map<String, dynamic>);
    }

    // Validate connections
    final connections = json['connections'] as Map<String, dynamic>;
    validateConnections(connections);
  }

  /// Get node count
  int get nodeCount => workflow.nodes.length;

  /// Get connection count
  int get connectionCount {
    var count = 0;
    final connections = json['connections'] as Map<String, dynamic>;

    for (final outputs in connections.values) {
      for (final connectionsList in (outputs as Map<String, dynamic>).values) {
        for (final conns in connectionsList as List) {
          count += (conns as List).length;
        }
      }
    }

    return count;
  }

  /// Check if template has minimum node count
  void expectMinimumNodes(int minimum) {
    expect(
      nodeCount,
      greaterThanOrEqualTo(minimum),
      reason: 'Template should have at least $minimum nodes',
    );
  }

  /// Check if template has connections
  void expectHasConnections() {
    expect(
      connectionCount,
      greaterThan(0),
      reason: 'Template should have at least one connection',
    );
  }

  /// Validate and save template
  Future<void> validateAndSave(String filename) async {
    validateComplete();
    await saveWorkflowToFile(workflow, filename);
  }
}

/// Create template test helper
TemplateTestHelper createTemplateHelper(N8nWorkflow workflow) {
  return TemplateTestHelper(workflow);
}

/// Assertions for template validation

class TemplateAssertions {
  /// Assert workflow has expected name pattern
  static void assertNameMatches(N8nWorkflow workflow, Pattern pattern) {
    expect(
      workflow.name,
      matches(pattern),
      reason: 'Workflow name should match pattern $pattern',
    );
  }

  /// Assert workflow has expected tags
  static void assertHasTags(N8nWorkflow workflow, List<String> expectedTags) {
    expect(workflow.tags, isNotNull, reason: 'Workflow should have tags');

    for (final tag in expectedTags) {
      expect(
        workflow.tags!.contains(tag),
        isTrue,
        reason: 'Workflow should have tag: $tag',
      );
    }
  }

  /// Assert workflow has specific number of nodes
  static void assertNodeCount(N8nWorkflow workflow, int expected) {
    expect(
      workflow.nodes.length,
      equals(expected),
      reason: 'Workflow should have exactly $expected nodes',
    );
  }

  /// Assert workflow has node with name
  static void assertHasNodeNamed(N8nWorkflow workflow, String nodeName) {
    expect(
      workflow.nodes.any((n) => n.name == nodeName),
      isTrue,
      reason: 'Workflow should have node named: $nodeName',
    );
  }

  /// Assert workflow has connection between nodes
  static void assertHasConnection(
    N8nWorkflow workflow,
    String sourceName,
    String targetName,
  ) {
    final connections = workflow.connections[sourceName];
    expect(
      connections,
      isNotNull,
      reason: 'Source node $sourceName should have connections',
    );

    var found = false;
    for (final outputs in connections!.values) {
      for (final conns in outputs) {
        if (conns.any((c) => c.node == targetName)) {
          found = true;
          break;
        }
      }
    }

    expect(
      found,
      isTrue,
      reason: 'Should have connection from $sourceName to $targetName',
    );
  }

  /// Assert all nodes have valid positions
  static void assertAllNodesHavePositions(N8nWorkflow workflow) {
    for (final node in workflow.nodes) {
      expect(node.position.x, greaterThanOrEqualTo(0));
      expect(node.position.y, greaterThanOrEqualTo(0));
    }
  }

  /// Assert workflow JSON is valid
  static void assertValidJson(String json) {
    expect(
      () => jsonDecode(json),
      returnsNormally,
      reason: 'JSON should be valid',
    );

    final map = jsonDecode(json) as Map<String, dynamic>;
    validateWorkflowJson(map);
  }
}
