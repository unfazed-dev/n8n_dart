# Webhook Execution ID Extraction

## Discovery

**You don't need workflow IDs for testing!**

The n8n webhook response can include the `execution_id` by using `$execution.id` in the workflow's Set node.

## How It Works

1. **Webhook triggers workflow** → n8n generates execution ID
2. **Set node includes** `execution_id: {{$execution.id}}` in response
3. **Client extracts** `execution_id` from webhook response JSON
4. **Client uses** real execution ID to poll status via REST API

## Benefits

✅ **No workflow ID needed** - Just webhook path is enough
✅ **Real execution IDs** - Not pseudo IDs
✅ **Simpler configuration** - Only need webhook paths in `.env.test`
✅ **Works with n8n cloud** - No special API access required beyond API key

## Updating Workflows

### Required: Add execution_id to Set Node

All test workflows must include `execution_id` in their Set node:

```json
{
  "parameters": {
    "values": {
      "string": [
        {
          "name": "execution_id",
          "value": "={{$execution.id}}"
        }
      ]
    }
  },
  "name": "Set",
  "type": "n8n-nodes-base.set"
}
```

### Example Workflow Structure

```
Webhook → Set (add execution_id) → Respond to Webhook
```

The response body will include:

```json
{
  "execution_id": "12345",
  "...other fields..."
}
```

## Updated .env.test Structure

Now you only need webhook paths:

```env
# Simple workflow
N8N_SIMPLE_WEBHOOK_PATH=test/simple

# Wait node workflow
N8N_WAIT_NODE_WEBHOOK_PATH=test/wait-node

# Slow workflow
N8N_SLOW_WEBHOOK_PATH=test/slow

# Error workflow
N8N_ERROR_WEBHOOK_PATH=test/error
```

**No workflow IDs required!**

## Client Implementation

The client automatically:

1. **Tries to extract** `execution_id` from webhook response
2. **Falls back to pseudo ID** if not found (for compatibility)
3. **Uses real execution ID** for polling via REST API `/api/v1/executions/{id}`

See:
- `N8nClient.startWorkflow()` - lines 87-100
- `ReactiveN8nClient._performStartWorkflow()` - lines 511-539

## Testing

After updating the workflow in n8n cloud to include `execution_id`:

1. Re-import the workflow JSON (or manually add the field)
2. Run tests: `dart test test/integration/reactive_client_integration_test.dart`
3. Tests should now pass with real execution IDs

## References

- [n8n Community Discussion](https://community.n8n.io/t/how-to-get-execution-id-of-workflow-immediately-when-we-are-calling-webhook/24947)
- [Webhook Node Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.webhook/)
- [Respond to Webhook Docs](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.respondtowebhook/)
