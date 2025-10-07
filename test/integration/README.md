# Integration Tests

Comprehensive integration tests for the n8n_dart package that validate functionality against a real n8n cloud instance.

## Overview

The integration test suite validates production readiness by testing:
- ✅ Connection to n8n cloud instance
- ✅ Workflow execution lifecycle (start, poll, complete)
- ✅ Wait nodes and interactive workflows
- ✅ Form field parsing and validation
- ✅ Error handling and circuit breaker behavior
- ✅ Concurrent execution
- ✅ Resource cleanup

## Quick Start

### Prerequisites

1. **n8n Cloud Instance**: Access to https://kinly.app.n8n.cloud
2. **Test Workflows**: 4 workflows created on n8n cloud (see [Workflow Setup](#workflow-setup))
3. **Credentials**: n8n cloud credentials (base URL, optional API key)

### Setup

1. **Copy environment template:**
   ```bash
   cp .env.test.example .env.test
   ```

2. **Configure credentials** in `.env.test`:
   ```env
   N8N_BASE_URL=https://kinly.app.n8n.cloud
   N8N_API_KEY=your-api-key-here  # Optional

   # Webhook IDs (see Workflow Setup section)
   N8N_SIMPLE_WEBHOOK_ID=simple-test-webhook
   N8N_WAIT_NODE_WEBHOOK_ID=wait-node-test-webhook
   N8N_SLOW_WEBHOOK_ID=slow-workflow-webhook
   N8N_ERROR_WEBHOOK_ID=error-test-webhook
   ```

3. **Create test workflows** on n8n cloud (see [Workflow Setup](#workflow-setup))

4. **Run tests:**
   ```bash
   # Run all integration tests
   dart test test/integration/

   # Run specific test file
   dart test test/integration/connection_test.dart

   # Run with specific tags
   dart test --tags integration
   dart test --tags connection
   ```

## Workflow Setup

You must manually create 4 test workflows on your n8n cloud instance.

### 1. Simple Webhook Workflow

**Purpose:** Basic execution testing
**Webhook Path:** `/test/simple`
**Expected Duration:** < 2 seconds

**Nodes:**
1. **Webhook** (Trigger)
   - Method: POST
   - Path: `/test/simple`
   - Response Mode: Respond to Webhook

2. **Set** (Transform)
   - Add these mappings:
     - `test_passed` = `true`
     - `timestamp` = `{{$now.toISO()}}`
     - `received_data` = `{{$json}}`

3. **Respond to Webhook**
   - Status Code: 200
   - Body: `{{ $json }}`

**Activation:** ✅ Activate workflow and copy webhook ID

---

### 2. Wait Node Workflow

**Purpose:** Interactive workflow testing
**Webhook Path:** `/test/wait-node`
**Expected Duration:** Variable (waits for user input)

**Nodes:**
1. **Webhook** (Trigger)
   - Method: POST
   - Path: `/test/wait-node`
   - Response Mode: Respond to Webhook

2. **Wait** (Wait for Input)
   - Resume Type: Form
   - Form Fields:
     - `name` (Text) - Required, Label: "Full Name"
     - `email` (Email) - Required, Label: "Email Address"
     - `age` (Number) - Optional, Label: "Age"

3. **Set** (Process Form Data)
   - Add mappings:
     - `form_submitted` = `true`
     - `submitted_name` = `{{$('Wait').item.json.name}}`
     - `submitted_email` = `{{$('Wait').item.json.email}}`
     - `submitted_age` = `{{$('Wait').item.json.age}}`

4. **Respond to Webhook**
   - Status Code: 200
   - Body: `{{ $json }}`

**Activation:** ✅ Activate workflow and copy webhook ID

---

### 3. Slow Workflow

**Purpose:** Timeout and polling behavior testing
**Webhook Path:** `/test/slow`
**Expected Duration:** ~10 seconds

**Nodes:**
1. **Webhook** (Trigger)
   - Method: POST
   - Path: `/test/slow`
   - Response Mode: Respond to Webhook

2. **Function** (Delay)
   - Code:
     ```javascript
     // Wait for 10 seconds
     await new Promise(resolve => setTimeout(resolve, 10000));
     return items;
     ```

3. **Set** (Transform)
   - Add mappings:
     - `slow_test_passed` = `true`
     - `delay_seconds` = `10`

4. **Respond to Webhook**
   - Status Code: 200
   - Body: `{{ $json }}`

**Activation:** ✅ Activate workflow and copy webhook ID

---

### 4. Error Workflow

**Purpose:** Error handling and circuit breaker testing
**Webhook Path:** `/test/error`
**Expected Duration:** < 1 second (immediate failure)

**Nodes:**
1. **Webhook** (Trigger)
   - Method: POST
   - Path: `/test/error`

2. **Function** (Throw Error)
   - Code:
     ```javascript
     throw new Error('Intentional test error');
     ```

**Activation:** ✅ Activate workflow and copy webhook ID

---

## Test Structure

```
test/integration/
├── README.md                        # This file
├── config/
│   ├── test_config.dart            # Test configuration loader
│   └── test_workflows.dart         # Workflow metadata
├── utils/
│   └── test_helpers.dart           # Shared test utilities
├── connection_test.dart            # Connection & health checks (9 tests)
├── workflow_execution_test.dart    # Workflow lifecycle tests (16 tests)
└── wait_node_test.dart             # Wait node & form tests (14 tests)
```

## Test Coverage

### Phase 1: Foundation & Essential Tests ✅

| Test File | Tests | Coverage |
|-----------|-------|----------|
| `connection_test.dart` | 9 | Connection health, SSL validation, configuration |
| `workflow_execution_test.dart` | 16 | Start, poll, complete, errors, concurrency |
| `wait_node_test.dart` | 14 | Wait nodes, forms, resumption, validation |
| **Total Phase 1** | **39** | **All Phase 1 scenarios** |

### Test Categories

1. **Connection Tests** (9 tests)
   - Successful connection to n8n cloud
   - Connection failure handling
   - SSL certificate validation
   - Configuration validation
   - Timeout and polling interval configuration
   - Concurrent connections
   - Resource disposal
   - Development vs production profile selection

2. **Workflow Execution Tests** (16 tests)
   - Start workflow and get execution ID
   - Retrieve execution status
   - Complete workflow successfully
   - Track execution data
   - Status transitions (new → running → success)
   - Slow workflow execution with polling
   - Error workflow detection
   - Non-existent execution handling
   - Empty webhook/execution ID validation
   - Multiple concurrent executions

3. **Wait Node Tests** (14 tests)
   - Detect wait node (waitingForInput flag)
   - Verify non-wait workflows don't set flag
   - Maintain waiting state until resumed
   - Parse form fields from wait node
   - Identify required vs optional fields
   - Parse all form field types (18 types)
   - Resume workflow with valid form data
   - Complete workflow after resumption
   - Handle invalid form data
   - Handle missing required fields
   - Validate form data before resume
   - Empty execution/input handling
   - Non-existent execution handling

## Running Tests

### Run All Integration Tests
```bash
dart test test/integration/
```

### Run Specific Test File
```bash
dart test test/integration/connection_test.dart
dart test test/integration/workflow_execution_test.dart
dart test test/integration/wait_node_test.dart
```

### Run by Tag
```bash
# All integration tests
dart test --tags integration

# Specific categories
dart test --tags connection
dart test --tags workflow
dart test --tags wait-node
```

### Skip Slow Tests
```bash
# Set in .env.test
CI_SKIP_SLOW_TESTS=true

dart test test/integration/
```

### Verbose Output
```bash
dart test --reporter=expanded test/integration/
```

## Configuration

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `N8N_BASE_URL` | ✅ | - | n8n cloud instance URL |
| `N8N_API_KEY` | ❌ | - | API key (optional, for production profile) |
| `N8N_SIMPLE_WEBHOOK_ID` | ✅ | - | Simple webhook workflow ID |
| `N8N_WAIT_NODE_WEBHOOK_ID` | ✅ | - | Wait node workflow ID |
| `N8N_SLOW_WEBHOOK_ID` | ✅ | - | Slow workflow ID |
| `N8N_ERROR_WEBHOOK_ID` | ✅ | - | Error workflow ID |
| `TEST_TIMEOUT_SECONDS` | ❌ | 300 | Maximum test timeout |
| `TEST_MAX_RETRIES` | ❌ | 3 | Maximum retry attempts |
| `TEST_POLLING_INTERVAL_MS` | ❌ | 2000 | Polling interval in milliseconds |
| `CI_RUN_INTEGRATION_TESTS` | ❌ | true | Enable integration tests in CI |
| `CI_SKIP_SLOW_TESTS` | ❌ | false | Skip slow tests |

### Test Helpers

The `test/integration/utils/test_helpers.dart` file provides:

**Client Creation:**
- `createTestClient()` - Create N8nClient for testing
- `createTestReactiveClient()` - Create ReactiveN8nClient for testing

**Wait Helpers:**
- `waitForExecutionStatus()` - Poll until specific status
- `waitForExecutionCompletion()` - Poll until finished
- `waitForWaitingState()` - Poll until waiting for input

**Data Generators:**
- `TestDataGenerator.simple()` - Simple test data
- `TestDataGenerator.formData()` - Form submission data
- `TestDataGenerator.largePayload()` - Performance testing data

**Cleanup:**
- `TestCleanup.registerExecution()` - Register for cleanup
- `TestCleanup.cancelAllExecutions()` - Cancel all registered

**Assertions:**
- `IntegrationAssertions.assertSuccessfulExecution()` - Assert success
- `IntegrationAssertions.assertFailedExecution()` - Assert error
- `IntegrationAssertions.assertWaitingForInput()` - Assert waiting
- `IntegrationAssertions.assertValidFormFields()` - Assert form fields

## Troubleshooting

### Error: Integration test configuration file not found

**Problem:** `.env.test` file doesn't exist

**Solution:**
```bash
cp .env.test.example .env.test
# Edit .env.test with your credentials
```

---

### Error: Required environment variable X is missing

**Problem:** Environment variable not set in `.env.test`

**Solution:** Add the missing variable to `.env.test`:
```env
N8N_BASE_URL=https://kinly.app.n8n.cloud
N8N_SIMPLE_WEBHOOK_ID=your-webhook-id
```

---

### Error: Connection timeout

**Problem:** Cannot connect to n8n cloud instance

**Solutions:**
1. Verify `N8N_BASE_URL` is correct
2. Check internet connection
3. Increase timeout in `.env.test`:
   ```env
   TEST_TIMEOUT_SECONDS=600
   ```

---

### Error: Webhook not found

**Problem:** Webhook ID doesn't exist on n8n cloud

**Solutions:**
1. Verify workflow is created on n8n cloud
2. Verify workflow is **activated** (active toggle ON)
3. Copy correct webhook ID from n8n workflow URL
4. Update webhook ID in `.env.test`

---

### Tests are flaky / failing randomly

**Problem:** Network latency or n8n cloud response time variability

**Solutions:**
1. Increase polling interval:
   ```env
   TEST_POLLING_INTERVAL_MS=5000
   ```
2. Increase timeout:
   ```env
   TEST_TIMEOUT_SECONDS=600
   ```
3. Run tests multiple times to verify:
   ```bash
   for i in {1..5}; do dart test test/integration/; done
   ```

---

### SSL certificate validation failed

**Problem:** SSL/TLS certificate issue

**Solutions:**
1. Ensure using `https://` (not `http://`)
2. Verify n8n cloud instance has valid SSL certificate
3. Check system date/time is correct

---

### Workflow completes too quickly

**Problem:** Can't observe intermediate states

**Solution:** Use slow workflow for polling tests:
```dart
final execution = await client.startWorkflow(
  config.slowWebhookId,  // 10-second delay
  data,
);
```

---

## Performance

### Expected Execution Times

| Test Suite | Tests | Expected Duration |
|------------|-------|-------------------|
| Connection | 9 | ~1-2 minutes |
| Workflow Execution | 16 | ~2-3 minutes |
| Wait Node | 14 | ~2-3 minutes |
| **Total Phase 1** | **39** | **~5-8 minutes** |

### Optimization Tips

1. **Run tests in parallel** (when supported by test runner)
2. **Skip slow tests** in CI/CD with `CI_SKIP_SLOW_TESTS=true`
3. **Reduce polling interval** for faster tests (but increases API calls)
4. **Use production profile** for better performance (requires API key)

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Integration Tests

on:
  pull_request:
  schedule:
    - cron: '0 2 * * *'  # Run nightly at 2 AM

jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable

      - name: Install dependencies
        run: dart pub get

      - name: Run integration tests
        env:
          N8N_BASE_URL: ${{ secrets.N8N_BASE_URL }}
          N8N_API_KEY: ${{ secrets.N8N_API_KEY }}
          N8N_SIMPLE_WEBHOOK_ID: ${{ secrets.N8N_SIMPLE_WEBHOOK_ID }}
          N8N_WAIT_NODE_WEBHOOK_ID: ${{ secrets.N8N_WAIT_NODE_WEBHOOK_ID }}
          N8N_SLOW_WEBHOOK_ID: ${{ secrets.N8N_SLOW_WEBHOOK_ID }}
          N8N_ERROR_WEBHOOK_ID: ${{ secrets.N8N_ERROR_WEBHOOK_ID }}
          CI_SKIP_SLOW_TESTS: 'true'
        run: |
          dart test --tags integration --reporter=expanded
```

### Required GitHub Secrets

Add these to your repository secrets:

- `N8N_BASE_URL`
- `N8N_API_KEY` (optional)
- `N8N_SIMPLE_WEBHOOK_ID`
- `N8N_WAIT_NODE_WEBHOOK_ID`
- `N8N_SLOW_WEBHOOK_ID`
- `N8N_ERROR_WEBHOOK_ID`

## Next Steps

### Phase 2: Reactive Features Validation (Planned)

- Reactive client stream testing
- Circuit breaker integration tests
- Adaptive polling validation
- Error recovery with real network issues

### Phase 3: Template Validation & Advanced Patterns (Planned)

- All 8 pre-built workflow templates
- Workflow generator (WorkflowBuilder) validation
- Multi-execution patterns (parallel, sequential, race)
- Queue and cache testing

See `test/integration/docs/INTEGRATION_TESTS_PLAN.md` for complete roadmap.

## Support

**Issues:** https://github.com/yourusername/n8n_dart/issues
**Documentation:** See main README.md and CLAUDE.md
**Test Plan:** See `test/integration/docs/INTEGRATION_TESTS_PLAN.md`

## License

Same as main n8n_dart package license.
