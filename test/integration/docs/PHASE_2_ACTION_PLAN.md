# Phase 2 Integration Tests - Action Plan

## Current Situation

**Date:** October 7, 2025
**Status:** 🚧 IN PROGRESS - Blocked on execution tracking

### What's Working ✅
- Webhook-based workflow triggering
- 13 out of 20 reactive client tests passing
- Basic stream emission tests
- State stream tests
- Error handling tests
- Resource management tests

### What's Failing ❌
- 7 out of 20 tests requiring execution status tracking
- All polling-related tests
- Workflow completion event tests
- Stream composition with polling

### Root Cause
**n8n webhooks don't return execution IDs**, and **n8n cloud REST API requires a paid plan**.

---

## Decision Matrix

### Option A: Skip Polling Tests (Quick Solution)

**Implementation Time:** 1-2 hours
**Cost:** $0
**Test Pass Rate:** 65% (13/20)

#### Tasks:
1. Add `skip()` conditions to polling tests when no API key
2. Update test documentation
3. Mark Phase 2 as "partially complete"
4. Document limitations in README

#### Code Changes:
```dart
test('pollExecutionStatus() emits updates', () async {
  if (config.apiKey == null || config.apiKey!.isEmpty) {
    skip('Requires n8n REST API access (paid plan)');
  }
  // ... test code
});
```

#### Pros:
- ✅ Quick to implement
- ✅ No cost
- ✅ Works on free tier
- ✅ Clearly documents limitations

#### Cons:
- ❌ Incomplete test coverage
- ❌ Cannot validate polling behavior
- ❌ Not production-ready validation

#### Recommendation:
**Use this if:** You're on free tier and just need basic webhook validation.

---

### Option B: Implement REST API Integration (Complete Solution)

**Implementation Time:** 4-6 hours
**Cost:** n8n Cloud paid plan (~$20-50/month)
**Test Pass Rate:** 100% (20/20)

#### Prerequisites:
1. Upgrade n8n cloud plan
2. Obtain API key from n8n dashboard
3. Add API key to `.env.test`

#### Tasks:
1. Implement `getExecutionStatus()` with REST API
2. Implement execution search by timestamp
3. Map webhook triggers to execution IDs
4. Update polling tests to use REST API
5. Test full execution lifecycle

#### Code Changes:

**Add to N8nClient:**
```dart
/// Get execution status via REST API
Future<WorkflowExecution> getExecutionStatus(String executionId) async {
  if (config.apiKey == null) {
    throw N8nException.workflow('API key required for execution tracking');
  }

  final url = Uri.parse('${config.baseUrl}/api/v1/executions/$executionId');
  final headers = {
    'Accept': 'application/json',
    'X-N8N-API-KEY': config.apiKey!,
  };

  final response = await _httpClient.get(url, headers: headers);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return WorkflowExecution.fromJson(data);
  } else {
    throw N8nException.serverError(
      'Failed to get execution status',
      statusCode: response.statusCode,
    );
  }
}

/// Find recent executions for a workflow
Future<List<WorkflowExecution>> findRecentExecutions({
  required String workflowId,
  DateTime? after,
  int limit = 10,
}) async {
  final url = Uri.parse(
    '${config.baseUrl}/api/v1/executions?workflowId=$workflowId&limit=$limit'
  );
  final headers = {
    'Accept': 'application/json',
    'X-N8N-API-KEY': config.apiKey!,
  };

  final response = await _httpClient.get(url, headers: headers);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final executions = (data['data'] as List)
        .map((e) => WorkflowExecution.fromJson(e))
        .toList();

    if (after != null) {
      return executions
          .where((e) => e.startedAt.isAfter(after))
          .toList();
    }
    return executions;
  }

  throw N8nException.serverError('Failed to list executions');
}
```

**Update startWorkflow():**
```dart
Future<String> startWorkflow(
  String webhookPath,
  Map<String, dynamic>? initialData,
) async {
  final triggerTime = DateTime.now();

  // Trigger via webhook
  final webhookUrl = Uri.parse('${config.baseUrl}/webhook/$webhookPath');
  await _httpClient.post(webhookUrl, body: json.encode(initialData));

  // If API key available, find the execution
  if (config.apiKey != null) {
    await Future.delayed(Duration(milliseconds: 500)); // Wait for execution to register

    final executions = await findRecentExecutions(
      workflowId: webhookPath,
      after: triggerTime.subtract(Duration(seconds: 2)),
    );

    if (executions.isNotEmpty) {
      return executions.first.id; // Return real execution ID
    }
  }

  // Fallback to pseudo ID
  return 'webhook-$webhookPath-${triggerTime.millisecondsSinceEpoch}';
}
```

#### Pros:
- ✅ Complete test coverage (100%)
- ✅ Production-ready validation
- ✅ Real execution tracking
- ✅ Can validate all reactive features

#### Cons:
- ❌ Requires paid plan ($20-50/month)
- ❌ More implementation work
- ❌ Adds API dependency

#### Recommendation:
**Use this if:** You're serious about production deployment and want full validation.

---

