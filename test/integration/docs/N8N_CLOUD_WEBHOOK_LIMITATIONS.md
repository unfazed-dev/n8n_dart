# n8n Cloud Webhook Integration - Limitations and Solutions

## Overview

This document details the findings from implementing integration tests for the n8n_dart package with n8n cloud webhooks, including limitations discovered and solutions implemented.

**Date:** October 7, 2025
**Package Version:** v1.0.0
**n8n Cloud Instance:** https://kinly.app.n8n.cloud

---

## Key Findings

### 1. Webhook URLs vs REST API Endpoints

n8n provides **two different methods** for triggering workflows:

#### A. Webhooks (Available on Free/Paid Plans)
- **URL Format:** `https://{instance}.n8n.cloud/webhook/{path}`
- **Example:** `https://kinly.app.n8n.cloud/webhook/test/simple`
- **Behavior:**
  - Directly triggers workflow execution
  - Returns the workflow's response immediately (if using "Respond to Webhook" node)
  - **Does NOT return execution ID**
  - Cannot track execution status after triggering
  - Suitable for fire-and-forget workflows

#### B. REST API (Requires Paid Plan)
- **URL Format:** `https://{instance}.n8n.cloud/api/v1/workflows/{workflowId}/execute`
- **Behavior:**
  - Triggers workflow via REST API
  - Returns execution ID for tracking
  - Allows polling execution status via `/api/v1/executions/{executionId}`
  - Full execution lifecycle tracking
  - **Requires API key** (not available on free trial)

### 2. n8n Cloud API Access Restrictions

**Critical Limitation:** The n8n REST API is **NOT available during the free trial**.

- ✅ **Webhooks:** Available on all plans (free and paid)
- ❌ **REST API:** Requires paid plan upgrade
- ❌ **Execution tracking:** Not possible with webhooks alone

