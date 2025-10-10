# CI/CD Setup Guide

This guide explains how to set up and maintain CI/CD integration for n8n_dart integration tests using GitHub Actions.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [GitHub Secrets Configuration](#github-secrets-configuration)
- [Workflow Configuration](#workflow-configuration)
- [Environment Management](#environment-management)
- [Test Reporting](#test-reporting)
- [Performance Tracking](#performance-tracking)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Overview

The n8n_dart integration test suite runs automatically on:
- **Pull requests** to `master`, `main`, or `develop` branches
- **Pushes** to `master` or `main` branches
- **Manual trigger** via GitHub Actions UI
- **Nightly schedule** at 2 AM UTC for continuous validation

### Workflow Architecture

```
┌─────────────────┐
│  Unit Tests     │ ← Fast feedback (< 2 min)
└────────┬────────┘
         │ ✓ Pass
         ▼
┌─────────────────┐
│ Environment     │ ← Validate config & credentials
│ Validation      │
└────────┬────────┘
         │ ✓ Valid
         ▼
┌─────────────────┐
│ Workflow        │ ← Verify n8n workflows exist
│ Verification    │
└────────┬────────┘
         │ ✓ Ready
         ▼
┌─────────────────┐
│ Integration     │ ← Run all integration tests
│ Tests           │   (< 20 min target)
└────────┬────────┘
         │ ✓ Complete
         ▼
┌─────────────────┐
│ Report &        │ ← Generate HTML report
│ Cleanup         │   Upload artifacts
│                 │   Post PR comment
│                 │   Cleanup old executions
└─────────────────┘
```

## Prerequisites

### 1. n8n Cloud Instance

You need an n8n cloud instance with:
- Active subscription
- API access enabled
- Test workflows deployed

### 2. Test Workflows

Deploy these 4 test workflows to your n8n cloud instance:

| Workflow | Webhook Path | Purpose |
|----------|--------------|---------|
| Simple Test | `/test/simple` | Basic execution test |
| Wait Node Test | `/test/wait-node` | Wait node functionality |
| Slow Test | `/test/slow` | Timeout handling |
| Error Test | `/test/error` | Error scenarios |

**See [test/integration/docs/TEST_WORKFLOWS.md](./TEST_WORKFLOWS.md) for workflow definitions.**

### 3. GitHub Repository Access

You need:
- Admin access to the GitHub repository
- Ability to add secrets
- GitHub Actions enabled

## GitHub Secrets Configuration

### Required Secrets

Add these secrets in **Settings → Secrets and variables → Actions**:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `N8N_BASE_URL` | Your n8n cloud instance URL | `https://yourinstance.app.n8n.cloud` |
| `N8N_API_KEY` | n8n API key for authentication | `n8n_api_xxxxxxxxxxxxx` |

### Optional Secrets (Recommended)

Pre-configure workflow IDs to avoid auto-discovery overhead:

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `N8N_SIMPLE_WORKFLOW_ID` | Simple workflow ID | From n8n UI or API |
| `N8N_WAIT_NODE_WORKFLOW_ID` | Wait node workflow ID | From n8n UI or API |
| `N8N_SLOW_WORKFLOW_ID` | Slow workflow ID | From n8n UI or API |
| `N8N_ERROR_WORKFLOW_ID` | Error workflow ID | From n8n UI or API |

**If not provided, workflow IDs will be auto-discovered by webhook path** (requires API key).

### Getting Workflow IDs

**Option 1: Using verify_workflows script**
```bash
dart run test/integration/utils/verify_workflows.dart
```

**Option 2: From n8n UI**
1. Open workflow in n8n editor
2. Workflow ID is in the URL: `...app.n8n.cloud/workflow/{ID}`

**Option 3: Using n8n API**
```bash
curl -H "X-N8N-API-KEY: your-api-key" \
  https://yourinstance.app.n8n.cloud/api/v1/workflows
```

### Adding Secrets

```bash
# Using GitHub CLI
gh secret set N8N_BASE_URL -b "https://yourinstance.app.n8n.cloud"
gh secret set N8N_API_KEY -b "n8n_api_xxxxxxxxxxxxx"

# Or via GitHub UI:
# 1. Navigate to: Settings → Secrets and variables → Actions
# 2. Click "New repository secret"
# 3. Enter name and value
# 4. Click "Add secret"
```

## Workflow Configuration

### Workflow File Location

[`.github/workflows/integration-tests.yml`](/.github/workflows/integration-tests.yml)

### Environment Variables

The workflow uses these environment variables:

```yaml
env:
  DART_VERSION: '3.2.0'
  TEST_TIMEOUT_SECONDS: 300
  TEST_MAX_RETRIES: 3
  TEST_POLLING_INTERVAL_MS: 2000
  CI_RUN_INTEGRATION_TESTS: true
  CI_SKIP_SLOW_TESTS: false
```

### Customizing Behavior

**Skip slow tests for faster feedback:**
```yaml
# Trigger manually with skip_slow_tests=true
workflow_dispatch:
  inputs:
    skip_slow_tests:
      description: 'Skip slow tests'
      required: false
      type: boolean
      default: false
```

**Adjust timeouts:**
```yaml
env:
  TEST_TIMEOUT_SECONDS: 600  # Increase to 10 minutes
```

**Change schedule:**
```yaml
schedule:
  - cron: '0 6 * * *'  # Run at 6 AM UTC instead
```

## Environment Management

### Validation Script

The [`validate_environment.dart`](../utils/validate_environment.dart) script runs before tests to ensure:

- All required environment variables are set
- Configuration is valid
- API credentials work
- Workflow configuration is complete

**Manual validation:**
```bash
cd test/integration
dart run utils/validate_environment.dart
```

**Expected output:**
```
🔍 Validating integration test environment...

Environment: CI/CD
✅ Configuration loaded successfully
   Base URL: https://yourinstance.app.n8n.cloud
   API Key: ***configured***
   Timeout: 300s
   Polling interval: 2000ms

✅ Configuration is valid
✅ All workflow IDs configured
✅ Supabase credentials configured
✅ Environment validation PASSED

✨ Ready to run integration tests!
```

### Workflow Verification

The [`verify_workflows.dart`](../utils/verify_workflows.dart) script verifies:

- All test workflows exist on n8n cloud
- Workflows are active (not paused)
- Webhook paths match configuration
- Webhook triggers are properly configured

**Manual verification:**
```bash
cd test/integration
dart run utils/verify_workflows.dart
```

## Test Reporting

### HTML Report Generation

The [`generate_report.dart`](../utils/generate_report.dart) script creates an HTML report with:

- Test execution summary
- Pass/fail statistics
- Individual test results
- Error details and stack traces
- Execution time metrics

Reports are generated automatically after test runs and uploaded as GitHub Actions artifacts.

### Viewing Reports

**Option 1: GitHub UI**
1. Go to Actions tab
2. Click on the workflow run
3. Scroll to "Artifacts" section
4. Download `integration-test-report`
5. Open `test-report.html` in browser

**Option 2: Direct artifact download**
```bash
# Using GitHub CLI
gh run download <run-id> -n integration-test-report
open test-report.html
```

### PR Comments

Test results are automatically posted as comments on pull requests:

```markdown
## 🧪 Integration Test Results

⏱️ **Execution Time:** 15m 32s
🎯 **Target:** < 20 minutes

📄 **Full Report:** Available in workflow artifacts
```

## Performance Tracking

### Execution Time Monitoring

The workflow tracks:
- Total test execution time
- Target threshold (20 minutes)
- Warning if threshold exceeded

### Metrics Collection

Test metrics are saved to `test-metrics.json`:

```json
{
  "execution_time_seconds": 932,
  "timestamp": "2025-10-10T12:34:56Z"
}
```

### Performance Trends

**To integrate with monitoring service:**

1. Modify the `performance-tracking` job in `.github/workflows/integration-tests.yml`
2. Add your monitoring service integration
3. Example with custom service:

```yaml
- name: Track performance trends
  run: |
    # Send metrics to monitoring service
    curl -X POST https://monitoring.example.com/metrics \
      -H "Content-Type: application/json" \
      -d @test-metrics.json
```

### Performance Alerts

Current thresholds:
- ⚠️ Warning: > 20 minutes (1200 seconds)
- 🎯 Target: < 20 minutes

## Maintenance

### Cleanup Old Executions

The [`cleanup_executions.dart`](../utils/cleanup_executions.dart) script automatically:
- Runs after each test execution
- Deletes executions older than 7 days (configurable)
- Prevents accumulation of test data

**Manual cleanup:**
```bash
cd test/integration
MAX_EXECUTIONS_AGE_DAYS=14 dart run utils/cleanup_executions.dart
```

**Configure cleanup in workflow:**
```yaml
env:
  MAX_EXECUTIONS_AGE_DAYS: 14  # Keep last 14 days
```

### Test Maintenance Checklist

**Monthly:**
- [ ] Review test execution times
- [ ] Check for flaky tests
- [ ] Update workflow versions (actions)
- [ ] Verify n8n cloud credentials rotation

**Quarterly:**
- [ ] Review test coverage
- [ ] Update test workflows if n8n API changed
- [ ] Optimize slow tests
- [ ] Clean up old artifacts

**Annually:**
- [ ] Review overall test strategy
- [ ] Update documentation
- [ ] Audit security (secrets, permissions)

## Troubleshooting

### Common Issues

#### 1. Tests Failing: "Invalid API key"

**Symptoms:**
```
❌ Environment validation FAILED
   API key: ❌ missing or invalid
```

**Solution:**
1. Verify `N8N_API_KEY` secret is set correctly
2. Check if API key has expired
3. Regenerate API key in n8n cloud settings

#### 2. Tests Failing: "Workflow not found"

**Symptoms:**
```
❌ Workflow verification FAILED
   test/simple → NOT FOUND
```

**Solution:**
1. Check if test workflows are deployed to n8n cloud
2. Verify webhook paths match configuration
3. Ensure workflows are active (not paused)
4. Run manual verification:
   ```bash
   dart run test/integration/utils/verify_workflows.dart
   ```

#### 3. Tests Timeout

**Symptoms:**
```
❌ Test execution exceeded 30 minutes
```

**Solution:**
1. Check n8n cloud instance performance
2. Increase timeout in workflow:
   ```yaml
   timeout-minutes: 45  # Increase from 30
   ```
3. Enable slow test skipping:
   ```yaml
   CI_SKIP_SLOW_TESTS: true
   ```

#### 4. Artifacts Not Uploading

**Symptoms:**
```
Error: Unable to upload artifact
```

**Solution:**
1. Check GitHub Actions storage quota
2. Verify artifact retention days:
   ```yaml
   retention-days: 7  # Reduce from 30
   ```
3. Check file permissions

#### 5. PR Comments Not Posting

**Symptoms:**
- No test results comment on PR

**Solution:**
1. Verify `GITHUB_TOKEN` has correct permissions
2. Check workflow permissions in repository settings:
   - Settings → Actions → General → Workflow permissions
   - Enable "Read and write permissions"

### Debug Mode

Enable verbose logging in workflow:

```yaml
- name: Run integration tests
  run: |
    dart test --verbose --tags=integration test/integration/
  env:
    # Add debug flags
    DEBUG: true
    LOG_LEVEL: debug
```

### Manual Test Execution

Run tests locally to debug:

```bash
# Set environment variables
export N8N_BASE_URL="https://yourinstance.app.n8n.cloud"
export N8N_API_KEY="your-api-key"

# Run validation
dart run test/integration/utils/validate_environment.dart

# Run verification
dart run test/integration/utils/verify_workflows.dart

# Run tests
dart test --tags=integration test/integration/
```

### Getting Help

1. **Check logs:**
   - Actions tab → Click workflow run → View logs

2. **Review test output:**
   - Download test report artifact
   - Check detailed error messages

3. **Consult documentation:**
   - [Integration Tests Plan](./INTEGRATION_TESTS_PLAN.md)
   - [Test Workflows](./TEST_WORKFLOWS.md)
   - [README](../README.md)

4. **Report issues:**
   - File issue on GitHub with:
     - Workflow run URL
     - Error messages
     - Environment details

## Best Practices

### Security

- ✅ Never commit secrets to repository
- ✅ Rotate API keys regularly
- ✅ Use minimal required permissions
- ✅ Audit secret access logs

### Performance

- ✅ Run unit tests before integration tests
- ✅ Skip slow tests in PR checks (optional)
- ✅ Run full suite nightly
- ✅ Monitor execution time trends

### Reliability

- ✅ Use retry logic for flaky tests
- ✅ Implement circuit breaker pattern
- ✅ Clean up test data regularly
- ✅ Verify workflows before tests

### Maintainability

- ✅ Document all configuration changes
- ✅ Keep workflow version up-to-date
- ✅ Review and optimize tests regularly
- ✅ Monitor test coverage

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [n8n API Documentation](https://docs.n8n.io/api/)
- [Dart Testing Documentation](https://dart.dev/guides/testing)
- [Integration Tests Plan](./INTEGRATION_TESTS_PLAN.md)

## Support

For questions or issues:
1. Check [Troubleshooting](#troubleshooting) section
2. Review workflow logs
3. Consult [Integration Tests Plan](./INTEGRATION_TESTS_PLAN.md)
4. File GitHub issue with details
