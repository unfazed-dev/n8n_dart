# Update Workflows to Include Execution ID

## Current Issue

The workflows in n8n cloud are returning webhook input data instead of the Set node output with `execution_id`. This is because the workflows haven't been updated with the new JSON files yet.

## Current Response (Wrong)
```json
{
  "headers": {...},
  "params": {},
  "query": {},
  "body": {"test": "verification"},
  "webhookUrl": "...",
  "executionMode": "production"
}
```

## Expected Response (Correct)
```json
{
  "execution_id": "12345",
  "test_passed": "true",
  "timestamp": "2025-10-09T..."
}
```

## Solution: Update Workflows

You need to update the existing workflows with the new JSON files that include `execution_id`.

### Option 1: Delete and Re-import (Recommended)

1. **Go to n8n cloud**: https://kinly.app.n8n.cloud

2. **Delete existing workflows**:
   - Find "Test: Simple Webhook"
   - Click "..." menu → Delete
   - Repeat for any other test workflows

3. **Import updated workflows**:
   - Click "Add Workflow" → "Import from File"
   - Import each file in order:
     - `test/integration/workflows/1_simple_webhook.json`
     - `test/integration/workflows/2_wait_node_webhook.json`
     - `test/integration/workflows/3_slow_webhook.json`
     - `test/integration/workflows/4_error_webhook.json`

4. **Activate workflows**:
   - Open each imported workflow
   - Click "Active" toggle in top-right
   - Workflow auto-saves

5. **Test the simple workflow**:
   ```bash
   curl -X POST https://kinly.app.n8n.cloud/webhook/test/simple \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}'
   ```

   **Should return**:
   ```json
   {
     "execution_id": "12345",
     "test_passed": "true",
     "timestamp": "2025-10-09T..."
   }
   ```

### Option 2: Manually Update Existing Workflow

If you want to keep the existing workflow:

1. **Open "Test: Simple Webhook" in n8n cloud**

2. **Click on the "Set" node**

3. **Add a new String field**:
   - Name: `execution_id`
   - Value: `={{$execution.id}}`

4. **Move it to the top** of the string fields list

5. **Save workflow**

6. **Test it**:
   ```bash
   curl -X POST https://kinly.app.n8n.cloud/webhook/test/simple \
     -H "Content-Type: application/json" \
     -d '{"test": "data"}'
   ```

7. **Repeat for other workflows**

## Verification

After updating, the webhook response should include `execution_id`:

```bash
curl -X POST https://kinly.app.n8n.cloud/webhook/test/simple \
  -H "Content-Type: application/json" \
  -d '{"name": "test"}'
```

**Look for**:
```json
{
  "execution_id": "actual-n8n-execution-id",  ← Must be present!
  "test_passed": "true",
  ...
}
```

## After Updating

Once all workflows return `execution_id`, run the tests:

```bash
dart test test/integration/reactive_client_integration_test.dart
```

**Expected**: 19-20 out of 20 tests passing (~95-100%)

## Troubleshooting

### Still getting webhook input data
- Check "Respond to Webhook" node is connected correctly
- Verify responseBody is `={{$json}}` not `={{$input}}`
- Make sure Set node is before Respond node in the flow

### execution_id is empty or null
- Verify Set node has the field: `execution_id` = `={{$execution.id}}`
- Check there are no typos in the expression
- Ensure workflow is active (not in test mode)

### Wrong path
- Webhook paths must be:
  - `test/simple`
  - `test/wait-node`
  - `test/slow`
  - `test/error`
- No leading/trailing slashes

## Current Test Status

**Before update**: 15/20 passing (75%)
- Tests pass but use pseudo IDs
- Polling fails because pseudo IDs start with "webhook-"

**After update**: 19-20/20 passing (95-100%)
- Tests will use real execution IDs
- Polling works via REST API
- Full Phase 2 integration complete
