import '../models/workflow_models.dart';
import 'credential_manager.dart';

/// Injects real credentials from CredentialManager into workflow nodes
class WorkflowCredentialInjector {
  final CredentialManager credentialManager;

  const WorkflowCredentialInjector(this.credentialManager);

  /// Inject credentials into workflow nodes
  N8nWorkflow injectCredentials(N8nWorkflow workflow) {
    final updatedNodes = workflow.nodes.map((node) {
      if (node.credentials == null || node.credentials!.isEmpty) {
        return node;
      }

      // Check if node has placeholder credentials
      final hasPlaceholder = node.credentials!.values.any((credValue) {
        if (credValue is Map) {
          return credValue['id'] == 'credential_id';
        }
        return false;
      });

      if (!hasPlaceholder) {
        return node; // Already has real credentials
      }

      // Determine credential type from node type
      final credentialType = _getCredentialTypeFromNodeType(node.type);
      if (credentialType == null) {
        return node; // Unknown node type, keep as is
      }

      // Get real credential from manager
      final realCredential = credentialManager.getCredential(credentialType);

      // Create updated node with real credentials
      return WorkflowNode(
        id: node.id,
        name: node.name,
        type: node.type,
        position: node.position,
        parameters: node.parameters,
        credentials: realCredential,
      );
    }).toList();

    return N8nWorkflow(
      name: workflow.name,
      nodes: updatedNodes,
      connections: workflow.connections,
      tags: workflow.tags,
      active: workflow.active,
      settings: workflow.settings,
    );
  }

  /// Determine credential type from node type
  String? _getCredentialTypeFromNodeType(String nodeType) {
    // Map n8n node types to credential types
    final typeMap = {
      'n8n-nodes-base.postgres': 'postgres',
      'n8n-nodes-base.postgresTrigger': 'postgres',
      'n8n-nodes-base.supabase': 'supabase',
      'n8n-nodes-base.awsS3': 'aws',
      'n8n-nodes-base.slack': 'slack',
      'n8n-nodes-base.slackTrigger': 'slack',
      'n8n-nodes-base.stripe': 'stripe',
      'n8n-nodes-base.stripeTrigger': 'stripe',
      'n8n-nodes-base.emailSend': 'email',
      'n8n-nodes-base.emailReadImap': 'email',
      'n8n-nodes-base.mongoDB': 'mongodb',
    };

    return typeMap[nodeType];
  }

  /// Check if workflow has any placeholder credentials
  bool hasPlaceholderCredentials(N8nWorkflow workflow) {
    for (final node in workflow.nodes) {
      if (node.credentials != null) {
        for (final credValue in node.credentials!.values) {
          if (credValue is Map && credValue['id'] == 'credential_id') {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Get list of credential types needed by workflow
  Set<String> getRequiredCredentials(N8nWorkflow workflow) {
    final required = <String>{};

    for (final node in workflow.nodes) {
      final credType = _getCredentialTypeFromNodeType(node.type);
      if (credType != null && node.credentials != null) {
        required.add(credType);
      }
    }

    return required;
  }

  /// Validate that all required credentials are configured
  Map<String, bool> validateCredentials(N8nWorkflow workflow) {
    final required = getRequiredCredentials(workflow);
    final status = <String, bool>{};

    for (final credType in required) {
      final cred = credentialManager.getCredential(
        credType,
        usePlaceholder: false,
      );
      // If we got here without exception, credential is configured
      status[credType] = cred.values.first['id'] != 'credential_id';
    }

    return status;
  }
}
