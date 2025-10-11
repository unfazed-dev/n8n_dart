# External Credentials Requirements for Template Testing

**Date:** October 7, 2025  
**Purpose:** Complete list of external service credentials needed to execute all 8 pre-built workflow templates

---

## 📋 Summary

To fully test all 8 pre-built workflow templates with execution on n8n cloud, we would need credentials for **6 different external services**:

1. ✅ **n8n Cloud** (we have this)
2. ✅ **PostgreSQL Database** (we have Supabase!)
3. ❌ **Email Service (SMTP)**
4. ❌ **Stripe Payment API**
5. ❌ **Cloud Storage (S3 or Google Drive)**
6. ❌ **Google Sheets API**

**Current Status (v1.1.0):** With Supabase credentials available, we can now execute **3 templates fully** and **4 templates partially** (database operations)!

---

## 🔐 Detailed Credential Requirements by Template

### 1. CRUD API Template (`WorkflowTemplates.crudApi()`)

**Template:** REST API with Create/Read/Update/Delete operations

**Required Credentials:**
- ✅ **PostgreSQL Database** (Supabase available!)
  - Host/IP address
  - Port (default: 5432)
  - Database name
  - Username
  - Password
  - SSL mode (optional)

**Nodes Using This Service:**
- `Postgres` node (5 instances: CREATE, READ, UPDATE, DELETE, route logic)

**Why Needed:**
- All CRUD operations perform database queries
- INSERT, SELECT, UPDATE, DELETE operations
- Cannot execute without database connection

**Setup Complexity:** Medium
- Need to provision PostgreSQL instance (cloud or local)
- Create test database and tables
- Configure connection credentials

---

### 2. User Registration Template (`WorkflowTemplates.userRegistration()`)

**Template:** User signup with email verification

**Required Credentials:**
- ✅ **PostgreSQL Database** (Supabase available!)
- ❌ **Email Service (SMTP)**
  - SMTP server host
  - SMTP port (465 for SSL, 587 for TLS)
  - Username/email address
  - Password or API key
  - From address
  - TLS/SSL settings

**Nodes Using These Services:**
- `Postgres` node - Store user data
- `Email Send` node - Send confirmation email
- `Email Send` node - Send welcome email

**Why Needed:**
- User data stored in database
- Confirmation email sent to user
- Welcome email after verification

**Setup Complexity:** High
- PostgreSQL (same as CRUD API)
- Email service (Gmail, SendGrid, Mailgun, AWS SES, etc.)
- Configure email templates
- Handle email deliverability

---

### 3. File Upload Template (`WorkflowTemplates.fileUpload()`)

**Template:** File upload processing with validation and storage

**Required Credentials:**
- ✅ **PostgreSQL Database** (Supabase available!)
- ❌ **Cloud Storage: AWS S3 OR Google Drive**

**Option A: AWS S3**
  - AWS Access Key ID
  - AWS Secret Access Key
  - S3 Bucket name
  - AWS Region
  - (Optional) S3 endpoint for custom configurations

**Option B: Google Drive**
  - Google OAuth 2.0 credentials
  - Client ID
  - Client Secret
  - Refresh token
  - Folder ID (where files will be stored)

**Nodes Using These Services:**
- `Function` node - File validation (size, type)
- `S3` OR `Google Drive` node - File storage
- `Postgres` node - Store file metadata (filename, size, URL)

**Why Needed:**
- Files uploaded to cloud storage
- File metadata stored in database
- Cannot store files without cloud storage

**Setup Complexity:** High
- PostgreSQL (same as CRUD API)
- AWS account + S3 bucket setup OR Google account + Drive API setup
- Configure storage permissions
- Handle file uploads/downloads

---

### 4. Order Processing Template (`WorkflowTemplates.orderProcessing()`)

**Template:** E-commerce order workflow with payment

**Required Credentials:**
- ✅ **PostgreSQL Database** (Supabase available!)
- ❌ **Stripe Payment API**
  - Stripe API key (Secret key)
  - Stripe Publishable key
  - Webhook signing secret (optional for webhooks)
- ❌ **Email Service (SMTP)** (same as User Registration)

**Nodes Using These Services:**
- `Postgres` node - Check inventory, store order
- `Stripe` node - Process payment
- `Email Send` node - Order confirmation email

**Why Needed:**
- Order data stored in database
- Payment processed via Stripe
- Confirmation email sent to customer

