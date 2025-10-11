# Cloud Edge Cases Integration Tests

This test suite validates n8n_dart behavior under extreme cloud conditions that can only be tested with a real n8n cloud instance.

## Test Coverage

### 1. Large Payloads (3 tests)
- Very large payload handling (1MB+)
- Extra large payload handling (5MB+)
- Concurrent large payloads (3x 512KB)

### 2. Long Executions (2 tests)
- Very long workflow execution (>5 minutes)
- Status polling during long execution (3 minutes)

### 3. Network Resilience (3 tests)
- Network timeout with automatic retry
- Circuit breaker opening after repeated failures
- Recovery from transient network errors

### 4. Concurrent Execution (5 tests)
- High concurrency (10 parallel workflows)
- Extreme concurrency (50 parallel workflows)
- Execution isolation under concurrent load
- Concurrent slow workflows (5 parallel)
- Maintaining unique execution IDs under load

## Prerequisites

### Required: n8n Cloud Workflows

These tests require **active workflows** deployed to your n8n cloud instance. The tests will fail with 404 errors if the workflows don't exist.

#### Workflow 1: Simple Test Workflow
- **Webhook Path:** `test/simple` (or set `N8N_SIMPLE_WEBHOOK_PATH` in `.env.test`)
- **Purpose:** Fast execution for testing basic operations
- **Recommended Setup:**
  ```
  Webhook (POST /test/simple)
  → Set node (add timestamp)
  → Respond to Webhook (200 OK)
  ```

#### Workflow 2: Slow Test Workflow
- **Webhook Path:** `test/slow` (or set `N8N_SLOW_WEBHOOK_PATH` in `.env.test`)
- **Purpose:** Long-running execution testing
- **Recommended Setup:**
  ```
  Webhook (POST /test/slow)
  → Code node (setTimeout or delay based on payload.delay seconds)
  → Set node (add completion timestamp)
  → Respond to Webhook (200 OK)
  ```

### Configuration

Add these to your `.env.test` file (they have defaults but you can customize):

```bash
# Webhook paths (defaults shown)
N8N_SIMPLE_WEBHOOK_PATH=test/simple
N8N_SLOW_WEBHOOK_PATH=test/slow

# Workflow IDs (use 'auto' for auto-discovery)
N8N_SIMPLE_WORKFLOW_ID=auto
N8N_SLOW_WORKFLOW_ID=auto
```

## Running the Tests

### Run all cloud edge case tests:
```bash
dart test test/integration/cloud_edge_cases_test.dart
```

### Run specific test groups:
```bash
# Large payloads only
dart test test/integration/cloud_edge_cases_test.dart --name "Large Payloads"

# Network resilience only
dart test test/integration/cloud_edge_cases_test.dart --name "Network Resilience"

# Concurrent execution only
dart test test/integration/cloud_edge_cases_test.dart --name "Concurrent Execution"
```

### Run with verbose output:
```bash
dart test test/integration/cloud_edge_cases_test.dart --reporter=expanded
```

## Test Execution Time

**Total:** 15-25 minutes (all tests)

Individual test timeouts:
- Large payload tests: 2-5 minutes each
- Long execution tests: 5-8 minutes each
- Network resilience: 1-2 minutes each
- Concurrent execution: 2-3 minutes each

## Tags

All tests are tagged with:
- `@slow` - Long-running tests
- `@cloud` - Requires cloud infrastructure
- `@integration` - Integration test category

Filter tests by tags:
```bash
# Run only cloud tests
dart test --tags=cloud

# Exclude slow tests
dart test --exclude-tags=slow
```

## Expected Behavior

### Successful Tests
Tests should:
- ✅ Handle large payloads without errors
- ✅ Complete long executions successfully
- ✅ Retry on transient network failures
- ✅ Maintain isolation under concurrent load
- ✅ Open circuit breaker after repeated failures
- ✅ Return unique execution IDs for each workflow

### Known Limitations
- **5MB+ payloads** may fail due to n8n cloud limits (this is acceptable)
- **50 parallel workflows** may experience some failures due to rate limiting (80%+ success required)
- **Circuit breaker test** requires intentionally invalid host (works with mock host)

## Troubleshooting

### Error: "The requested webhook is not registered"
**Cause:** Workflows don't exist in n8n cloud or are not active.

**Solution:**
1. Log into your n8n cloud instance at https://kinly.app.n8n.cloud
2. Create the required workflows (see Prerequisites above)
3. Make sure workflows are **activated** (toggle in top-right)
4. Verify webhook paths match your `.env.test` configuration

### Error: "API key expired"
**Cause:** N8N_API_KEY in `.env.test` has expired.

**Solution:**
1. Log into n8n cloud
2. Go to Settings → API
3. Generate a new API key
4. Update `N8N_API_KEY` in `.env.test`

### Error: "Execution timeout"
**Cause:** n8n cloud is slow or the workflow is hanging.

**Solution:**
1. Check n8n cloud status (https://status.n8n.io)
2. Increase timeout in `.env.test`: `TEST_TIMEOUT_SECONDS=600`
3. Run individual tests instead of full suite

### Tests passing locally but failing in CI
**Cause:** CI environment doesn't have `.env.test` configured.

**Solution:**
Add secrets to your CI environment:
- `N8N_BASE_URL`
- `N8N_API_KEY`
- Webhook paths and workflow IDs

## Contributing

When adding new cloud edge case tests:

1. **Always tag with `@slow` and `@cloud`**
2. **Add appropriate timeout** (consider 2x expected execution time)
3. **Use `createTestReactiveClient(config)`** helper
4. **Clean up with `addTearDown(client.dispose)`**
5. **Document expected behavior** in test description
6. **Update this README** with new test coverage

## See Also

- [Integration Tests Plan](docs/INTEGRATION_TESTS_PLAN.md) - Overall test strategy
- [Test Helpers](utils/test_helpers.dart) - Shared test utilities
- [Test Config](config/test_config.dart) - Configuration management
