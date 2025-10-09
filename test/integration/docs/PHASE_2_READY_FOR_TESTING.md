# Phase 2 Ready for Testing

## ✅ All Workflows Updated with Execution ID

All 4 test workflows now include `execution_id={{$execution.id}}` in their responses, allowing the client to extract real execution IDs from webhook responses.

## Updated Files

### Workflow JSON Files
- ✅ `test/integration/workflows/1_simple_webhook.json` - Added `execution_id` field
- ✅ `test/integration/workflows/2_wait_node_webhook.json` - Added `execution_id` field
- ✅ `test/integration/workflows/3_slow_webhook.json` - Added `execution_id` field
- ✅ `test/integration/workflows/4_error_webhook.json` - Restructured to return execution ID before error

### Client Code
- ✅ `N8nClient.startWorkflow()` - Extracts `execution_id` from webhook response
- ✅ `ReactiveN8nClient._performStartWorkflow()` - Extracts `execution_id` from webhook response
- ✅ Both clients fall back to pseudo IDs if `execution_id` not present (backward compatible)

### Documentation
- ✅ `WEBHOOK_EXECUTION_ID.md` - Complete guide on execution ID extraction
- ✅ `workflows/README.md` - Updated with execution ID requirement

## How It Works

```
1. POST /webhook/test/simple
   → Triggers workflow in n8n

2. Workflow executes:
   Webhook → Set (adds execution_id) → Respond

3. Response JSON:
   {
     "execution_id": "12345",
     "test_passed": true,
     "timestamp": "..."
   }

4. Client extracts execution_id: "12345"

5. Client polls REST API:
   GET /api/v1/executions/12345
```

## Testing Steps

### 1. Re-import Updated Workflows

Since workflow `1_simple_webhook` was already imported, you need to update it:

**Option A: Delete and Re-import (Recommended)**
1. Go to n8n cloud: https://kinly.app.n8n.cloud
2. Delete the existing "Test: Simple Webhook" workflow
3. Import `test/integration/workflows/1_simple_webhook.json`
4. Activate the workflow
5. Test with curl to verify `execution_id` is returned

**Option B: Manually Add Field**
1. Open "Test: Simple Webhook" workflow in n8n
2. Click on the "Set" node
3. Add new string field:
   - Name: `execution_id`
   - Value: `={{$execution.id}}`
4. Save workflow

### 2. Import Remaining Workflows

Import these 3 new workflows:
- `2_wait_node_webhook.json`
- `3_slow_webhook.json`
- `4_error_webhook.json`

### 3. Verify Execution ID is Returned

Test the simple webhook:

```bash
curl -X POST https://kinly.app.n8n.cloud/webhook/test/simple \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

**Expected Response:**
```json
{
  "execution_id": "1234",  ← Should be present!
  "test_passed": "true",
  "timestamp": "2025-10-09T..."
}
```

### 4. Run Integration Tests

```bash
# Run all Phase 2 tests
dart test test/integration/reactive_client_integration_test.dart

# Should see much higher pass rate with real execution IDs
```

## Expected Results

### Before (with only simple workflow):
- **13/20 tests passing** (65%)
- Failures due to missing workflows and pseudo execution IDs

### After (with all 4 workflows + execution_id):
- **19-20/20 tests passing** (~95-100%)
- Only potential failures might be timing-related

## Key Benefits

✅ **No workflow IDs needed** - Just webhook paths
✅ **Real execution IDs** - From webhook responses
✅ **Proper polling** - Via REST API `/api/v1/executions/{id}`
✅ **Simpler config** - Only webhook paths in `.env.test`
✅ **Backward compatible** - Falls back to pseudo IDs if needed

## Troubleshooting

### Execution ID not in response
- Verify Set node has `execution_id={{$execution.id}}` field
- Check response mode is "Respond to Webhook" (not "On Received")
- Ensure workflow structure is: Webhook → Set → Respond

### Tests still using pseudo IDs
- Check webhook response contains `execution_id` field
- Verify client code extracts it (check logs)
- Ensure `.env.test` has correct webhook paths

### Polling fails with 404
- Execution ID might be invalid
- Check n8n cloud API key is valid
- Verify endpoint is `/api/v1/executions/{id}` (not `/api/execution/{id}`)

## Next Steps

After all tests pass:
1. ✅ Mark Phase 2 as complete
2. Move to Phase 3 (if planned)
3. Consider removing workflow ID fields from config (no longer needed)
4. Update main documentation with execution ID approach

## Files Modified

```
test/integration/
├── workflows/
│   ├── 1_simple_webhook.json          ← Updated
│   ├── 2_wait_node_webhook.json       ← Updated
│   ├── 3_slow_webhook.json            ← Updated
│   ├── 4_error_webhook.json           ← Updated
│   └── README.md                      ← Updated
├── docs/
│   ├── WEBHOOK_EXECUTION_ID.md        ← New
│   └── PHASE_2_READY_FOR_TESTING.md   ← This file
└── .env.test                          ← Updated comments

lib/src/core/services/
├── n8n_client.dart                    ← Extracts execution_id
└── reactive_n8n_client.dart           ← Extracts execution_id
```

## Summary

**Ready to test!** All workflows now return `execution_id` in their webhook responses. Import the updated workflows and run the tests to verify Phase 2 is complete.
