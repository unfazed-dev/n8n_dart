# Integration Test Architecture

This document describes the architecture and organization of the n8n_dart integration test suite.

## Overview

The integration test suite validates n8n_dart functionality through two types of tests:
1. **Local Tests** - Workflow generation and validation (no n8n cloud required)
2. **Cloud Tests** - Actual workflow execution on n8n cloud (requires credentials)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Integration Test Suite                       │
│                         (141+ tests)                             │
└────────────────────────┬────────────────────────────────────────┘
                         │
           ┌─────────────┴──────────────┐
           │                             │
    ┌──────▼──────┐             ┌───────▼────────┐
    │ Local Tests │             │  Cloud Tests   │
    │  (141 tests)│             │ (~70 tests)    │
    │ ✅ No Setup  │             │ ⏳ Requires    │
    │             │             │   Credentials  │
    └──────┬──────┘             └───────┬────────┘
           │                             │
           │                             │
    ┌──────▼───────┐              ┌──────▼──────┐
    │  Workflow    │              │  Execution  │
    │  Generation  │              │   Tests     │
    └──────────────┘              └─────────────┘
```

## Test Organization

### Directory Structure

```
test/integration/
├── README.md                          # Setup and usage guide
├── config/
│   └── test_config.dart               # Test configuration loader
├── docs/
│   ├── INTEGRATION_TESTS_PLAN.md      # 6-phase implementation plan
│   ├── PHASE_6_SUMMARY.md             # Validation results
│   ├── ARCHITECTURE.md                # This file
│   └── TEST_WORKFLOWS.md              # n8n workflow definitions
├── utils/
│   ├── validate_environment.dart      # Environment validation script
│   ├── verify_workflows.dart          # Workflow verification script
│   ├── generate_report.dart           # HTML report generation
│   └── cleanup_executions.dart        # Old execution cleanup
│
├── Local Tests (No credentials needed):
│   ├── workflow_builder_integration_test.dart      # 29 tests
│   ├── workflow_generator_integration_test.dart    # 13 tests
│   └── template_validation_test.dart               # 99 tests
│
└── Cloud Tests (Requires n8n credentials):
    ├── connection_test.dart                        # Connection validation
    ├── workflow_execution_test.dart                # Basic execution
    ├── wait_node_test.dart                         # Wait node interactions
    ├── multi_execution_test.dart                   # Concurrent executions
    ├── e2e_test.dart                               # End-to-end workflows
    ├── error_recovery_integration_test.dart        # Error handling
    ├── circuit_breaker_integration_test.dart       # Circuit breaker
    ├── reactive_client_integration_test.dart       # Reactive features
    ├── polling_integration_test.dart               # Polling strategies
    ├── queue_integration_test.dart                 # Workflow queue
    └── cache_integration_test.dart                 # Execution caching