**Source:** n8n Community Forums
**Reference:** [n8n API access requirements](https://community.n8n.io/t/no-api-to-get-the-execution-id/73960)

### 3. Webhook Response Behavior

When triggering a workflow via webhook:

```bash
# Production webhook URL
curl -X POST "https://kinly.app.n8n.cloud/webhook/test/simple" \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Response (if using Respond to Webhook node)
{
  "headers": {...},
  "params": {},
  "query": {},
  "body": {"test": "data"},
  "webhookUrl": "https://kinly.app.n8n.cloud/webhook/test/simple",
  "executionMode": "production"
}
```

**Key Points:**
- Response contains request metadata
- No execution ID provided
- No way to track execution status after response
- Workflow must complete within HTTP timeout (~30 seconds)

### 4. Test vs Production Webhook URLs

n8n provides two webhook URL formats:

#### Test URL (Development Mode)
- **Format:** `https://{instance}.n8n.cloud/webhook-test/{path}`
- **Example:** `https://kinly.app.n8n.cloud/webhook-test/test/simple`
- **Behavior:**
  - Must click "Execute Workflow" in n8n UI first
  - Only works for ONE call after clicking button
  - Shows execution data in workflow canvas
  - Used for testing/debugging

#### Production URL (Live Mode)
- **Format:** `https://{instance}.n8n.cloud/webhook/{path}`
- **Example:** `https://kinly.app.n8n.cloud/webhook/test/simple`
- **Behavior:**
  - Always available when workflow is active
  - Unlimited calls
  - Executions visible only in "Executions" tab
  - Used for production integrations

**For integration tests:** Always use **production URLs**.

---

## Implementation Changes Made

### 1. Updated `N8nClient.startWorkflow()`

Modified to support webhook-based triggering:

```dart
Future<String> startWorkflow(
  String webhookPath,
  Map<String, dynamic>? initialData,
) async {
  // Try webhook-based triggering first (for n8n cloud)
  try {
    final webhookUrl = Uri.parse('${config.baseUrl}/webhook/$webhookPath');
    final response = await _httpClient.post(webhookUrl, ...);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Generate pseudo execution ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'webhook-$webhookPath-$timestamp';
    }
  } catch (e) {
    // Fallback to API endpoint for self-hosted n8n
    if (e is N8nException && e.statusCode == 404) {
      return await _startWorkflowViaApi(webhookPath, initialData);
    }
    rethrow;
  }
}
```

**Strategy:** Try webhook first, fallback to REST API if available.

### 2. Updated `ReactiveN8nClient._performStartWorkflow()`

Similar changes for reactive client:

```dart
Future<WorkflowExecution> _performStartWorkflow(
  String webhookPath,
  Map<String, dynamic>? data,
) async {
  // Webhook triggering
  final webhookUrl = Uri.parse('${config.baseUrl}/webhook/$webhookPath');
  final response = await _httpClient.post(webhookUrl, ...);

  if (response.statusCode >= 200 && response.statusCode < 300) {
    // Create WorkflowExecution with pseudo ID
    final executionId = 'webhook-$webhookPath-$timestamp';
    return WorkflowExecution(
      id: executionId,
      workflowId: webhookPath,
      status: WorkflowStatus.running,
      startedAt: DateTime.now(),
      data: json.decode(response.body),
    );
  }
}
```

### 3. Pseudo Execution IDs

Since webhooks don't return execution IDs, we generate pseudo IDs:

**Format:** `webhook-{path}-{timestamp}`

**Example:** `webhook-test/simple-1696723456789`

**Limitations:**
- Cannot be used to query execution status
- Only useful for local tracking/logging
- Not valid for n8n REST API calls

---

## Test Results

### Phase 2 Integration Tests - Reactive Client

**Test File:** `test/integration/reactive_client_integration_test.dart`

#### ✅ Passing Tests (13/20)

Tests that work with webhook-only mode:

1. **Stream Emission Tests (3/3)**
   - ✅ `startWorkflow() emits WorkflowExecution`
   - ✅ `startWorkflow() stream completes after emission`
   - ✅ `startWorkflow() propagates errors as stream errors`

2. **State Streams Tests (4/4)**
   - ✅ `executionState$ provides current execution map`
   - ✅ `config$ emits configuration changes`
   - ✅ `connectionState$ tracks connection status`
   - ✅ `metrics$ provides performance metrics`

3. **Event Streams Tests (2/3)**
   - ✅ `workflowStarted$ emits when workflow starts`
   - ❌ `workflowCompleted$ emits when workflow finishes` (needs polling)
   - ❌ `workflowErrors$ emits when workflow fails` (needs polling)

4. **Stream Composition Tests (1/2)**
   - ✅ `Multiple subscribers receive state updates`
   - ❌ `Stream caching works for concurrent polling` (needs polling)

5. **Error Handling Tests (2/2)**
   - ✅ `errors$ stream captures client errors`
   - ✅ `Stream errors can be caught with handleError`

6. **Resource Management Tests (2/2)**
   - ✅ `dispose() cleans up all subscriptions`
   - ✅ `Multiple dispose() calls are safe`

#### ❌ Failing Tests (7/20)

Tests that require REST API access:

1. **Polling Streams Tests (0/3)**
   - ❌ `pollExecutionStatus() emits status updates until completion`
   - ❌ `pollExecutionStatus() uses distinct to avoid duplicate emissions`
   - ❌ `watchExecution() auto-stops when execution finishes`

2. **Event Streams Tests (2/3)**
   - ❌ `workflowCompleted$ emits when workflow finishes`
   - ❌ `workflowErrors$ emits when workflow fails`
   - ❌ `workflowEvents$ emits all event types`

3. **Stream Composition Tests (1/2)**
   - ❌ `Stream caching works for concurrent polling`

**Reason for Failures:**
- Tests require `getExecutionStatus(executionId)` to track workflow completion
- This requires REST API access via `/api/v1/executions/{executionId}`
- REST API not available on n8n cloud free trial

**Pass Rate:** 65% (13/20 tests passing)

---

## Solutions and Workarounds

### Solution 1: Webhook-Only Mode (Current Implementation)

**Status:** ✅ Implemented

**Approach:**
- Use webhooks for triggering workflows
- Accept that execution tracking is unavailable
- Mark polling tests as "not supported in webhook mode"

**Pros:**
- Works on free n8n cloud tier
- No API key required
- Simpler implementation

**Cons:**
- Cannot track execution status
- Cannot poll for completion
- ~35% of integration tests fail

**Use Case:** Development, testing basic webhook functionality

### Solution 2: Hybrid Mode (Webhook + REST API)

**Status:** 🚧 Not Implemented (Requires Paid Plan)

**Approach:**
1. Trigger workflows via webhook (fast, no API needed)
2. Query execution list via REST API to find recent executions
3. Poll execution status via REST API
4. Track completion and get final results

**Implementation Steps:**

```dart
// 1. Trigger workflow via webhook
final webhookResponse = await _httpClient.post(
  Uri.parse('${config.baseUrl}/webhook/$webhookPath'),
  body: json.encode(data),
);

// 2. Query recent executions to find our execution
final executionsUrl = Uri.parse(
  '${config.baseUrl}/api/v1/executions?workflowId=$workflowId&limit=10'
);
final executionsResponse = await _httpClient.get(
  executionsUrl,
  headers: {'X-N8N-API-KEY': config.apiKey!},
);

// 3. Find execution by matching timestamp/data
final executions = json.decode(executionsResponse.body)['data'];
final ourExecution = executions.firstWhere((exec) =>
  exec['createdAt'] > webhookTriggerTime
);

// 4. Poll execution status
final statusUrl = Uri.parse(
  '${config.baseUrl}/api/v1/executions/${ourExecution['id']}'
);
final statusResponse = await _httpClient.get(
  statusUrl,
  headers: {'X-N8N-API-KEY': config.apiKey!},
);
```

**Pros:**
- Full execution tracking
- All integration tests can pass
- Production-ready monitoring

**Cons:**
- Requires paid n8n cloud plan
- More complex implementation
- Additional API calls needed

**Use Case:** Production deployments, full test coverage

### Solution 3: Test-Only Execution Tracking

**Status:** 💡 Alternative Approach

**Approach:**
- Use webhook response data as "execution result"
- Add unique identifiers to webhook payloads
- Track executions via workflow output, not n8n API

**Implementation:**

```dart
// Add unique tracking ID to payload
final trackingId = Uuid().v4();
final data = {
  ...originalData,
  '_tracking_id': trackingId,
  '_triggered_at': DateTime.now().toIso8601String(),
};

// Trigger workflow
final response = await triggerWebhook(data);

// Workflow includes tracking ID in response
final result = json.decode(response.body);
expect(result['_tracking_id'], trackingId);
expect(result['status'], 'completed');
```

**Pros:**
- Works on free tier
- No API access needed
- Simple to implement

**Cons:**
- Requires modifying test workflows
- Cannot track async/long-running workflows
- Not suitable for production monitoring

**Use Case:** Integration tests only

---

## Recommendations

### For Development/Testing (Free Tier)

**Use Solution 1: Webhook-Only Mode**

```yaml
# .env.test configuration
N8N_BASE_URL=https://kinly.app.n8n.cloud
N8N_SIMPLE_WEBHOOK_ID=test/simple
# No API key needed

# Run tests, accepting some will skip/fail
dart test test/integration/ --tags phase-2
```

**Expected Results:**
- ~65% tests pass (webhook functionality)
- ~35% tests fail (polling/status tracking)
- Sufficient for validating core reactive features

### For Production Use (Paid Plan)

**Use Solution 2: Hybrid Mode**

1. **Upgrade n8n cloud plan** to enable REST API
2. **Get API key** from n8n cloud dashboard
3. **Update configuration:**

```yaml
# .env.test configuration
N8N_BASE_URL=https://kinly.app.n8n.cloud
N8N_API_KEY=your-actual-api-key-here
N8N_SIMPLE_WEBHOOK_ID=test/simple
```

4. **Implement hybrid triggering** (see Solution 2 above)
5. **Run full test suite:**

```bash
dart test test/integration/ --tags phase-2
# Expected: 100% tests pass
```

### For CI/CD

**Option A: Skip Polling Tests**

```dart
// Add skip condition
test('pollExecutionStatus() emits updates', () async {
  if (!config.hasApiKey) {
    skip('Requires n8n REST API access');
  }
  // ... test code
});
```

**Option B: Use Different Test Suites**

```bash
# Run webhook-only tests (no API needed)
dart test test/integration/ --tags webhook-only

# Run full tests (API required)
dart test test/integration/ --tags full-integration
```

---

## API Endpoints Reference

### n8n Cloud REST API

**Base URL:** `https://{instance}.n8n.cloud/api/v1`

**Authentication:**
```
Headers:
  X-N8N-API-KEY: {your-api-key}
```

### Executions Endpoints

#### List Executions
```http
GET /api/v1/executions?workflowId={id}&limit={n}

Response:
{
  "data": [
    {
      "id": "execution-id",
      "workflowId": "workflow-id",
      "status": "success|error|waiting|running",
      "createdAt": "2025-10-07T...",
      "finishedAt": "2025-10-07T...",
      "data": {...}
    }
  ]
}
```

#### Get Execution Status
```http
GET /api/v1/executions/{executionId}

Response:
{
  "id": "execution-id",
  "workflowId": "workflow-id",
  "status": "success",
  "finished": true,
  "data": {...},
  "createdAt": "2025-10-07T...",
  "finishedAt": "2025-10-07T..."
}
```

### Webhook Endpoints

#### Production Webhook
```http
POST /webhook/{path}
Content-Type: application/json

Body: {your-workflow-data}

Response: {workflow-response}
```

#### Test Webhook
```http
POST /webhook-test/{path}
Content-Type: application/json

Note: Requires clicking "Execute Workflow" in UI first
```

---

## Future Improvements

### Short-term (No API Required)

1. **Add webhook-only test tags**
   ```dart
   @Tags(['integration', 'webhook-only'])
   test('webhook trigger works', () {...});
   ```

2. **Improve error messages for skipped tests**
   ```dart
   if (!config.hasApiKey) {
     skip('REST API required. Upgrade n8n cloud plan to enable.');
   }
   ```

3. **Document webhook limitations in README**

### Long-term (With API Access)

1. **Implement hybrid mode** (Solution 2)
2. **Add execution tracking** via REST API
3. **Implement adaptive polling** with backoff
4. **Add execution search** by timestamp/data
5. **Implement webhook→execution mapping** logic

---

## Related Documentation

- **n8n Webhook Docs:** https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/
- **n8n API Reference:** https://docs.n8n.io/api/api-reference/
- **n8n Community Forum:** https://community.n8n.io/
- **Integration Test Plan:** [INTEGRATION_TESTS_PLAN.md](./INTEGRATION_TESTS_PLAN.md)
- **Test README:** [test/integration/README.md](../README.md)

---

## Conclusion

The n8n_dart package successfully supports n8n cloud webhook integrations with the following considerations:

✅ **Webhook triggering works perfectly** on free and paid plans
✅ **65% of integration tests pass** without API access
⚠️ **Execution tracking requires** REST API (paid plan)
⚠️ **Polling/status tests fail** without API key

For most use cases, webhook-only mode is sufficient. For production monitoring and full test coverage, upgrade to a paid n8n cloud plan with REST API access.

---

## 🚧 PHASE 2 STATUS: IN PROGRESS

**Current State:** Webhook-only mode implemented, but Phase 2 is **NOT COMPLETE**

**Test Results:**
- ✅ 13/20 tests passing (65%)
- ❌ 7/20 tests failing (35%)
- 🚫 **Blocking Issue:** No execution tracking without REST API

**What's Blocking Completion:**
1. **Missing REST API Access** - Required for execution status tracking
2. **Failing Polling Tests** - Cannot verify workflow completion
3. **Failing Event Tests** - Cannot track workflowCompleted$/workflowErrors$ events
4. **Failing Stream Composition Tests** - Concurrent polling requires status checks

**Decision Required:**

### Option A: Accept Partial Completion ⚠️
- Mark 7 tests as "skip when no API key"
- Document webhook-only limitations
- Complete Phase 2 with 65% pass rate
- **Pro:** No cost, works on free tier
- **Con:** Incomplete test coverage

### Option B: Implement Full Solution ✅
- Get n8n cloud API key (requires paid plan)
- Implement hybrid mode (webhook + REST API)
- Achieve 100% test pass rate
- **Pro:** Complete test coverage, production-ready
- **Con:** Requires paid n8n cloud subscription

### Option C: Implement Workaround 🔧
- Use Solution 3 (test-only execution tracking)
- Modify test workflows to include status in response
- Works on free tier
- **Pro:** No API needed, creative solution
- **Con:** Only works for test scenarios, not production-ready

**Next Steps:** Decide which option to pursue before marking Phase 2 as complete
