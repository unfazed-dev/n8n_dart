# n8n Workflow Generator Guide

**Version:** 1.0
**Date:** October 3, 2025

---

## 📖 Table of Contents

1. [Introduction](#introduction)
2. [Why Generate Workflows Programmatically?](#why-generate-workflows-programmatically)
3. [Getting Started](#getting-started)
4. [Core Concepts](#core-concepts)
5. [WorkflowBuilder API](#workflowbuilder-api)
6. [Common Node Types](#common-node-types)
7. [Pre-built Templates](#pre-built-templates)
8. [Advanced Patterns](#advanced-patterns)
9. [Best Practices](#best-practices)
10. [Examples](#examples)

---

## 🎯 Introduction

The n8n_dart Workflow Generator allows you to **programmatically create n8n workflow JSON files** using Dart code instead of building them manually in the n8n UI.

### What You Can Do

- ✅ Generate n8n workflows from Dart code
- ✅ Use fluent API for building complex workflows
- ✅ Leverage pre-built templates for common use cases
- ✅ Version control your workflows in Git
- ✅ Automate workflow creation for multi-tenant systems
- ✅ Generate workflows from user input or configuration
- ✅ Export to JSON and import into any n8n instance

---

## 💡 Why Generate Workflows Programmatically?

### 1. **Version Control**
```dart
// Workflows as code = Git history, PRs, code review
final workflow = WorkflowBuilder.create()
  .name('User Registration')
  .webhookTrigger(name: 'Register', path: 'auth/register')
  .postgres(name: 'Save User', operation: 'insert', table: 'users')
  .build();
```

### 2. **Template Reusability**
```dart
// Create 100 similar workflows with different configs
for (var tenant in tenants) {
  final workflow = WorkflowTemplates.crudApi(
    resourceName: tenant.resource,
    tableName: tenant.table,
  );
  await workflow.saveToFile('workflows/${tenant.id}.json');
}
```

### 3. **Dynamic Generation**
```dart
// Generate workflows based on user configuration
final userConfig = await loadUserConfig();
final workflow = buildCustomWorkflow(userConfig);
```

### 4. **Consistency**
```dart
// Ensure all workflows follow the same patterns
final workflow = WorkflowBuilder.create()
  .name('Process Order')
  .tags(['ecommerce', 'production']) // Always tagged
  .webhookTrigger(name: 'Webhook', path: 'orders')
  // ... rest of workflow
```

---

## 🚀 Getting Started

### Installation

The workflow generator is included in the n8n_dart package:

```yaml
dependencies:
  n8n_dart: ^1.0.0
```

### Basic Example

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  // Create a simple workflow
  final workflow = WorkflowBuilder.create()
      .name('My First Generated Workflow')
      .tags(['example'])
      .webhookTrigger(
        name: 'Webhook Trigger',
        path: 'test-webhook',
        method: 'POST',
      )
      .respondToWebhook(
        name: 'Send Response',
        responseCode: 200,
        responseBody: {'message': 'Hello from n8n!'},
      )
      .connect('Webhook Trigger', 'Send Response')
      .build();

  // Save to file
  await workflow.saveToFile('my_workflow.json');

  // Or get JSON string
  print(workflow.toJson());
}
```

### Import into n8n

1. Open n8n UI
2. Click **"..."** menu → **Import from File**
3. Select the generated JSON file
4. Configure credentials (if needed)
5. **Activate** the workflow

---

## 🧩 Core Concepts

### 1. **Workflow**

A complete n8n workflow with nodes, connections, and settings.

```dart
final workflow = N8nWorkflow(
  name: 'My Workflow',
  active: false,
  nodes: [...],
  connections: {...},
  settings: WorkflowSettings(),
);
```

### 2. **Nodes**

Individual steps in the workflow (trigger, action, logic).

```dart
final node = WorkflowNode(
  name: 'Webhook Trigger',
  type: 'n8n-nodes-base.webhook',
  position: NodePosition(100, 200),
  parameters: {
    'path': 'my-webhook',
    'method': 'POST',
  },
);
```

### 3. **Connections**

Links between nodes that define data flow.

```dart
// Connect "Webhook Trigger" to "Process Data"
builder.connect('Webhook Trigger', 'Process Data');
```

### 4. **WorkflowBuilder**

Fluent API for building workflows step-by-step.

```dart
final workflow = WorkflowBuilder.create()
  .name('My Workflow')
  .webhookTrigger(...)
  .postgres(...)
  .connect(...)
  .build();
```

---

## 🔨 WorkflowBuilder API

### Basic Methods

#### `name(String name)`
Set the workflow name.

```dart
builder.name('Customer Registration');
```

#### `active([bool isActive])`
Set workflow as active/inactive.

```dart
builder.active(true); // Active
builder.active(false); // Inactive (default)
```

#### `tags(List<String> tags)`
Add tags to the workflow.

```dart
builder.tags(['production', 'api', 'users']);
```

#### `settings(WorkflowSettings settings)`
Configure workflow settings.

```dart
builder.settings(WorkflowSettings(
  executionMode: 'sequential',
  timezone: 'America/New_York',
  executionTimeout: 3600,
));
```

### Node Methods

#### `webhookTrigger()`
Add a webhook trigger node.

```dart
builder.webhookTrigger(
  name: 'Webhook',
  path: 'users/create',
  method: 'POST',
  authentication: 'headerAuth',
);
```

#### `httpRequest()`
Add an HTTP request node.

```dart
builder.httpRequest(
  name: 'Call External API',
  url: 'https://api.example.com/data',
  method: 'GET',
  headers: {'Authorization': 'Bearer {{$json.token}}'},
);
```

#### `postgres()`
Add a PostgreSQL database node.

```dart
builder.postgres(
  name: 'Save to Database',
  operation: 'insert',
  table: 'customers',
);
```

#### `emailSend()`
Add an email sending node.

```dart
builder.emailSend(
  name: 'Send Notification',
  fromEmail: 'noreply@example.com',
  toEmail: '{{$json.customerEmail}}',
  subject: 'Welcome!',
  message: 'Thanks for signing up!',
);
```

#### `function()`
Add a code/function node.

```dart
builder.function(
  name: 'Transform Data',
  code: '''
const data = \$input.item.json;
return [{
  json: {
    ...data,
    processed: true,
    timestamp: new Date().toISOString()
  }
}];
''',
);
```

#### `ifNode()`
Add a conditional IF node.

```dart
builder.ifNode(
  name: 'Check Status',
  conditions: [
    {
      'leftValue': '={{$json.status}}',
      'operation': 'equals',
      'rightValue': 'active',
    }
  ],
);
```

#### `setNode()`
Add a SET node for data transformation.

```dart
builder.setNode(
  name: 'Set Variables',
  values: {
    'userId': '={{$json.id}}',
    'createdAt': '={{new Date().toISOString()}}',
  },
);
```

#### `waitNode()`
Add a WAIT node for user input.

```dart
builder.waitNode(
  name: 'Wait for Approval',
  waitType: 'webhook',
);
```

#### `respondToWebhook()`
Add a response node.

```dart
builder.respondToWebhook(
  name: 'Send Success',
  responseCode: 200,
  responseBody: {'status': 'success'},
);
```

### Connection Methods

#### `connect(source, target)`
Connect two nodes.

```dart
builder.connect('Webhook Trigger', 'Process Data');
```

#### `connectSequence(List<String> nodes)`
Connect multiple nodes in sequence.

```dart
builder.connectSequence([
  'Webhook',
  'Validate',
  'Save',
  'Respond',
]);
```

### Positioning Methods

#### `position(x, y)`
Set custom position for next node.

```dart
builder.position(500, 300);
```

#### `newRow()`
Start a new row (reset X position, increment Y).

```dart
builder.newRow(); // Next node starts on new row
```

### Build Methods

#### `build()`
Build and return the workflow object.

```dart
final workflow = builder.build();
```

#### `buildJson()`
Build and return JSON string.

```dart
final json = builder.buildJson();
```

#### `buildAndSave(filePath)`
Build and save to file.

```dart
await builder.buildAndSave('my_workflow.json');
```

---

## 📦 Common Node Types

### Trigger Nodes

```dart
// Webhook Trigger
builder.webhookTrigger(
  name: 'Webhook',
  path: 'my-endpoint',
  method: 'POST',
);

// Schedule Trigger (via custom node)
builder.node(
  name: 'Schedule',
  type: 'n8n-nodes-base.scheduleTrigger',
  parameters: {
    'rule': {
      'interval': [
        {'field': 'cronExpression', 'expression': '0 9 * * *'}
      ]
    }
  },
);
```

### Database Nodes

```dart
// PostgreSQL
builder.postgres(
  name: 'Query Database',
  operation: 'select',
  query: 'SELECT * FROM users WHERE active = true',
);

// MongoDB
builder.mongodb(
  name: 'Find Documents',
  operation: 'find',
  collection: 'products',
  query: {'category': '{{$json.category}}'},
);
```

### API/Integration Nodes

```dart
// Stripe
builder.stripe(
  name: 'Create Charge',
  resource: 'charge',
  operation: 'create',
  additionalParams: {
    'amount': '={{$json.amount}}',
    'currency': 'usd',
  },
);

// Slack
builder.slack(
  name: 'Post Message',
  channel: '#general',
  text: 'New order received: {{$json.orderId}}',
);

// Google Sheets
builder.googleSheets(
  name: 'Append Row',
  operation: 'append',
  spreadsheetId: 'your-sheet-id',
  sheetName: 'Orders',
);
```

### Storage Nodes

```dart
// AWS S3
builder.awsS3(
  name: 'Upload File',
  operation: 'upload',
  bucketName: 'my-bucket',
  fileName: '={{$json.filename}}',
);
```

### Logic Nodes

```dart
// IF condition
builder.ifNode(
  name: 'Check Amount',
  conditions: [
    {
      'leftValue': '={{$json.amount}}',
      'operation': 'larger',
      'rightValue': 100,
    }
  ],
);

// Function (custom code)
builder.function(
  name: 'Calculate',
  code: '''
const items = \$input.all();
const total = items.reduce((sum, item) => sum + item.json.price, 0);
return [{ json: { total } }];
''',
);
```

---

## 🎨 Pre-built Templates

The library includes ready-to-use templates for common workflows.

### CRUD API

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  final workflow = WorkflowTemplates.crudApi(
    resourceName: 'products',
    tableName: 'products',
    webhookPath: 'api/v1',
  );

  await workflow.saveToFile('crud_api.json');
}
```

**Generates:**
- Create (POST)
- Read (GET)
- Update (PUT)
- Delete (DELETE)

### User Registration

```dart
final workflow = WorkflowTemplates.userRegistration(
  webhookPath: 'auth/register',
  tableName: 'users',
  fromEmail: 'noreply@example.com',
);
```

**Includes:**
- Input validation
- Password hashing
- Database save
- Welcome email
- Response

### File Upload

```dart
final workflow = WorkflowTemplates.fileUpload(
  webhookPath: 'upload',
  s3Bucket: 'my-uploads',
);
```

**Includes:**
- File upload handling
- S3 storage
- Metadata saving
- Slack notification

### Order Processing

```dart
final workflow = WorkflowTemplates.orderProcessing(
  webhookPath: 'orders',
  notificationEmail: 'orders@example.com',
);
```

**Includes:**
- Order total calculation
- Stripe payment processing
- Conditional logic (success/failure)
- Email notifications
- Database save

### Multi-Step Form

```dart
final workflow = WorkflowTemplates.multiStepForm(
  webhookPath: 'form/start',
  tableName: 'form_submissions',
);
```

**Includes:**
- Wait nodes for each step
- Data accumulation
- Final save
- Completion response

### Scheduled Report

```dart
final workflow = WorkflowTemplates.scheduledReport(
  reportName: 'Weekly Sales',
  recipients: 'team@example.com',
  schedule: '0 9 * * 1', // Monday 9 AM
);
```

**Includes:**
- Schedule trigger
- Data query
- Report generation
- Email delivery

### Data Sync

```dart
final workflow = WorkflowTemplates.dataSync(
  sourceName: 'Shopify',
  targetName: 'Database',
  schedule: '0 */6 * * *', // Every 6 hours
);
```

**Includes:**
- Schedule trigger
- Source API fetch
- Data transformation
- Target save
- Slack notification

### Webhook Logger

```dart
final workflow = WorkflowTemplates.webhookLogger(
  webhookPath: 'log',
  spreadsheetId: 'your-sheet-id',
  sheetName: 'Event Logs',
);
```

**Includes:**
- Webhook trigger
- Log formatting
- Google Sheets append
- Response

---

## 🎓 Advanced Patterns

### Pattern 1: Conditional Branching

```dart
final workflow = WorkflowBuilder.create()
    .name('Order Approval Workflow')
    .webhookTrigger(name: 'Order', path: 'orders')
    .function(
      name: 'Calculate Total',
      code: 'return [{json: {total: \$json.amount * \$json.quantity}}];',
    )
    .ifNode(
      name: 'Amount > 1000?',
      conditions: [
        {'leftValue': '={{$json.total}}', 'operation': 'larger', 'rightValue': 1000}
      ],
    )
    // TRUE path (amount > 1000) - needs approval
    .waitNode(name: 'Wait for Manager Approval')
    .emailSend(
      name: 'Notify Approved',
      fromEmail: 'orders@example.com',
      toEmail: '={{$json.customerEmail}}',
      subject: 'Order Approved',
    )
    // FALSE path (amount <= 1000) - auto-approve
    .newRow()
    .postgres(name: 'Auto Approve Order', operation: 'update', table: 'orders')
    // Merge paths
    .newRow()
    .respondToWebhook(name: 'Send Response', responseCode: 200)
    // Connections
    .connect('Order', 'Calculate Total')
    .connect('Calculate Total', 'Amount > 1000?')
    .connect('Amount > 1000?', 'Wait for Manager Approval', sourceIndex: 0)
    .connect('Wait for Manager Approval', 'Notify Approved')
    .connect('Notify Approved', 'Send Response')
    .connect('Amount > 1000?', 'Auto Approve Order', sourceIndex: 1)
    .connect('Auto Approve Order', 'Send Response')
    .build();
```

### Pattern 2: Error Handling

```dart
final workflow = WorkflowBuilder.create()
    .name('API Call with Error Handling')
    .webhookTrigger(name: 'Trigger', path: 'api-call')
    .httpRequest(
      name: 'Call External API',
      url: 'https://api.example.com/data',
      method: 'POST',
    )
    .ifNode(
      name: 'API Success?',
      conditions: [
        {'leftValue': '={{$statusCode}}', 'operation': 'equals', 'rightValue': 200}
      ],
    )
    // Success path
    .postgres(name: 'Save Success', operation: 'insert', table: 'api_logs')
    // Error path
    .newRow()
    .postgres(name: 'Log Error', operation: 'insert', table: 'api_errors')
    .emailSend(
      name: 'Alert Admin',
      fromEmail: 'alerts@example.com',
      toEmail: 'admin@example.com',
      subject: 'API Call Failed',
    )
    .connect('Trigger', 'Call External API')
    .connect('Call External API', 'API Success?')
    .connect('API Success?', 'Save Success', sourceIndex: 0)
    .connect('API Success?', 'Log Error', sourceIndex: 1)
    .connect('Log Error', 'Alert Admin')
    .build();
```

### Pattern 3: Parallel Processing

```dart
final workflow = WorkflowBuilder.create()
    .name('Parallel Task Processing')
    .webhookTrigger(name: 'Start', path: 'parallel')
    // Split into parallel paths
    .httpRequest(name: 'Task 1 - Fetch Users', url: 'https://api.example.com/users')
    .newRow()
    .httpRequest(name: 'Task 2 - Fetch Products', url: 'https://api.example.com/products')
    .newRow()
    .httpRequest(name: 'Task 3 - Fetch Orders', url: 'https://api.example.com/orders')
    // Merge results
    .newRow()
    .function(
      name: 'Merge Results',
      code: '''
const allData = \$input.all();
return [{
  json: {
    users: allData[0].json,
    products: allData[1].json,
    orders: allData[2].json
  }
}];
''',
    )
    .respondToWebhook(name: 'Return Combined', responseCode: 200)
    // Connect for parallel execution
    .connect('Start', 'Task 1 - Fetch Users')
    .connect('Start', 'Task 2 - Fetch Products')
    .connect('Start', 'Task 3 - Fetch Orders')
    .connect('Task 1 - Fetch Users', 'Merge Results')
    .connect('Task 2 - Fetch Products', 'Merge Results')
    .connect('Task 3 - Fetch Orders', 'Merge Results')
    .connect('Merge Results', 'Return Combined')
    .build();
```

### Pattern 4: Loop/Iteration

```dart
final workflow = WorkflowBuilder.create()
    .name('Process Items in Batch')
    .webhookTrigger(name: 'Start', path: 'batch')
    .function(
      name: 'Split Items',
      code: '''
const items = \$input.item.json.items;
return items.map(item => ({ json: item }));
''',
    )
    // Process each item
    .httpRequest(
      name: 'Process Item',
      url: 'https://api.example.com/process',
      method: 'POST',
    )
    .postgres(
      name: 'Save Result',
      operation: 'insert',
      table: 'processed_items',
    )
    .connectSequence(['Start', 'Split Items', 'Process Item', 'Save Result'])
    .build();
```

---

## ✅ Best Practices

### 1. **Use Descriptive Names**

```dart
// ❌ Bad
builder.webhookTrigger(name: 'Webhook', path: 'wh1');

// ✅ Good
builder.webhookTrigger(
  name: 'Customer Registration Webhook',
  path: 'customers/register',
);
```

### 2. **Add Tags for Organization**

```dart
builder
  .tags(['production', 'api', 'customers'])
  .name('Customer Management API');
```

### 3. **Use ConnectSequence for Linear Flows**

```dart
// ❌ Verbose
builder
  .connect('A', 'B')
  .connect('B', 'C')
  .connect('C', 'D');

// ✅ Concise
builder.connectSequence(['A', 'B', 'C', 'D']);
```

### 4. **Extract Complex Logic into Functions**

```dart
WorkflowNode buildPaymentNode({required String name}) {
  return WorkflowNode(
    name: name,
    type: 'n8n-nodes-base.stripe',
    position: NodePosition(300, 200),
    parameters: {
      'resource': 'charge',
      'operation': 'create',
      'amount': '={{$json.total}}',
    },
  );
}

// Use in workflow
builder.addNode(buildPaymentNode(name: 'Process Payment'));
```

### 5. **Version Your Workflows**

```dart
builder
  .name('Customer API')
  .version(2.0) // Increment on breaking changes
  .tags(['v2', 'production']);
```

### 6. **Document Complex Workflows**

```dart
builder
  .function(
    name: 'Calculate Discounts',
    code: '''
// Apply volume discount:
// - 10-50 items: 5% off
// - 51-100 items: 10% off
// - 101+ items: 15% off
const quantity = \$json.quantity;
let discount = 0;

if (quantity >= 101) discount = 0.15;
else if (quantity >= 51) discount = 0.10;
else if (quantity >= 10) discount = 0.05;

return [{
  json: {
    ...\$json,
    discount,
    finalPrice: \$json.price * (1 - discount)
  }
}];
''',
  );
```

### 7. **Use Templates for Consistency**

```dart
// Create base template function
N8nWorkflow createApiEndpoint({
  required String resourceName,
  required String tableName,
}) {
  return WorkflowBuilder.create()
    .name('$resourceName API')
    .tags(['api', resourceName.toLowerCase()])
    .webhookTrigger(name: 'API Webhook', path: 'api/$resourceName')
    .postgres(name: 'Database Operation', table: tableName)
    .respondToWebhook(name: 'Send Response')
    .connectSequence(['API Webhook', 'Database Operation', 'Send Response'])
    .build();
}

// Reuse
final usersApi = createApiEndpoint(resourceName: 'Users', tableName: 'users');
final productsApi = createApiEndpoint(resourceName: 'Products', tableName: 'products');
```

---

## 📚 Examples

### Example 1: Simple Todo API

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  final workflow = WorkflowBuilder.create()
      .name('Todo CRUD API')
      .tags(['api', 'todo'])
      .webhookTrigger(name: 'API Endpoint', path: 'todos', method: 'POST')
      .function(
        name: 'Route Request',
        code: '''
const method = \$json.headers['x-method'] || 'GET';
return [{ json: { method, body: \$json.body } }];
''',
      )
      .postgres(name: 'Execute Query', operation: 'executeQuery')
      .respondToWebhook(name: 'Return Result', responseCode: 200)
      .connectSequence([
        'API Endpoint',
        'Route Request',
        'Execute Query',
        'Return Result',
      ])
      .build();

  await workflow.saveToFile('todo_api.json');
  print('✅ Generated: todo_api.json');
}
```

### Example 2: User Registration with Email

```dart
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  final workflow = WorkflowTemplates.userRegistration(
    webhookPath: 'auth/register',
    tableName: 'users',
    fromEmail: 'welcome@myapp.com',
  );

  await workflow.saveToFile('user_registration.json');
  print('✅ Generated: user_registration.json');
}
```

### Example 3: Dynamic Workflow Generation

```dart
import 'package:n8n_dart/n8n_dart.dart';

// Generate workflows for multiple tenants
void main() async {
  final tenants = [
    {'name': 'Acme Corp', 'table': 'acme_orders'},
    {'name': 'TechStart', 'table': 'techstart_orders'},
    {'name': 'ShopHub', 'table': 'shophub_orders'},
  ];

  for (var tenant in tenants) {
    final workflow = WorkflowBuilder.create()
        .name('${tenant['name']} Order Processing')
        .tags([tenant['name']!, 'orders'])
        .webhookTrigger(
          name: 'Order Webhook',
          path: 'orders/${tenant['name']!.toLowerCase()}',
        )
        .postgres(
          name: 'Save Order',
          operation: 'insert',
          table: tenant['table']!,
        )
        .emailSend(
          name: 'Send Confirmation',
          fromEmail: 'orders@${tenant['name']!.toLowerCase()}.com',
          toEmail: '={{$json.customerEmail}}',
          subject: 'Order Confirmation',
        )
        .connectSequence([
          'Order Webhook',
          'Save Order',
          'Send Confirmation',
        ])
        .build();

    await workflow.saveToFile('workflows/${tenant['name']}_orders.json');
  }

  print('✅ Generated ${tenants.length} workflows!');
}
```

---

## 🎯 Next Steps

1. **Explore the examples** in `example/generate_workflows.dart`
2. **Try pre-built templates** from `WorkflowTemplates`
3. **Create custom workflows** using `WorkflowBuilder`
4. **Import into n8n** and test your generated workflows
5. **Share workflows** with your team via Git

---

## 📚 Additional Resources

- [n8n Official Documentation](https://docs.n8n.io)
- [n8n Workflow Templates](https://n8n.io/workflows/)
- [n8n_dart GitHub Repository](https://github.com/your-repo/n8n_dart)
- [Universal Backend Guide](./UNIVERSAL_BACKEND_GUIDE.md)

---

**Happy Workflow Generation!** 🚀
