# Supabase Integration Setup for n8n_dart Tests

**Status:** ✅ Supabase credentials available  
**Impact:** Enables execution testing for 3+ templates!  
**Date:** October 7, 2025

---

## 🎯 What This Enables

With Supabase (PostgreSQL) credentials, we can now:

**✅ Full Execution Testing (3 templates):**
1. **CRUD API** - Complete REST API with database operations
2. **Multi-Step Form** - Interactive forms with wait nodes + database storage
3. **Data Sync** - Bi-directional data synchronization with PostgreSQL

**⚠️ Partial Execution Testing (4 templates):**
4. **User Registration** - Database operations ✅ | Email ❌
5. **File Upload** - Metadata storage ✅ | File storage ❌
6. **Order Processing** - Inventory/orders ✅ | Payment ❌ Email ❌
7. **Scheduled Report** - Data queries ✅ | Email ❌ Sheets ❌

**❌ JSON Validation Only (1 template):**
8. **Webhook Logger** - Needs Google Sheets

---

## 🔐 Supabase Credentials Configuration

### Environment Variables

Add to `.env.test`:

```bash
# Supabase PostgreSQL Connection
SUPABASE_HOST=aws-0-us-east-1.pooler.supabase.com
SUPABASE_PORT=6543
SUPABASE_DATABASE=postgres
SUPABASE_USER=postgres.xxxxxxxxxxxxx
SUPABASE_PASSWORD=your-password-here
SUPABASE_SSL_MODE=require

# Alternative: Connection String
SUPABASE_CONNECTION_STRING=postgresql://postgres.xxxxx:password@aws-0-us-east-1.pooler.supabase.com:6543/postgres
```

### n8n Cloud Configuration

In n8n workflow PostgreSQL node credentials:
- **Host:** `aws-0-us-east-1.pooler.supabase.com`
- **Database:** `postgres`
- **User:** `postgres.xxxxxxxxxxxxx`
- **Password:** `[your-password]`
- **Port:** `6543` (connection pooling - recommended)
- **SSL:** `require` or `prefer`

---

## 📊 Database Schema Setup

Run these SQL commands in Supabase SQL Editor:

```sql
-- ========================================
-- Schema for CRUD API Template
-- ========================================
CREATE TABLE IF NOT EXISTS api_resources (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  data JSONB,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- ========================================
-- Schema for User Registration Template
-- ========================================
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  email_verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ========================================
-- Schema for File Upload Template
-- ========================================
CREATE TABLE IF NOT EXISTS files (
  id SERIAL PRIMARY KEY,
  filename TEXT NOT NULL,
  original_name TEXT,
  size INTEGER,
  mime_type TEXT,
  url TEXT,
  user_id INTEGER REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

-- ========================================
-- Schema for Order Processing Template
-- ========================================
CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  total DECIMAL(10, 2) NOT NULL,
  status TEXT DEFAULT 'pending',
  items JSONB,
  payment_id TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory (
  id SERIAL PRIMARY KEY,
  product_name TEXT NOT NULL,
  quantity INTEGER DEFAULT 0,
  price DECIMAL(10, 2)
);

-- ========================================
-- Schema for Multi-Step Form Template
-- ========================================
CREATE TABLE IF NOT EXISTS form_submissions (
  id SERIAL PRIMARY KEY,
  step_1_data JSONB,
  step_2_data JSONB,
  step_3_data JSONB,
  final_data JSONB,
  completed BOOLEAN DEFAULT false,
  user_email TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
);

-- ========================================
-- Schema for Scheduled Report Template
-- ========================================
CREATE TABLE IF NOT EXISTS analytics_data (
  id SERIAL PRIMARY KEY,
  metric_name TEXT NOT NULL,
  metric_value NUMERIC,
  date DATE DEFAULT CURRENT_DATE,
  metadata JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- ========================================
-- Schema for Data Sync Template
-- ========================================
CREATE TABLE IF NOT EXISTS sync_data (
  id SERIAL PRIMARY KEY,
  external_id TEXT UNIQUE,
  data JSONB NOT NULL,
  source TEXT,
  last_synced_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_data_external_id ON sync_data(external_id);
CREATE INDEX IF NOT EXISTS idx_sync_data_last_synced ON sync_data(last_synced_at);

-- ========================================
-- Test Data (Optional)
-- ========================================

-- Sample users
INSERT INTO users (name, email, password_hash, email_verified) VALUES
('Test User 1', 'test1@example.com', '$2a$10$examplehash1', true),
('Test User 2', 'test2@example.com', '$2a$10$examplehash2', true)
ON CONFLICT (email) DO NOTHING;

-- Sample inventory
INSERT INTO inventory (product_name, quantity, price) VALUES
('Product A', 100, 29.99),
('Product B', 50, 49.99),
('Product C', 75, 19.99)
ON CONFLICT DO NOTHING;

-- Sample analytics data
INSERT INTO analytics_data (metric_name, metric_value, metadata) VALUES
('daily_users', 150, '{"source": "web"}'),
('revenue', 2500.50, '{"currency": "USD"}'),
('conversions', 45, '{"funnel": "signup"}')
ON CONFLICT DO NOTHING;
```