```

## Test Categories

### 1. Local Tests (141 tests ✅)

Tests that validate workflow generation and structure **without** connecting to n8n cloud.

#### Workflow Builder Tests (29 tests)
**File:** `workflow_builder_integration_test.dart`

Tests the `WorkflowBuilder` fluent API for programmatically creating workflow JSON.

**Test Coverage:**
- Basic workflow creation (webhook, function, database, HTTP, IF nodes)
- Advanced patterns (branching, multiple rows, custom positioning, tags, settings)
- JSON export/import with roundtrip validation
- Connection methods (connect, connectSequence, multiple outputs)
- Node type extensions (email, Slack, wait, Set nodes)
- Workflow validation (structure, positions, connections)
- Complex real-world workflows (API endpoints, data pipelines)

**Example:**
```dart
test('creates simple workflow with webhook and response', () {
  final workflow = WorkflowBuilder.create()
    .name('Simple API')
    .webhookTrigger(path: 'test/simple', method: 'POST')
    .respondToWebhook(responseCode: 200)
    .connectSequence(['Webhook', 'Respond to Webhook'])
    .build();

  expect(workflow.nodes, hasLength(2));
  expect(workflow.connections, isNotEmpty);
});
```

#### Workflow Generator Tests (13 tests)
**File:** `workflow_generator_integration_test.dart`

Tests credential injection and workflow generation with external service credentials.

**Test Coverage:**
- Credential injection (Postgres, AWS, Slack, Stripe, SMTP)
- Placeholder detection and replacement
- Required credential type identification
- WorkflowBuilder integration with credentials
- Template workflow generation
- JSON file generation
- Error handling (missing credentials, unknown nodes)

**Example:**
```dart
test('injects credentials into workflow with postgres node', () {
  final workflow = WorkflowBuilder.create()
    .name('DB Workflow')
    .postgres(operation: 'select', table: 'users')
    .build();

  final injected = injectCredentials(workflow, {
    'postgres': PostgresCredentials(
      host: 'localhost',
      port: 5432,
      database: 'test_db',
      user: 'test_user',
      password: 'test_pass',
    ),
  });

  expect(injected.nodes.first.credentials, isNotNull);
});
```

#### Template Validation Tests (99 tests)
**File:** `template_validation_test.dart`

Comprehensive validation of all 8 pre-built workflow templates.

**Templates Tested:**
1. **CRUD API** (14 checks) - REST API with database operations
2. **User Registration** (13 checks) - User signup with email verification
3. **File Upload** (13 checks) - AWS S3 upload with notifications
4. **Order Processing** (14 checks) - Stripe payments with branching logic
5. **Multi-Step Form** (14 checks) - Form with wait nodes for user input
6. **Scheduled Report** (13 checks) - Cron-triggered database reports
7. **Slack Bot** (9 checks) - Slack command handler
8. **Webhook Relay** (9 checks) - Webhook forwarding with transformations

**Checks Per Template:**
- ✅ Valid workflow structure
- ✅ Valid JSON generation
- ✅ Correct name pattern and tags
- ✅ Minimum required nodes present
- ✅ Correct node types (webhook, database, email, etc.)
- ✅ Proper node connections
- ✅ Export/import roundtrip preservation
- ✅ File save/load functionality
- ✅ Valid node positions

**Example:**
```dart
test('CRUD API generates valid workflow structure', () {
  final workflow = WorkflowTemplates.crudApi(
    apiPath: 'test/api',
    tableName: 'users',
  );

  expect(workflow, isNotNull);
  expect(workflow.nodes.length, greaterThanOrEqualTo(3));
  expect(workflow.connections, isNotEmpty);

  // Verify has webhook trigger
  final webhookNode = workflow.nodes.firstWhere(
    (n) => n.type == 'n8n-nodes-base.webhook',
  );
  expect(webhookNode, isNotNull);
});
```

### 2. Cloud Tests (~70 tests ⏳)

Tests that require actual n8n cloud instance and execute workflows.

**Status:** ⏳ Pending n8n cloud credentials

#### Connection Tests
- Validate connection to n8n cloud
- Health check endpoints
- API key authentication
- Workflow discovery

#### Workflow Execution Tests
- Basic workflow execution
- Execution status polling
- Result retrieval
- Timeout handling

#### Wait Node Tests
- Wait node triggering
- Form field rendering
- Form submission
- Execution resumption

#### Error Recovery Tests
- Network error handling
- Retry logic with exponential backoff
- Circuit breaker pattern
- Error categorization

#### Reactive Tests
- Reactive client functionality
- Stream-based polling
- Event-driven workflows
- Reactive queue management

## Test Infrastructure

### Configuration Management

**TestConfig** (`test/integration/config/test_config.dart`)
- Loads credentials from `.env.test` file or environment variables
- Supports both manual workflow IDs and auto-discovery
- Handles missing credentials gracefully
- Validates configuration before test execution

```dart
final config = TestConfig.load();           // From .env.test
final config = TestConfig.fromEnvironment(); // From env vars
```

### Utility Scripts

#### 1. Environment Validation (`utils/validate_environment.dart`)
Validates test environment before running cloud tests:
- ✅ Checks required environment variables
- ✅ Validates workflow IDs (configured or auto-discovery)
- ✅ Verifies optional Supabase credentials
- ✅ Exit codes: 0=success, 1=failure

```bash
dart run test/integration/utils/validate_environment.dart
```

#### 2. Workflow Verification (`utils/verify_workflows.dart`)
Verifies n8n workflows exist and are active:
- ✅ Discovers all workflows with webhooks
- ✅ Verifies required test workflows by webhook path
- ✅ Checks workflow activation status
- ✅ Provides troubleshooting guidance

```bash
dart run test/integration/utils/verify_workflows.dart
```

#### 3. HTML Report Generation (`utils/generate_report.dart`)
Creates styled HTML report from test JSON output:
- ✅ Parses Dart test JSON output
- ✅ Calculates statistics (total, passed, failed, skipped)
- ✅ Generates styled HTML with metrics
- ✅ Includes error details and stack traces

```bash
dart test --reporter=json > results.json
dart run test/integration/utils/generate_report.dart results.json report.html
```

#### 4. Execution Cleanup (`utils/cleanup_executions.dart`)
Removes old test executions from n8n cloud:
- ✅ Configurable retention (default: 7 days)
- ✅ Discovers workflows via API
- ✅ Prevents accumulation of test data

```bash
MAX_EXECUTIONS_AGE_DAYS=14 dart run test/integration/utils/cleanup_executions.dart
```

## Test Execution Flow

### Local Tests (No Setup Required)

```
┌──────────────┐
│ Run Tests    │
│ dart test    │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ Workflow Builder     │ ✅ 29 tests
│ - Create workflows   │
│ - Validate structure │
│ - Test connections   │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Workflow Generator   │ ✅ 13 tests
│ - Inject credentials │
│ - Generate JSON      │
│ - Handle errors      │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Template Validation  │ ✅ 99 tests
│ - Validate 8 templates
│ - Check structure    │
│ - Test roundtrip     │
└──────┬───────────────┘
       │
       ▼