### Option C: Workflow-Based Status (Creative Workaround)

**Implementation Time:** 2-3 hours
**Cost:** $0
**Test Pass Rate:** 90% (18/20)

#### Concept:
Modify test workflows to include execution status in their responses, eliminating need for polling.

#### Tasks:
1. Update test workflows to return completion status
2. Add execution tracking to workflow responses
3. Modify tests to check response instead of polling
4. Keep 2 polling tests skipped (still need real polling validation)

#### Workflow Changes:

**Update Simple Webhook workflow:**
```javascript
// In "Set" node
{
  "test_passed": true,
  "timestamp": "{{$now.toISO()}}",
  "execution_id": "{{$execution.id}}",
  "execution_status": "completed",
  "received_data": "{{$json}}"
}
```

**For slow workflow:**
```javascript
// In "Function" node (before delay)
const executionId = $execution.id;
const startTime = new Date();

// Wait 10 seconds
await new Promise(resolve => setTimeout(resolve, 10000));

return items.map(item => ({
  ...item.json,
  execution_id: executionId,
  execution_status: 'completed',
  started_at: startTime.toISOString(),
  finished_at: new Date().toISOString(),
  duration_ms: new Date() - startTime
}));
```

#### Test Changes:
```dart
test('workflow execution completes', () async {
  final execution = await client
      .startWorkflow(config.simpleWebhookId, data)
      .first;

  // Check response data includes status
  expect(execution.data!['execution_status'], 'completed');
  expect(execution.data!['execution_id'], isNotEmpty);
});

test('slow workflow reports timing', () async {
  final execution = await client
      .startWorkflow(config.slowWebhookId, data)
      .first;

  expect(execution.data!['duration_ms'], greaterThan(9000));
  expect(execution.data!['execution_status'], 'completed');
}, timeout: Timeout(Duration(seconds: 120)));
```

#### Pros:
- ✅ No API needed (free tier)
- ✅ 90% test coverage
- ✅ Creative solution
- ✅ Validates workflow execution

#### Cons:
- ❌ Not production-like (real apps can't modify workflows)
- ❌ Only works for synchronous workflows
- ❌ Can't validate true polling behavior
- ❌ Requires workflow modifications

#### Recommendation:
**Use this if:** You want good test coverage without paying, and understand the limitations.

---

## Recommended Path Forward

### Phase 1: Immediate (Choose ONE)

**For Development/Learning:**
→ **Option A** (Skip polling tests)
- Quick, free, good enough for development
- Clear documentation of limitations

**For Production Project:**
→ **Option B** (REST API integration)
- Worth the investment for complete validation
- Production-ready solution

**For Budget-Conscious with High Standards:**
→ **Option C** (Workflow-based workaround)
- Best compromise between coverage and cost
- 90% coverage without API

### Phase 2: Future Enhancement

Once Option A, B, or C is chosen and Phase 2 is complete, consider:

1. **Add CI/CD integration**
   - Skip polling tests in free tier CI
   - Run full tests in paid tier

2. **Document patterns**
   - Show users which tests pass in which modes
   - Provide migration guide from free to paid

3. **Add configuration detection**
   ```dart
   enum N8nMode {
     webhookOnly,  // Free tier
     hybridApi,    // Paid tier with API
   }

   static N8nMode detectMode(TestConfig config) {
     return config.hasApiKey ? N8nMode.hybridApi : N8nMode.webhookOnly;
   }
   ```

---

## Implementation Checklist

### For Option A (Skip Tests):
- [ ] Add `skip()` to 7 failing tests
- [ ] Update test documentation
- [ ] Add "webhook-only" test tag
- [ ] Document in README.md
- [ ] Mark Phase 2 complete with caveats

### For Option B (REST API):
- [ ] Get n8n cloud API key
- [ ] Add API key to `.env.test`
- [ ] Implement `getExecutionStatus()`
- [ ] Implement `findRecentExecutions()`
- [ ] Update `startWorkflow()` to find execution ID
- [ ] Update `ReactiveN8nClient` similarly
- [ ] Test all 20 tests pass
- [ ] Mark Phase 2 complete ✅

### For Option C (Workflow Workaround):
- [ ] Update 4 test workflows to include status
- [ ] Modify 5 failing tests to check response
- [ ] Skip 2 true-polling tests
- [ ] Test 18/20 pass
- [ ] Document workaround limitations
- [ ] Mark Phase 2 complete with note

---

## Time Estimates

| Option | Implementation | Testing | Documentation | Total |
|--------|---------------|---------|---------------|-------|
| A: Skip | 1 hour | 30 min | 30 min | **2 hours** |
| B: REST API | 4 hours | 1 hour | 1 hour | **6 hours** |
| C: Workaround | 2 hours | 30 min | 30 min | **3 hours** |

---

## Decision Point

**Which option should we implement?**

Please respond with your choice:
- **A** - Skip polling tests (free tier solution)
- **B** - Implement REST API (paid tier, complete solution)
- **C** - Implement workflow workaround (creative middle ground)

Once decided, we'll implement and complete Phase 2.