---

## 🧪 Test Workflow Configurations

### 1. CRUD API Template - Full Execution

**What to Test:**
- Create new resource via webhook
- Read resource by ID
- Update existing resource
- Delete resource
- List all resources

**n8n Workflow Setup:**
1. Generate workflow: `WorkflowTemplates.crudApi(resourceName: 'users', tableName: 'api_resources')`
2. Import JSON to n8n cloud
3. Configure PostgreSQL credentials (Supabase)
4. Test each CRUD operation via webhook

**Expected Result:** All database operations succeed

---

### 2. Multi-Step Form Template - Full Execution ⭐

**What to Test:**
- Webhook triggers form
- Wait node 1: Collect step 1 data
- Resume workflow with step 1 input
- Wait node 2: Collect step 2 data
- Resume workflow with step 2 input
- Wait node 3: Collect step 3 data
- Final submission stored in database

**n8n Workflow Setup:**
1. Generate workflow: `WorkflowTemplates.multiStepForm()`
2. Import JSON to n8n cloud
3. Configure PostgreSQL credentials (Supabase)
4. Configure wait node forms
5. Test multi-step flow

**Expected Result:** Form data collected at each step, final submission in database

**⭐ Key Feature:** Tests wait nodes + database = validates interactive workflows!

---

### 3. Data Sync Template - Full Execution

**What to Test:**
- Schedule trigger (or manual webhook)
- Fetch data from external source (mock HTTP endpoint)
- Transform data
- Sync to Supabase PostgreSQL
- Handle conflicts (update vs. insert)

**n8n Workflow Setup:**
1. Generate workflow: `WorkflowTemplates.dataSync()`
2. Import JSON to n8n cloud
3. Configure PostgreSQL credentials (Supabase)
4. Configure HTTP source (can use mock API)
5. Test sync operation

**Expected Result:** Data synced to database, conflicts resolved

---

### 4. User Registration Template - Partial Execution

**What Can Test:**
- ✅ Webhook receives registration data
- ✅ Password hashing (function node)
- ✅ User inserted into database
- ❌ Email confirmation (skip - no SMTP)
- ❌ Welcome email (skip - no SMTP)

**Workaround:** Comment out or disable email nodes, test database operations only

---

### 5. File Upload Template - Partial Execution

**What Can Test:**
- ✅ Webhook receives file data
- ✅ File validation (function node)
- ✅ Metadata stored in database
- ❌ File upload to S3/Drive (skip - no credentials)

**Workaround:** Mock file URL, test database metadata storage only

---

### 6. Order Processing Template - Partial Execution

**What Can Test:**
- ✅ Webhook receives order data
- ✅ Inventory check (database query)
- ✅ Order inserted into database
- ❌ Stripe payment (skip - no API key)
- ❌ Confirmation email (skip - no SMTP)

**Workaround:** Disable payment/email nodes, test order + inventory database operations

---

### 7. Scheduled Report Template - Partial Execution

**What Can Test:**
- ✅ Schedule trigger
- ✅ Database queries (fetch analytics data)
- ✅ Data transformation (function node)
- ❌ Email send (skip - no SMTP)
- ❌ Google Sheets export (skip - no API)

**Workaround:** Disable email/sheets nodes, test database queries and data transformation

---

## 📝 Integration Test Code Examples