┌──────────────┐
│ All Passed ✅ │
│ 141/141      │
└──────────────┘
```

### Cloud Tests (Requires Credentials)

```
┌─────────────────┐
│ Setup           │
│ .env.test       │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ Validate Environment│  ← validate_environment.dart
│ - Check credentials │
│ - Verify workflow   │
│   IDs configured    │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Verify Workflows    │  ← verify_workflows.dart
│ - Workflows exist   │
│ - Workflows active  │
│ - Webhooks match    │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Run Tests           │
│ dart test           │
│   --tags=integration│
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Generate Report     │  ← generate_report.dart
│ - Parse JSON        │
│ - Create HTML       │
│ - Show metrics      │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│ Cleanup Executions  │  ← cleanup_executions.dart
│ - Remove old data   │
│ - Keep last 7 days  │
└─────────────────────┘
```

## Test Data & Fixtures

### Mock HTTP Client

**MockN8nHttpClient** (`test/mocks/mock_n8n_http_client.dart`)
- Simulates n8n API responses
- Configurable success/failure scenarios
- Network delay simulation
- Used by all unit tests

### Test Workflows

Test workflows are defined in `docs/TEST_WORKFLOWS.md`:
1. **Simple Test** - Basic webhook execution
2. **Wait Node Test** - Interactive form handling
3. **Slow Test** - Timeout scenario testing
4. **Error Test** - Error handling validation

Each workflow includes:
- Webhook path
- Expected behavior
- JSON definition
- Setup instructions

## Best Practices

### Writing Integration Tests

**DO:**
- ✅ Use `@Tags(['integration'])` annotation
- ✅ Handle missing credentials gracefully with `markTestSkipped()`
- ✅ Clean up resources (dispose clients, close streams)
- ✅ Use descriptive test names
- ✅ Document n8n workflow requirements in test file
- ✅ Test both success and failure scenarios

**DON'T:**
- ❌ Hardcode credentials in test files
- ❌ Assume specific test execution order
- ❌ Create flaky tests (timing-dependent)
- ❌ Leave test data in n8n cloud
- ❌ Make tests dependent on each other

### Example Integration Test

```dart
import 'package:test/test.dart';
import 'package:n8n_dart/n8n_dart.dart';
import '../config/test_config.dart';