**Setup Complexity:** Very High
- PostgreSQL (same as CRUD API)
- Stripe account (test mode acceptable)
- Email service (same as User Registration)
- Configure payment flow
- Handle payment webhooks
- Test payment scenarios

---

### 5. Multi-Step Form Template (`WorkflowTemplates.multiStepForm()`)

**Template:** Interactive multi-step forms with user input

**Required Credentials:**
- ✅ **PostgreSQL Database** (Supabase available!)

**Nodes Using This Service:**
- `Wait` node (multiple instances) - Collect user input at each step
- `Function` node - Process form data
- `Postgres` node - Store final form submission

**Why Needed:**
- Wait nodes collect form data from users
- Final submission stored in database
- Cannot store data without database

**Setup Complexity:** Medium
- PostgreSQL (same as CRUD API)
- Configure wait node forms
- Test multi-step flow

**⭐ Key Feature:** This template can now be **fully executed** with Supabase! Tests wait nodes + database storage - a critical test case!

---

### 6. Scheduled Report Template (`WorkflowTemplates.scheduledReport()`)

**Template:** Automated report generation and delivery

**Required Credentials:**
- ✅ **PostgreSQL Database** (Supabase available!)
- ❌ **Email Service (SMTP)** (same as User Registration)
- ❌ **Google Sheets API**
  - Google OAuth 2.0 credentials
  - Client ID
  - Client Secret
  - Refresh token
  - Spreadsheet ID
  - Sheet name

**Nodes Using These Services:**
- `Schedule` node - Cron trigger (no credentials needed)
- `Postgres` node - Query data for report
- `Function` node - Format report data
- `Email Send` node - Send report via email
- `Google Sheets` node - Export to spreadsheet

**Why Needed:**
- Report data queried from database
- Report sent via email
- Report exported to Google Sheets

**Setup Complexity:** Very High
- PostgreSQL (same as CRUD API)
- Email service (same as User Registration)
- Google Cloud Console project setup
- Enable Google Sheets API
- OAuth flow configuration
- Configure spreadsheet access

---

### 7. Data Sync Template (`WorkflowTemplates.dataSync()`)

**Template:** Bi-directional data synchronization

**Required Credentials:**
- ✅ **PostgreSQL Database** (Supabase available!)

**Nodes Using This Service:**
- `Schedule` OR `Webhook` node - Trigger sync (no credentials needed)
- `HTTP Request` node - Fetch source data (may need API key depending on source)
- `Function` node - Transform data
- `Postgres` node - Sync to destination database

**Why Needed:**
- Source data may require API credentials
- Destination data stored in PostgreSQL
- Sync operations require database access

**Setup Complexity:** Medium-High
- PostgreSQL (same as CRUD API)
- Source API credentials (if fetching from external API)
- Configure data transformation logic
- Handle sync conflicts

---

### 8. Webhook Logger Template (`WorkflowTemplates.webhookLogger()`)

**Template:** Log incoming webhook events to Google Sheets

**Required Credentials:**
- ❌ **Google Sheets API** (same as Scheduled Report)

**Nodes Using This Service:**
- `Webhook` node - Receive events (no credentials needed)
- `Function` node - Format log entry (no credentials needed)
- `Google Sheets` node - Append to log sheet
- `Respond to Webhook` node - Send acknowledgment (no credentials needed)

**Why Needed:**
- Log data appended to Google Sheets
- Cannot log without Sheets access

**Setup Complexity:** High
- Google Cloud Console project setup (same as Scheduled Report)
- Enable Google Sheets API
- OAuth flow configuration
- Configure spreadsheet access

---

## 📊 Credential Summary Matrix

| Template | PostgreSQL | Email (SMTP) | Stripe | S3/Drive | Google Sheets |
|----------|------------|--------------|--------|----------|---------------|
| 1. CRUD API | ✅ | ❌ | ❌ | ❌ | ❌ |
| 2. User Registration | ✅ | ✅ | ❌ | ❌ | ❌ |
| 3. File Upload | ✅ | ❌ | ❌ | ✅ (choose one) | ❌ |
| 4. Order Processing | ✅ | ✅ | ✅ | ❌ | ❌ |
| 5. Multi-Step Form | ✅ | ❌ | ❌ | ❌ | ❌ |
| 6. Scheduled Report | ✅ | ✅ | ❌ | ❌ | ✅ |
| 7. Data Sync | ✅ | ❌ | ❌ | ❌ | ❌ |
| 8. Webhook Logger | ❌ | ❌ | ❌ | ❌ | ✅ |