### Test: CRUD API Full Execution

```dart
group('CRUD API Template - Full Execution with Supabase', () {
  late ReactiveN8nClient client;
  late String workflowWebhookId;
  
  setUp(() {
    client = ReactiveN8nClient(
      config: N8nConfigProfiles.production(
        baseUrl: 'https://kinly.app.n8n.cloud',
      ),
    );
    workflowWebhookId = 'crud-api-test-webhook'; // Set up in n8n cloud
  });

  test('CREATE: Insert new resource via webhook', () async {
    final data = {
      'operation': 'create',
      'name': 'Test User',
      'email': 'test@example.com',
    };
    
    final execution = await client.startWorkflow(workflowWebhookId, data).first;
    final completed = await client.pollExecutionStatus(execution.id)
        .firstWhere((e) => e.isFinished);
    
    expect(completed.status, WorkflowStatus.success);
    expect(completed.data, contains('id')); // Database returned ID
  });

  test('READ: Fetch resource by ID', () async {
    final data = {
      'operation': 'read',
      'id': 1,
    };
    
    final execution = await client.startWorkflow(workflowWebhookId, data).first;
    final completed = await client.pollExecutionStatus(execution.id)
        .firstWhere((e) => e.isFinished);
    
    expect(completed.status, WorkflowStatus.success);
    expect(completed.data, contains('name'));
    expect(completed.data, contains('email'));
  });

  // Similar tests for UPDATE and DELETE...
});
```

### Test: Multi-Step Form with Wait Nodes

```dart
group('Multi-Step Form Template - Full Execution with Wait Nodes', () {
  test('Complete multi-step form with database storage', () async {
    // Step 1: Start workflow
    final execution = await client.startWorkflow(formWebhookId, {}).first;
    
    // Step 2: Wait for wait node (step 1)
    final waiting1 = await client.pollExecutionStatus(execution.id)
        .firstWhere((e) => e.waitingForInput);
    
    expect(waiting1.waitNodeData, isNotNull);
    expect(waiting1.waitNodeData!.nodeName, contains('Step 1'));
    
    // Step 3: Resume with step 1 data
    await client.resumeWorkflow(execution.id, {
      'firstName': 'John',
      'lastName': 'Doe',
    });
    
    // Step 4: Wait for wait node (step 2)
    final waiting2 = await client.pollExecutionStatus(execution.id)
        .firstWhere((e) => e.waitingForInput);
    
    // Step 5: Resume with step 2 data
    await client.resumeWorkflow(execution.id, {
      'email': 'john@example.com',
      'phone': '555-0123',
    });
    
    // Continue for step 3...
    
    // Final: Verify completion and database storage
    final completed = await client.pollExecutionStatus(execution.id)
        .firstWhere((e) => e.isFinished);
    
    expect(completed.status, WorkflowStatus.success);
    
    // Verify data in Supabase
    // (Can query form_submissions table directly or via workflow)
  });
});
```

---

## ✅ Updated Test Coverage

**With Supabase:**

| Test Category | Before (No DB) | After (With Supabase) | Improvement |
|---------------|----------------|------------------------|-------------|
| **Full Template Execution** | 0 templates | **3 templates** | +3 ✅ |
| **Partial Template Execution** | 0 templates | **4 templates** | +4 ⚠️ |
| **Database Operations** | 0 tested | **7 templates tested** | +7 ✅ |
| **Wait Nodes** | Mock only | **Real execution** | ✅ |
| **JSON Validation** | 8 templates | 8 templates | ✅ |

**Total Tests:** 60-70 tests (unchanged)  
**Execution Tests:** 40-50 (enhanced quality - now include real database operations!)

---

## 🎯 Next Steps

1. ✅ Add Supabase credentials to `.env.test`
2. ✅ Run SQL schema setup in Supabase
3. ✅ Create 3 workflows in n8n cloud (CRUD API, Multi-Step Form, Data Sync)
4. ✅ Configure PostgreSQL credentials in n8n
5. ✅ Implement integration tests with real execution
6. ✅ Verify database operations succeed

---

**Status:** Ready to implement with Supabase!  
**Impact:** Significantly better test coverage - real database operations validated!  
**Effort:** ~30 minutes setup (credentials + schema) + implement tests