@Tags(['integration'])
void main() {
  late N8nClient client;
  late TestConfig config;

  setUp(() {
    config = TestConfig.load();
    if (config.baseUrl.isEmpty) {
      markTestSkipped('No n8n credentials configured');
      return;
    }

    client = N8nClient(
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
    );
  });

  tearDown(() {
    client.dispose();
  });

  group('Workflow Execution', () {
    test('executes simple workflow successfully', () async {
      // Arrange
      final webhookId = config.simpleWorkflowId!;
      final data = {'test': 'data'};

      // Act
      final execution = await client.triggerWorkflow(
        webhookId,
        data: data,
      );

      // Assert
      expect(execution, isNotNull);
      expect(execution.finished, isTrue);
      expect(execution.status, equals(WorkflowStatus.success));
    });
  });
}
```

## Performance Considerations

### Test Execution Times

| Test Suite | Tests | Duration | Notes |
|------------|-------|----------|-------|
| Workflow Builder | 29 | <1s | In-memory only |
| Workflow Generator | 13 | <1s | File I/O minimal |
| Template Validation | 99 | ~60s | JSON serialization |
| **Total Local** | **141** | **~62s** | **No network** |
| Cloud Tests | ~70 | ~15-20min | Network + n8n execution |

### Optimization Tips

1. **Run local tests first** for fast feedback
2. **Skip cloud tests during development** with `--exclude-tags=integration`
3. **Use mocks** for unit testing n8n client
4. **Parallel test execution** not recommended (n8n rate limits)

## Troubleshooting

### Common Issues

#### "No n8n credentials configured"
**Solution:** Create `.env.test` file with credentials:
```env
N8N_BASE_URL=https://yourinstance.app.n8n.cloud
N8N_API_KEY=your-api-key
```

#### "Workflow not found"
**Solution:** Run workflow verification script:
```bash
dart run test/integration/utils/verify_workflows.dart
```

#### "Test timeout"
**Solution:** Increase test timeout or check n8n cloud connectivity:
```dart
test('slow test', () async {
  // ...
}, timeout: Timeout(Duration(minutes: 5)));
```

## Maintenance

### Regular Tasks

**Weekly:**
- Run full test suite
- Review test execution times
- Check for flaky tests

**Monthly:**
- Update test workflows if n8n API changed
- Review and update test documentation
- Clean up old test executions

**Before Releases:**
- Run full test suite on all platforms
- Generate and review test report
- Validate all test documentation current

### Updating Tests for n8n Changes

When n8n updates their API:
1. Review n8n changelog for breaking changes
2. Update models (`n8n_models.dart`) if needed
3. Update test workflows in n8n cloud
4. Run full test suite to detect regressions
5. Update test documentation

## Contributing

See [CONTRIBUTING.md](../../../CONTRIBUTING.md) for guidelines on:
- Writing tests
- Code style
- Pull request process
- Test requirements

## References

- [Integration Test Plan](./INTEGRATION_TESTS_PLAN.md) - Complete 6-phase implementation plan
- [Phase 6 Summary](./PHASE_6_SUMMARY.md) - Comprehensive validation results
- [Test Setup Guide](../README.md) - Setup instructions
- [Test Workflows](./TEST_WORKFLOWS.md) - n8n workflow definitions

---

**Last Updated:** 2025-10-10
**Status:** Phase 6 Complete (75% - local tests validated, cloud tests pending credentials)