**Total Unique Services Required:**
- **PostgreSQL:** 7 out of 8 templates (87.5%)
- **Email (SMTP):** 3 out of 8 templates (37.5%)
- **Google Sheets:** 2 out of 8 templates (25%)
- **Stripe:** 1 out of 8 templates (12.5%)
- **S3/Google Drive:** 1 out of 8 templates (12.5%)

---

## 💰 Cost Estimation

### Free Tier Options

**PostgreSQL:**
- ✅ **ElephantSQL** - Free tier (20 MB database)
- ✅ **Supabase** - Free tier (500 MB database, 2 GB bandwidth)
- ✅ **Neon** - Free tier (3 GB storage)
- ✅ **Local PostgreSQL** - Completely free

**Email (SMTP):**
- ✅ **SendGrid** - Free tier (100 emails/day)
- ✅ **Mailgun** - Free tier (100 emails/day for 3 months)
- ✅ **Gmail SMTP** - Free (with limitations)

**Stripe:**
- ✅ **Stripe Test Mode** - Completely free (no real payments)

**Google Sheets:**
- ✅ **Google Sheets API** - Free (with rate limits)
- ✅ **Google Drive API** - Free (15 GB storage)

**AWS S3:**
- ✅ **AWS Free Tier** - 5 GB storage, 20,000 GET requests, 2,000 PUT requests (first 12 months)
- ⚠️ After free tier: ~$0.023 per GB/month

### Estimated Monthly Cost (After Free Tiers)
- PostgreSQL: $0 (free tier) or $5-15/month (paid)
- Email: $0 (free tier) or $10-15/month (paid)
- Stripe: $0 (test mode only)
- Google Sheets: $0 (free)
- Google Drive: $0 (free tier)
- AWS S3: ~$1-5/month (depending on usage)

**Total:** $0-35/month (if using paid services)  
**Free Option Total:** $0/month (using free tiers)

---

## 🔧 Setup Effort Estimate

### Quick Setup (1-2 hours)
- ✅ **PostgreSQL** (ElephantSQL or local Docker)
- ✅ **Stripe Test Mode** (account creation + API keys)

### Medium Setup (2-4 hours)
- ⚠️ **Email SMTP** (SendGrid setup + API key + sender verification)
- ⚠️ **Google Sheets** (Google Cloud Console + OAuth setup)

### Complex Setup (4-8 hours)
- ⚠️ **AWS S3** (AWS account + bucket creation + IAM permissions)
- ⚠️ **Google Drive** (Google Cloud Console + OAuth + folder permissions)

**Total Setup Time:** 7-14 hours for all services

---

## ✅ Recommended Minimal Setup

To test the **most templates** with **minimal effort**, set up:

**Priority 1: PostgreSQL** (Required by 7/8 templates)
- Enables: CRUD API, User Registration, File Upload, Order Processing, Multi-Step Form, Scheduled Report, Data Sync
- Recommendation: **ElephantSQL** (free tier, cloud-hosted, no setup)
- Alternative: **Local Docker PostgreSQL** (completely free)

**Priority 2: Email (SMTP)** (Required by 3/8 templates)
- Enables: User Registration, Order Processing, Scheduled Report
- Recommendation: **SendGrid** (free tier: 100 emails/day)
- Alternative: **Gmail SMTP** (free, but requires app password)

**Priority 3: Stripe Test Mode** (Required by 1/8 template)
- Enables: Order Processing
- Recommendation: **Stripe Test Mode** (completely free)

**Priority 4: Google Sheets** (Required by 2/8 templates)
- Enables: Scheduled Report, Webhook Logger
- Recommendation: **Google Sheets API** (free, but OAuth setup is complex)

**With Priority 1-3:** Can test 7/8 templates (87.5% coverage)  
**With All 4:** Can test 8/8 templates (100% coverage)

---

## 🚀 Quick Start Guide (If We Want Full Testing)

### Step 1: PostgreSQL (5 minutes)
```bash
# Option A: ElephantSQL (cloud)
1. Go to https://www.elephantsql.com/
2. Sign up for free account
3. Create "Tiny Turtle" instance (free)
4. Copy connection string

# Option B: Local Docker (local)
docker run --name test-postgres \
  -e POSTGRES_PASSWORD=testpassword \
  -p 5432:5432 \
  -d postgres:15

# Create test database
CREATE DATABASE n8n_test;
CREATE TABLE users (id SERIAL PRIMARY KEY, name TEXT, email TEXT);
CREATE TABLE files (id SERIAL PRIMARY KEY, filename TEXT, size INT, url TEXT);
CREATE TABLE orders (id SERIAL PRIMARY KEY, total DECIMAL, status TEXT);
```

