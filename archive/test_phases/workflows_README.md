# Test Workflows for Integration Testing

This directory contains 4 n8n workflow JSON files that must be imported into your n8n cloud instance for integration tests to run.

## ⚠️ Important: All workflows include `execution_id` in responses

All workflows have been configured to return the execution ID in their webhook response using `{{$execution.id}}`. This allows the client to track execution status via the REST API without needing workflow IDs. See `../docs/WEBHOOK_EXECUTION_ID.md` for details.

## Quick Setup

### Option 1: Import via n8n UI (Recommended)

1. **Go to n8n cloud:** https://kinly.app.n8n.cloud
2. **Import each workflow:**
   - Click "Add Workflow" → "Import from File"
   - Select each JSON file in order:
     - `1_simple_webhook.json`
     - `2_wait_node_webhook.json`
     - `3_slow_webhook.json`
     - `4_error_webhook.json`
   - Click "Import"
3. **Activate each workflow:**
   - Open imported workflow
   - Click "Active" toggle in top-right
   - Workflow will auto-save
4. **Copy webhook IDs:**
   - Open each workflow
   - Click on the "Webhook" node
   - Copy the webhook URL (format: `https://kinly.app.n8n.cloud/webhook/WEBHOOK_ID`)
   - Extract just the `WEBHOOK_ID` part
5. **Update `.env.test`:**
   ```env
   N8N_SIMPLE_WEBHOOK_ID=<webhook-id-from-workflow-1>
   N8N_WAIT_NODE_WEBHOOK_ID=<webhook-id-from-workflow-2>
   N8N_SLOW_WEBHOOK_ID=<webhook-id-from-workflow-3>
   N8N_ERROR_WEBHOOK_ID=<webhook-id-from-workflow-4>
   ```

### Option 2: Manual Creation

If import doesn't work, manually create workflows following these specifications:

#### 1. Simple Webhook (`/test/simple`)
- **Webhook Node:** POST, path `/test/simple`, Response Mode: "Respond to Webhook"
- **Set Node:** Add `execution_id={{$execution.id}}`, `test_passed=true`, `timestamp={{$now.toISO()}}`
- **Respond to Webhook Node:** Status 200, Body `{{$json}}`
- Connect: Webhook → Set → Respond

#### 2. Wait Node Webhook (`/test/wait-node`)
- **Webhook Node:** POST, path `/test/wait-node`, Response Mode: "Respond to Webhook"
- **Wait Node:** Form with fields:
  - `name` (Text, Required)
  - `email` (Email, Required)
  - `age` (Number, Optional)
- **Set Node:** Add `execution_id={{$execution.id}}`, `form_submitted=true`, `submitted_name={{$('Wait').item.json.name}}`, `submitted_email={{$('Wait').item.json.email}}`, `submitted_age={{$('Wait').item.json.age}}`
- **Respond to Webhook Node:** Status 200, Body `{{$json}}`
- Connect: Webhook → Wait → Set → Respond

#### 3. Slow Webhook (`/test/slow`)
- **Webhook Node:** POST, path `/test/slow`, Response Mode: "Respond to Webhook"
- **Function Node:** Code:
  ```javascript
  // Wait for 10 seconds
  await new Promise(resolve => setTimeout(resolve, 10000));
  return items;
  ```
- **Set Node:** Add `execution_id={{$execution.id}}`, `slow_test_passed=true`, `delay_seconds=10`
- **Respond to Webhook Node:** Status 200, Body `{{$json}}`
- Connect: Webhook → Function → Set → Respond

#### 4. Error Webhook (`/test/error`)
- **Webhook Node:** POST, path `/test/error`, Response Mode: "Respond to Webhook"
- **Set Node:** Add `execution_id={{$execution.id}}`, `status=starting`
- **Respond to Webhook Node:** Status 200, Body `{{$json}}`
- **Function Node:** Code:
  ```javascript
  throw new Error('Intentional test error');
  ```
- Connect: Webhook → Set → Respond → Function

## Workflow Details

### 1. Simple Webhook
**Purpose:** Basic execution testing
**Path:** `/test/simple`
**Duration:** < 2 seconds
**Tests:** Connection, basic execution, response handling

### 2. Wait Node Webhook
**Purpose:** Interactive workflow with wait node
**Path:** `/test/wait-node`
**Duration:** Variable (waits for user input)
**Tests:** Wait nodes, form fields, workflow resumption

### 3. Slow Webhook
**Purpose:** Timeout and polling behavior
**Path:** `/test/slow`
**Duration:** ~10 seconds
**Tests:** Polling intervals, timeout handling, long-running workflows

### 4. Error Webhook
**Purpose:** Error handling and circuit breaker
**Path:** `/test/error`
**Duration:** < 1 second (fails immediately)
**Tests:** Error detection, error recovery, circuit breaker logic

## Verification

After setup, verify workflows work:

```bash
# Test simple webhook
curl -X POST https://kinly.app.n8n.cloud/webhook/YOUR_WEBHOOK_ID \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Should return:
# {"test_passed": true, "timestamp": "2025-10-07...", "received_data": {...}}
```

## Running Integration Tests

Once workflows are set up and `.env.test` is configured:

```bash
# Run all integration tests
dart test test/integration/

# Run specific test file
dart test test/integration/reactive_client_integration_test.dart

# Run Phase 2 tests only
dart test test/integration/ --tags phase-2
```

## Troubleshooting

### Workflow not triggering
- Ensure workflow is **Active** (toggle in top-right)
- Check webhook path matches exactly (`/test/simple` not `/test-simple`)
- Verify n8n cloud instance URL is correct

### Webhook ID not working
- Copy the full webhook URL from n8n
- Extract only the ID part after `/webhook/`
- Example: `https://kinly.app.n8n.cloud/webhook/abc123def456` → use `abc123def456`

### Import fails
- Ensure you're using n8n version 1.0+
- Try manual creation if import doesn't work
- Check JSON file is valid (not corrupted)

### Tests timing out
- Verify n8n cloud instance is accessible
- Check internet connection
- Increase timeout in `.env.test`: `TEST_TIMEOUT_SECONDS=600`

## Files

- `1_simple_webhook.json` - Simple webhook workflow
- `2_wait_node_webhook.json` - Wait node workflow
- `3_slow_webhook.json` - Slow execution workflow
- `4_error_webhook.json` - Error testing workflow
- `README.md` - This file

## Support

See main integration test documentation:
- `test/integration/README.md` - Complete integration test guide
- `test/integration/docs/INTEGRATION_TESTS_PLAN.md` - Full test plan

For n8n-specific help: https://docs.n8n.io/
