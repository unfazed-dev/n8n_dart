/// Test workflow metadata and documentation
///
/// This file documents the required n8n workflows for integration testing.
/// These workflows must be created manually on your n8n cloud instance
/// (https://kinly.app.n8n.cloud) before running integration tests.
///
/// See test/integration/docs/WORKFLOW_SETUP_GUIDE.md for step-by-step
/// instructions on creating these workflows.
library;

/// Metadata for a test workflow
class TestWorkflowMetadata {
  final String name;
  final String webhookId;
  final String description;
  final List<String> nodes;
  final Duration expectedDuration;
  final bool hasWaitNode;

  const TestWorkflowMetadata({
    required this.name,
    required this.webhookId,
    required this.description,
    required this.nodes,
    required this.expectedDuration,
    this.hasWaitNode = false,
  });
}

/// Test workflows required for integration testing
class TestWorkflows {
  /// Simple webhook workflow (no wait nodes)
  ///
  /// **Purpose:** Basic execution testing
  ///
  /// **Workflow Structure:**
  /// 1. Webhook Trigger (POST)
  /// 2. Set Node (transforms data)
  /// 3. Respond to Webhook (returns success)
  ///
  /// **Expected Response Time:** < 2 seconds
  ///
  /// **Test Coverage:**
  /// - Basic workflow execution
  /// - Webhook trigger
  /// - Immediate response
  /// - Status polling
  /// - Execution data retrieval
  ///
  /// **Setup Instructions:**
  /// 1. Create new workflow in n8n cloud
  /// 2. Add Webhook node with path: `/test/simple`
  /// 3. Add Set node to transform incoming data
  /// 4. Add Respond to Webhook node with success message
  /// 5. Activate workflow and copy webhook ID
  static const simple = TestWorkflowMetadata(
    name: 'Simple Test Workflow',
    webhookId: 'simple-test-webhook',
    description: 'Basic webhook workflow without wait nodes',
    nodes: ['Webhook', 'Set', 'Respond to Webhook'],
    expectedDuration: Duration(seconds: 2),
  );

  /// Wait node workflow (with form fields)
  ///
  /// **Purpose:** Interactive workflow testing
  ///
  /// **Workflow Structure:**
  /// 1. Webhook Trigger (POST)
  /// 2. Wait Node (waits for user input with form)
  /// 3. Set Node (processes form data)
  /// 4. Respond to Webhook (returns final result)
  ///
  /// **Expected Response Time:** Variable (waits for user input)
  ///
  /// **Form Fields:**
  /// - `name` (text) - Required
  /// - `email` (email) - Required
  /// - `age` (number) - Optional
  ///
  /// **Test Coverage:**
  /// - Wait node detection
  /// - Form field parsing
  /// - Workflow resumption
  /// - Multi-step workflow completion
  ///
  /// **Setup Instructions:**
  /// 1. Create new workflow in n8n cloud
  /// 2. Add Webhook node with path: `/test/wait-node`
  /// 3. Add Wait node configured with form fields (name, email, age)
  /// 4. Add Set node to process form submission
  /// 5. Add Respond to Webhook node
  /// 6. Activate workflow and copy webhook ID
  static const waitNode = TestWorkflowMetadata(
    name: 'Wait Node Test Workflow',
    webhookId: 'wait-node-test-webhook',
    description: 'Workflow with wait node and form fields',
    nodes: ['Webhook', 'Wait', 'Set', 'Respond to Webhook'],
    expectedDuration: Duration(minutes: 5),
    hasWaitNode: true,
  );

  /// Slow workflow (for timeout testing)
  ///
  /// **Purpose:** Timeout and polling behavior testing
  ///
  /// **Workflow Structure:**
  /// 1. Webhook Trigger (POST)
  /// 2. Function Node (with 10-second delay)
  /// 3. Set Node (transforms data)
  /// 4. Respond to Webhook (returns result)
  ///
  /// **Expected Response Time:** ~10 seconds
  ///
  /// **Test Coverage:**
  /// - Long-running workflow handling
  /// - Polling interval behavior
  /// - Timeout configuration
  /// - Status updates during execution
  ///
  /// **Setup Instructions:**
  /// 1. Create new workflow in n8n cloud
  /// 2. Add Webhook node with path: `/test/slow`
  /// 3. Add Function node with code: `await new Promise(r => setTimeout(r, 10000)); return items;`
  /// 4. Add Set node
  /// 5. Add Respond to Webhook node
  /// 6. Activate workflow and copy webhook ID
  static const slow = TestWorkflowMetadata(
    name: 'Slow Test Workflow',
    webhookId: 'slow-workflow-webhook',
    description: 'Workflow with intentional 10-second delay',
    nodes: ['Webhook', 'Function (delay)', 'Set', 'Respond to Webhook'],
    expectedDuration: Duration(seconds: 10),
  );

  /// Error workflow (intentionally fails)
  ///
  /// **Purpose:** Error handling and circuit breaker testing
  ///
  /// **Workflow Structure:**
  /// 1. Webhook Trigger (POST)
  /// 2. Function Node (throws error)
  ///
  /// **Expected Response Time:** < 1 second (immediate failure)
  ///
  /// **Test Coverage:**
  /// - Error detection
  /// - Circuit breaker behavior
  /// - Error recovery
  /// - Retry logic
  /// - Failed workflow status
  ///
  /// **Setup Instructions:**
  /// 1. Create new workflow in n8n cloud
  /// 2. Add Webhook node with path: `/test/error`
  /// 3. Add Function node with code: `throw new Error('Intentional test error');`
  /// 4. Activate workflow and copy webhook ID
  static const error = TestWorkflowMetadata(
    name: 'Error Test Workflow',
    webhookId: 'error-test-webhook',
    description: 'Workflow that intentionally throws an error',
    nodes: ['Webhook', 'Function (error)'],
    expectedDuration: Duration(seconds: 1),
  );

  /// Get all required test workflows
  static List<TestWorkflowMetadata> get all => [simple, waitNode, slow, error];

  /// Get workflows with wait nodes
  static List<TestWorkflowMetadata> get withWaitNodes =>
      all.where((w) => w.hasWaitNode).toList();

  /// Get workflows without wait nodes
  static List<TestWorkflowMetadata> get withoutWaitNodes =>
      all.where((w) => !w.hasWaitNode).toList();
}