### Step 2: Email SMTP (10 minutes)
```bash
# SendGrid
1. Sign up at https://sendgrid.com/
2. Create API key
3. Verify sender email
4. Note: SMTP host (smtp.sendgrid.net), port (587), username (apikey), password (API key)
```

### Step 3: Stripe (2 minutes)
```bash
# Stripe Test Mode
1. Sign up at https://stripe.com/
2. Get test API keys from dashboard
3. Use test mode only (no real payments)
```

### Step 4: Google Sheets (20 minutes - most complex)
```bash
# Google Cloud Console
1. Create project at https://console.cloud.google.com/
2. Enable Google Sheets API
3. Create OAuth 2.0 credentials
4. Download credentials JSON
5. Run OAuth flow to get refresh token
6. Create test spreadsheet, note spreadsheet ID
```

**Total Time:** ~40 minutes for all services

---

## 📝 Credential Storage Format

**Recommended: `.env.integration` file**

```bash
# n8n Cloud
N8N_BASE_URL=https://kinly.app.n8n.cloud
N8N_API_KEY=your-n8n-api-key

# PostgreSQL
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DATABASE=n8n_test
POSTGRES_USER=postgres
POSTGRES_PASSWORD=testpassword

# Email (SendGrid)
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USER=apikey
SMTP_PASSWORD=your-sendgrid-api-key
SMTP_FROM=test@yourdomain.com

# Stripe
STRIPE_API_KEY=sk_test_your_test_key_here

# Google Sheets
GOOGLE_SHEETS_CLIENT_ID=your-client-id
GOOGLE_SHEETS_CLIENT_SECRET=your-client-secret
GOOGLE_SHEETS_REFRESH_TOKEN=your-refresh-token
GOOGLE_SHEETS_SPREADSHEET_ID=your-spreadsheet-id

# AWS S3 (optional)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_S3_BUCKET=your-bucket-name
AWS_REGION=us-east-1

# Google Drive (optional - alternative to S3)
GOOGLE_DRIVE_CLIENT_ID=your-client-id
GOOGLE_DRIVE_CLIENT_SECRET=your-client-secret
GOOGLE_DRIVE_REFRESH_TOKEN=your-refresh-token
GOOGLE_DRIVE_FOLDER_ID=your-folder-id
```

---

## ⚠️ Security Considerations

**DO NOT:**
- ❌ Commit credentials to Git
- ❌ Share credentials in public channels
- ❌ Use production credentials for testing
- ❌ Hardcode credentials in test files

**DO:**
- ✅ Use `.env.integration` file (add to `.gitignore`)
- ✅ Use test/development credentials only
- ✅ Rotate credentials periodically
- ✅ Use environment variables in CI/CD
- ✅ Use Stripe test mode (no real payments)
- ✅ Use separate test database (not production)

---

## 🎯 Recommendation

**Current Setup (v1.1.0):**
- ✅ **n8n cloud credentials** available
- ✅ **Supabase (PostgreSQL) credentials** available!
- ✅ Can execute **3 templates fully** (CRUD API, Multi-Step Form, Data Sync)
- ✅ Can execute **4 templates partially** (database operations only)
- ✅ Can validate all **8 templates** (JSON generation + structure)

**What This Enables:**
- ✅ Real database operations testing (INSERT, UPDATE, DELETE, SELECT)
- ✅ Multi-Step Form with wait nodes + database storage
- ✅ 7/8 templates test database integration
- ✅ Significantly better test coverage than JSON-only

**For Future (Optional Enhancements):**
- Add **Email SMTP** (enables full execution for 4 templates)
- Consider **Stripe test mode** (enables payment in Order Processing)
- Optional: **Google Sheets** (enables Webhook Logger + Scheduled Report export)
- Optional: **Cloud Storage** (enables File Upload)

**Estimated Effort to Enable All Templates:**
- Setup time: ~30-40 minutes (Supabase already set up!)
- Additional time: ~1-2 hours for remaining services
- Monthly cost: $0 (using free tiers)
- Complexity: Low-Medium (Google Sheets OAuth is hardest part)

---

**Current Status:** ✅ **Supabase credentials available!** Can execute 3 templates fully and test database operations for 7/8 templates.

**Impact:** Significantly improved test coverage - moved from JSON-only validation to real database execution testing!

