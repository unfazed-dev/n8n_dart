/// Example: Generating n8n Workflows Programmatically
///
/// This example demonstrates how to use the n8n_dart workflow generator
/// to create n8n workflow JSON files that can be imported into n8n.
///
/// The generator now supports automatic credential loading from .env files!

import 'dart:io';
import 'package:n8n_dart/n8n_dart.dart';

// Global credential manager instance
late CredentialManager credManager;

void main() async {
  print('🚀 n8n Workflow Generator Examples\n');

  // Initialize credential manager
  credManager = _initializeCredentials();

  // Create output directory
  final outputDir = Directory('generated_workflows');
  if (!outputDir.existsSync()) {
    outputDir.createSync();
  }

  // Example 1: Simple Webhook to Database
  await example1SimpleWebhookToDb(outputDir.path);

  // Example 2: User Registration Flow
  await example2UserRegistration(outputDir.path);

  // Example 3: Multi-Step Form
  await example3MultiStepForm(outputDir.path);

  // Example 4: Using Templates
  await example4UsingTemplates(outputDir.path);

  // Example 5: Complex Workflow with Conditionals
  await example5ComplexWorkflow(outputDir.path);

  // Example 6: Scheduled Report
  await example6ScheduledReport(outputDir.path);

  // Example 7: IoT Sensor Data Processing
  await example7IoTSensorData(outputDir.path);

  // Example 8: Social Media Monitoring
  await example8SocialMediaMonitoring(outputDir.path);

  // Example 9: Real-time Alert System
  await example9RealtimeAlerts(outputDir.path);

  // Example 10: Chatbot Integration
  await example10ChatbotIntegration(outputDir.path);

  // Example 11: Booking & Appointment System
  await example11BookingSystem(outputDir.path);

  // Example 12: Journaling & Daily Reflection
  await example12JournalingSystem(outputDir.path);

  // Example 13: Real-time Chat Application
  await example13ChatWorkflow(outputDir.path);

  // Example 14: Invoice Generation for Bookings
  await example14InvoiceWorkflow(outputDir.path);

  // Example 15: Supabase Booking System
  await example15SupabaseBooking(outputDir.path);

  // Example 16: Supabase Booking with Auto-Invoice
  await example16SupabaseBookingInvoice(outputDir.path);

  // Example 17: Stripe Payment with Supabase Booking & Invoice
  await example17StripeBookingInvoice(outputDir.path);

  print('\n✅ All workflows generated successfully!');
  print('📁 Check the "generated_workflows" directory for JSON files.');
  print('\n📤 Import these files into n8n:');
  print('   1. Open n8n UI');
  print('   2. Click "..." menu → Import from File');
  print('   3. Select the generated JSON file');
  print('   4. Configure credentials (if needed)');
  print('   5. Activate the workflow\n');
}

/// Initialize credential manager from .env file
CredentialManager _initializeCredentials() {
  print('🔐 Loading credentials...\n');

  CredentialManager manager;

  // Try to load from .env.test first, then .env
  final envTestFile = File('.env.test');
  final envFile = File('.env');

  if (envTestFile.existsSync()) {
    print('   ✓ Found .env.test file');
    manager = CredentialManager.fromEnvFile('.env.test');
  } else if (envFile.existsSync()) {
    print('   ✓ Found .env file');
    manager = CredentialManager.fromEnvFile('.env');
  } else {
    print('   ⚠️  No .env file found - using placeholder credentials');
    print('   💡 Create .env.test with your credentials for automatic setup\n');
    manager = CredentialManager();
  }

  // Print credential status
  manager.printStatus();
  print('');

  return manager;
}

/// Save workflow with credential injection
Future<void> _saveWorkflowWithCredentials(
  N8nWorkflow workflow,
  String filePath,
) async {
  // Inject real credentials from .env
  final injector = WorkflowCredentialInjector(credManager);
  final workflowWithCreds = injector.injectCredentials(workflow);

  // Check if any placeholders remain
  if (injector.hasPlaceholderCredentials(workflowWithCreds)) {
    final required = injector.getRequiredCredentials(workflowWithCreds);
    print('   ⚠️  Missing credentials: ${required.join(', ')}');
    print('   💡 Add these to .env.test for automatic configuration');
  }

  // Save to file
  await workflowWithCreds.saveToFile(filePath);
}

/// Example 1: Simple webhook that saves data to PostgreSQL
Future<void> example1SimpleWebhookToDb(String outputPath) async {
  print('📝 Example 1: Simple Webhook → Database');

  final workflow = WorkflowBuilder.create()
      .name('Simple Webhook to Database')
      .tags(['example', 'webhook', 'database'])
      .active(false)
      // Webhook trigger
      .webhookTrigger(
        name: 'Webhook Trigger',
        path: 'simple-webhook',
        method: 'POST',
      )
      // Transform data
      .function(
        name: 'Transform Data',
        code: '''
const { name, email, message } = \$input.item.json.body;

return [{
  json: {
    name,
    email,
    message,
    created_at: new Date().toISOString()
  }
}];
''',
      )
      // Save to database
      .postgres(
        name: 'Save to Database',
        operation: 'insert',
        table: 'submissions',
      )
      // Respond to webhook
      .respondToWebhook(
        name: 'Send Success Response',
        responseCode: 200,
        responseBody: {
          'status': 'success',
          'message': 'Data saved successfully',
        },
      )
      // Connect nodes in sequence
      .connectSequence([
        'Webhook Trigger',
        'Transform Data',
        'Save to Database',
        'Send Success Response',
      ])
      .build();

  // Save to file with credentials
  await _saveWorkflowWithCredentials(
    workflow,
    '$outputPath/01_simple_webhook_to_db.json',
  );
  print('   ✓ Generated: 01_simple_webhook_to_db.json\n');
}

/// Example 2: User registration with email confirmation
Future<void> example2UserRegistration(String outputPath) async {
  print('📝 Example 2: User Registration with Email');

  final workflow = WorkflowBuilder.create()
      .name('User Registration Flow')
      .tags(['auth', 'registration', 'email'])
      .active(false)
      .webhookTrigger(
        name: 'Registration Webhook',
        path: 'auth/register',
        method: 'POST',
      )
      .function(
        name: 'Validate & Hash Password',
        code: '''
const { email, password, name } = \$input.item.json.body;

// Validation
if (!email || !password || !name) {
  throw new Error('Missing required fields');
}

if (!/^[^\\s@]+@[^\\s@]+\\.[^\\s@]+\$/.test(email)) {
  throw new Error('Invalid email format');
}

// In production, use bcrypt for password hashing
const passwordHash = 'hashed_' + password;

return [{
  json: {
    email,
    name,
    password_hash: passwordHash,
    email_verified: false,
    created_at: new Date().toISOString()
  }
}];
''',
      )
      .postgres(
        name: 'Check Existing User',
        operation: 'select',
        query: r"SELECT id FROM users WHERE email = '{{$json.email}}'",
      )
      .ifNode(
        name: 'User Exists?',
        conditions: [
          {
            'leftValue': r'={{$json.length}}',
            'operation': 'largerEqual',
            'rightValue': 1,
          }
        ],
      )
      // User exists - return error
      .newRow()
      .respondToWebhook(
        name: 'Return Error',
        responseCode: 400,
        responseBody: {'error': 'User already exists'},
      )
      // User doesn't exist - create account
      .newRow()
      .postgres(
        name: 'Create User',
        operation: 'insert',
        table: 'users',
      )
      .function(
        name: 'Generate Verification Token',
        code: '''
const userId = \$input.item.json.id;
const token = Math.random().toString(36).substring(2, 15);

return [{
  json: {
    userId,
    email: \$input.item.json.email,
    name: \$input.item.json.name,
    verificationToken: token,
    verificationUrl: 'https://app.example.com/verify?token=' + token
  }
}];
''',
      )
      .emailSend(
        name: 'Send Verification Email',
        fromEmail: 'noreply@example.com',
        toEmail: r'={{$json.email}}',
        subject: 'Verify Your Email Address',
        message: r'''
Hi {{$json.name}},

Welcome to our platform! Please verify your email address by clicking the link below:

{{$json.verificationUrl}}

Best regards,
The Team
''',
      )
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 201,
        responseBody: {
          'message': 'User created successfully',
          'userId': r'={{$json.userId}}',
        },
      )
      .connect('Registration Webhook', 'Validate & Hash Password')
      .connect('Validate & Hash Password', 'Check Existing User')
      .connect('Check Existing User', 'User Exists?')
      .connect('User Exists?', 'Return Error', sourceIndex: 0)
      .connect('User Exists?', 'Create User', sourceIndex: 1)
      .connect('Create User', 'Generate Verification Token')
      .connect('Generate Verification Token', 'Send Verification Email')
      .connect('Send Verification Email', 'Return Success')
      .build();

  await workflow.saveToFile('$outputPath/02_user_registration.json');
  print('   ✓ Generated: 02_user_registration.json\n');
}

/// Example 3: Multi-step form with wait nodes
Future<void> example3MultiStepForm(String outputPath) async {
  print('📝 Example 3: Multi-Step Form with Wait Nodes');

  final workflow = WorkflowBuilder.create()
      .name('Multi-Step Onboarding Form')
      .tags(['form', 'wait', 'multi-step'])
      .active(false)
      .webhookTrigger(
        name: 'Start Onboarding',
        path: 'onboarding/start',
        method: 'POST',
      )
      .function(
        name: 'Initialize Session',
        code: '''
const { userId } = \$input.item.json.body;

return [{
  json: {
    sessionId: 'SESSION-' + Date.now(),
    userId,
    step1: \$input.item.json.body,
    createdAt: new Date().toISOString()
  }
}];
''',
      )
      .waitNode(
        name: 'Wait for Personal Info',
        waitType: 'webhook',
      )
      .function(
        name: 'Process Personal Info',
        code: '''
return [{
  json: {
    ...\$input.item.json,
    step2_personal: \$input.item.json.body
  }
}];
''',
      )
      .waitNode(
        name: 'Wait for Preferences',
        waitType: 'webhook',
      )
      .function(
        name: 'Process Preferences',
        code: '''
return [{
  json: {
    ...\$input.item.json,
    step3_preferences: \$input.item.json.body,
    completedAt: new Date().toISOString()
  }
}];
''',
      )
      .postgres(
        name: 'Save Onboarding Data',
        operation: 'insert',
        table: 'onboarding_sessions',
      )
      .emailSend(
        name: 'Send Welcome Email',
        fromEmail: 'welcome@example.com',
        toEmail: r'={{$json.step2_personal.email}}',
        subject: 'Welcome! Your account is ready',
        message: 'Thanks for completing onboarding!',
      )
      .respondToWebhook(
        name: 'Return Completion',
        responseCode: 200,
        responseBody: {
          'message': 'Onboarding completed',
          'sessionId': r'={{$json.sessionId}}',
        },
      )
      .connectSequence([
        'Start Onboarding',
        'Initialize Session',
        'Wait for Personal Info',
        'Process Personal Info',
        'Wait for Preferences',
        'Process Preferences',
        'Save Onboarding Data',
        'Send Welcome Email',
        'Return Completion',
      ])
      .build();

  await workflow.saveToFile('$outputPath/03_multi_step_form.json');
  print('   ✓ Generated: 03_multi_step_form.json\n');
}

/// Example 4: Using pre-built templates
Future<void> example4UsingTemplates(String outputPath) async {
  print('📝 Example 4: Using Pre-built Templates');

  // CRUD API template
  final crudWorkflow = WorkflowTemplates.crudApi(
    resourceName: 'products',
    tableName: 'products',
    webhookPath: 'api/v1',
  );
  await crudWorkflow.saveToFile('$outputPath/04_crud_api_template.json');
  print('   ✓ Generated: 04_crud_api_template.json');

  // Order processing template
  final orderWorkflow = WorkflowTemplates.orderProcessing(
    webhookPath: 'orders/process',
    notificationEmail: 'orders@example.com',
  );
  await orderWorkflow.saveToFile('$outputPath/05_order_processing_template.json');
  print('   ✓ Generated: 05_order_processing_template.json');

  // File upload template
  final uploadWorkflow = WorkflowTemplates.fileUpload(
    webhookPath: 'files/upload',
    s3Bucket: 'my-app-uploads',
  );
  await uploadWorkflow.saveToFile('$outputPath/06_file_upload_template.json');
  print('   ✓ Generated: 06_file_upload_template.json\n');
}

/// Example 5: Complex workflow with multiple paths
Future<void> example5ComplexWorkflow(String outputPath) async {
  print('📝 Example 5: Complex E-Commerce Order Processing');

  final workflow = WorkflowBuilder.create()
      .name('Advanced Order Processing')
      .tags(['ecommerce', 'payment', 'inventory'])
      .active(false)
      .webhookTrigger(
        name: 'Order Received',
        path: 'orders/create',
        method: 'POST',
      )
      .function(
        name: 'Calculate Order Total',
        code: '''
const { items, userId, shippingAddress } = \$input.item.json.body;

const subtotal = items.reduce((sum, item) =>
  sum + (item.price * item.quantity), 0
);
const tax = subtotal * 0.1; // 10% tax
const shipping = subtotal > 50 ? 0 : 5.99; // Free shipping over \$50
const total = subtotal + tax + shipping;

return [{
  json: {
    orderId: 'ORD-' + Date.now(),
    userId,
    items,
    shippingAddress,
    subtotal,
    tax,
    shipping,
    total,
    status: 'pending'
  }
}];
''',
      )
      // Check inventory
      .postgres(
        name: 'Check Inventory',
        operation: 'select',
        query: r"SELECT * FROM inventory WHERE product_id IN ({{$json.items}})",
      )
      .ifNode(
        name: 'Inventory Available?',
        conditions: [
          {
            'leftValue': r'={{$json.inStock}}',
            'operation': 'equals',
            'rightValue': true,
          }
        ],
      )
      // Out of stock path
      .newRow()
      .emailSend(
        name: 'Notify Out of Stock',
        fromEmail: 'orders@example.com',
        toEmail: r'={{$json.customerEmail}}',
        subject: 'Order on Hold - Items Out of Stock',
        message: 'Some items in your order are currently out of stock.',
      )
      .respondToWebhook(
        name: 'Return Out of Stock',
        responseCode: 200,
        responseBody: {
          'status': 'on_hold',
          'message': 'Items out of stock',
        },
      )
      // In stock path - process payment
      .newRow()
      .stripe(
        name: 'Process Payment',
        resource: 'charge',
        operation: 'create',
        additionalParams: {
          'amount': r'={{$json.total * 100}}',
          'currency': 'usd',
        },
      )
      .ifNode(
        name: 'Payment Successful?',
        conditions: [
          {
            'leftValue': r'={{$json.status}}',
            'operation': 'equals',
            'rightValue': 'succeeded',
          }
        ],
      )
      // Payment failed
      .newRow()
      .postgres(
        name: 'Save Failed Order',
        operation: 'insert',
        table: 'failed_orders',
      )
      .emailSend(
        name: 'Payment Failed Email',
        fromEmail: 'orders@example.com',
        toEmail: r'={{$json.customerEmail}}',
        subject: 'Payment Failed',
        message: 'Your payment could not be processed.',
      )
      // Payment succeeded
      .newRow()
      .postgres(
        name: 'Create Order Record',
        operation: 'insert',
        table: 'orders',
      )
      .postgres(
        name: 'Update Inventory',
        operation: 'update',
        table: 'inventory',
      )
      .slack(
        name: 'Notify Fulfillment Team',
        channel: '#fulfillment',
        text: r'New order ready for processing: {{$json.orderId}}',
      )
      .emailSend(
        name: 'Order Confirmation Email',
        fromEmail: 'orders@example.com',
        toEmail: r'={{$json.customerEmail}}',
        subject: r'Order Confirmation - {{$json.orderId}}',
        message: 'Thank you for your order!',
      )
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 200,
        responseBody: {
          'status': 'success',
          'orderId': r'={{$json.orderId}}',
        },
      )
      // Connect all paths
      .connect('Order Received', 'Calculate Order Total')
      .connect('Calculate Order Total', 'Check Inventory')
      .connect('Check Inventory', 'Inventory Available?')
      .connect('Inventory Available?', 'Notify Out of Stock', sourceIndex: 1)
      .connect('Notify Out of Stock', 'Return Out of Stock')
      .connect('Inventory Available?', 'Process Payment', sourceIndex: 0)
      .connect('Process Payment', 'Payment Successful?')
      .connect('Payment Successful?', 'Save Failed Order', sourceIndex: 1)
      .connect('Save Failed Order', 'Payment Failed Email')
      .connect('Payment Successful?', 'Create Order Record', sourceIndex: 0)
      .connect('Create Order Record', 'Update Inventory')
      .connect('Update Inventory', 'Notify Fulfillment Team')
      .connect('Notify Fulfillment Team', 'Order Confirmation Email')
      .connect('Order Confirmation Email', 'Return Success')
      .build();

  await workflow.saveToFile('$outputPath/07_complex_order_processing.json');
  print('   ✓ Generated: 07_complex_order_processing.json\n');
}

/// Example 6: Scheduled workflow
Future<void> example6ScheduledReport(String outputPath) async {
  print('📝 Example 6: Scheduled Weekly Report');

  final workflow = WorkflowTemplates.scheduledReport(
    reportName: 'Sales',
    recipients: 'team@example.com',
    schedule: '0 9 * * 1', // Every Monday at 9 AM
  );

  await workflow.saveToFile('$outputPath/08_scheduled_report.json');
  print('   ✓ Generated: 08_scheduled_report.json\n');
}

/// Example 7: IoT Sensor Data Processing
/// Receives sensor data from IoT devices, validates thresholds,
/// stores in database, and triggers alerts for anomalies
Future<void> example7IoTSensorData(String outputPath) async {
  print('📝 Example 7: IoT Sensor Data Processing');

  final workflow = WorkflowBuilder.create()
      .name('IoT Sensor Data Pipeline')
      .tags(['iot', 'sensors', 'real-time', 'monitoring'])
      .active(true)
      // Receive sensor data
      .webhookTrigger(
        name: 'Receive Sensor Data',
        path: 'iot/sensor-data',
        method: 'POST',
      )
      // Validate sensor data
      .function(
        name: 'Validate & Transform',
        code: r'''
// Validate sensor data
const data = $input.item.json;

if (!data.deviceId || !data.sensorType || data.value === undefined) {
  throw new Error('Invalid sensor data');
}

// Transform data
return {
  deviceId: data.deviceId,
  sensorType: data.sensorType,
  value: parseFloat(data.value),
  timestamp: data.timestamp || new Date().toISOString(),
  location: data.location || 'unknown',
  battery: data.battery || 100
};
''',
      )
      // Store in time-series database
      .postgres(
        name: 'Store Sensor Reading',
        operation: 'insert',
        table: 'sensor_readings',
      )
      // Check if value is out of threshold
      .ifNode(
        name: 'Value Out of Range?',
        conditions: [
          {
            'leftValue': r'={{$json.value}}',
            'operation': 'larger',
            'rightValue': 100,
          }
        ],
      )
      // Alert path - value exceeded threshold
      .newRow()
      .function(
        name: 'Build Alert Message',
        code: r'''
const data = $input.item.json;
return {
  alert: true,
  severity: data.value > 150 ? 'critical' : 'warning',
  message: `Sensor ${data.deviceId} (${data.sensorType}) reading: ${data.value}`,
  deviceId: data.deviceId,
  value: data.value
};
''',
      )
      .postgres(
        name: 'Log Alert',
        operation: 'insert',
        table: 'sensor_alerts',
      )
      .slack(
        name: 'Send Alert to Ops',
        channel: '#iot-alerts',
        text: r'🚨 {{$json.message}} - Severity: {{$json.severity}}',
      )
      .emailSend(
        name: 'Email Ops Team',
        fromEmail: 'iot@example.com',
        toEmail: 'ops@example.com',
        subject: r'IoT Alert: {{$json.severity}}',
        message: r'Device alert triggered. Check Slack for details.',
      )
      // Normal path - value in range
      .newRow()
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 200,
        responseBody: {
          'status': 'ok',
          'message': 'Sensor data processed',
        },
      )
      // Connect all nodes
      .connect('Receive Sensor Data', 'Validate & Transform')
      .connect('Validate & Transform', 'Store Sensor Reading')
      .connect('Store Sensor Reading', 'Value Out of Range?')
      .connect('Value Out of Range?', 'Build Alert Message', sourceIndex: 0)
      .connect('Build Alert Message', 'Log Alert')
      .connect('Log Alert', 'Send Alert to Ops')
      .connect('Send Alert to Ops', 'Email Ops Team')
      .connect('Value Out of Range?', 'Return Success', sourceIndex: 1)
      .build();

  await workflow.saveToFile('$outputPath/09_iot_sensor_processing.json');
  print('   ✓ Generated: 09_iot_sensor_processing.json\n');
}

/// Example 8: Social Media Monitoring
/// Monitor social media mentions, analyze sentiment, and respond
Future<void> example8SocialMediaMonitoring(String outputPath) async {
  print('📝 Example 8: Social Media Monitoring');

  final workflow = WorkflowBuilder.create()
      .name('Social Media Monitoring & Response')
      .tags(['social-media', 'monitoring', 'engagement'])
      // Schedule to check every 15 minutes
      .node(
        name: 'Check Every 15min',
        type: 'n8n-nodes-base.scheduleTrigger',
        parameters: {
          'rule': {
            'interval': [
              {'field': 'minutes', 'minutesInterval': 15}
            ]
          }
        },
      )
      // Search Twitter mentions
      .httpRequest(
        name: 'Fetch Twitter Mentions',
        url: 'https://api.twitter.com/2/tweets/search/recent',
        method: 'GET',
        additionalParams: {
          'qs': {
            'query': '@YourBrand',
            'max_results': 10,
          },
          'authentication': 'oAuth2',
        },
      )
      // Analyze sentiment (mock - would use AI service)
      .function(
        name: 'Analyze Sentiment',
        code: r'''
const tweets = $input.item.json.data || [];

return tweets.map(tweet => {
  // Simple sentiment analysis (replace with actual AI service)
  const text = tweet.text.toLowerCase();
  let sentiment = 'neutral';

  if (text.includes('love') || text.includes('great') || text.includes('awesome')) {
    sentiment = 'positive';
  } else if (text.includes('hate') || text.includes('bad') || text.includes('issue')) {
    sentiment = 'negative';
  }

  return {
    tweetId: tweet.id,
    text: tweet.text,
    sentiment: sentiment,
    author: tweet.author_id
  };
});
''',
      )
      // Store in database
      .postgres(
        name: 'Save Mentions',
        operation: 'insert',
        table: 'social_mentions',
      )
      // Check if negative sentiment
      .ifNode(
        name: 'Is Negative?',
        conditions: [
          {
            'leftValue': r'={{$json.sentiment}}',
            'operation': 'equals',
            'rightValue': 'negative',
          }
        ],
      )
      // Negative sentiment path
      .newRow()
      .slack(
        name: 'Alert Support Team',
        channel: '#customer-support',
        text: r'⚠️ Negative mention detected: {{$json.text}}',
      )
      .emailSend(
        name: 'Email Social Team',
        fromEmail: 'social@example.com',
        toEmail: 'support@example.com',
        subject: 'Urgent: Negative Social Media Mention',
        message: r'Please respond to tweet: {{$json.tweetId}}',
      )
      // Positive sentiment path
      .newRow()
      .function(
        name: 'Log Positive Feedback',
        code: r'''
return {
  type: 'positive_mention',
  message: 'Great customer feedback received',
  tweetId: $input.item.json.tweetId
};
''',
      )
      .build();

  await workflow.saveToFile('$outputPath/10_social_media_monitoring.json');
  print('   ✓ Generated: 10_social_media_monitoring.json\n');
}

/// Example 9: Real-time Alert System
/// Monitor multiple data sources and trigger alerts based on conditions
Future<void> example9RealtimeAlerts(String outputPath) async {
  print('📝 Example 9: Real-time Alert System');

  final workflow = WorkflowBuilder.create()
      .name('Real-time Multi-Source Alert System')
      .tags(['alerts', 'monitoring', 'real-time'])
      .active(true)
      // Webhook for various alert sources
      .webhookTrigger(
        name: 'Alert Webhook',
        path: 'alerts/trigger',
        method: 'POST',
      )
      // Determine alert priority
      .function(
        name: 'Classify Alert',
        code: r'''
const alert = $input.item.json;

// Determine priority based on source and severity
let priority = 'low';
let requiresImmediate = false;

if (alert.severity === 'critical' || alert.source === 'production') {
  priority = 'high';
  requiresImmediate = true;
} else if (alert.severity === 'warning') {
  priority = 'medium';
}

return {
  ...alert,
  priority: priority,
  requiresImmediate: requiresImmediate,
  timestamp: new Date().toISOString(),
  alertId: `alert_${Date.now()}`
};
''',
      )
      // Store all alerts
      .postgres(
        name: 'Log Alert',
        operation: 'insert',
        table: 'system_alerts',
      )
      // Check priority level
      .ifNode(
        name: 'High Priority?',
        conditions: [
          {
            'leftValue': r'={{$json.requiresImmediate}}',
            'operation': 'equals',
            'rightValue': true,
          }
        ],
      )
      // High priority path - immediate notification
      .newRow()
      .slack(
        name: 'Alert Channel',
        channel: '#critical-alerts',
        text: r'🚨 CRITICAL: {{$json.message}} (Source: {{$json.source}})',
      )
      .httpRequest(
        name: 'Trigger PagerDuty',
        url: 'https://api.pagerduty.com/incidents',
        method: 'POST',
        additionalParams: {
          'body': {
            'incident': {
              'type': 'incident',
              'title': r'={{$json.message}}',
              'urgency': 'high',
            }
          }
        },
      )
      .emailSend(
        name: 'Email On-Call',
        fromEmail: 'alerts@example.com',
        toEmail: 'oncall@example.com',
        subject: r'CRITICAL ALERT: {{$json.alertId}}',
        message: r'''
Critical alert triggered:

Source: {{$json.source}}
Message: {{$json.message}}
Time: {{$json.timestamp}}
Priority: {{$json.priority}}

Please investigate immediately.
''',
      )
      // Low/Medium priority path - log only
      .newRow()
      .function(
        name: 'Queue for Review',
        code: r'''
return {
  status: 'queued',
  message: 'Alert queued for review',
  alertId: $input.item.json.alertId
};
''',
      )
      .respondToWebhook(
        name: 'Acknowledge Alert',
        responseCode: 200,
        responseBody: {
          'status': 'received',
          'alertId': r'={{$json.alertId}}',
        },
      )
      // Connect nodes
      .connect('Alert Webhook', 'Classify Alert')
      .connect('Classify Alert', 'Log Alert')
      .connect('Log Alert', 'High Priority?')
      .connect('High Priority?', 'Alert Channel', sourceIndex: 0)
      .connect('Alert Channel', 'Trigger PagerDuty')
      .connect('Trigger PagerDuty', 'Email On-Call')
      .connect('High Priority?', 'Queue for Review', sourceIndex: 1)
      .connect('Queue for Review', 'Acknowledge Alert')
      .build();

  await workflow.saveToFile('$outputPath/11_realtime_alert_system.json');
  print('   ✓ Generated: 11_realtime_alert_system.json\n');
}

/// Example 10: Chatbot Integration
/// Process chatbot messages, route to appropriate handlers, and respond
Future<void> example10ChatbotIntegration(String outputPath) async {
  print('📝 Example 10: Chatbot Integration');

  final workflow = WorkflowBuilder.create()
      .name('AI Chatbot Message Router')
      .tags(['chatbot', 'ai', 'customer-service'])
      .active(true)
      // Receive message from chat platform
      .webhookTrigger(
        name: 'Incoming Message',
        path: 'chatbot/message',
        method: 'POST',
      )
      // Extract and classify intent
      .function(
        name: 'Parse Intent',
        code: r'''
const message = $input.item.json;
const text = (message.text || '').toLowerCase();

// Simple intent classification (replace with NLP service)
let intent = 'general';
let requiresHuman = false;

if (text.includes('price') || text.includes('cost')) {
  intent = 'pricing';
} else if (text.includes('support') || text.includes('help')) {
  intent = 'support';
  requiresHuman = true;
} else if (text.includes('order') || text.includes('track')) {
  intent = 'order_status';
} else if (text.includes('cancel') || text.includes('refund')) {
  intent = 'cancellation';
  requiresHuman = true;
}

return {
  userId: message.userId,
  messageId: message.id,
  text: message.text,
  intent: intent,
  requiresHuman: requiresHuman,
  timestamp: new Date().toISOString()
};
''',
      )
      // Store conversation
      .postgres(
        name: 'Log Conversation',
        operation: 'insert',
        table: 'chat_messages',
      )
      // Route based on intent
      .ifNode(
        name: 'Needs Human Agent?',
        conditions: [
          {
            'leftValue': r'={{$json.requiresHuman}}',
            'operation': 'equals',
            'rightValue': true,
          }
        ],
      )
      // Human escalation path
      .newRow()
      .slack(
        name: 'Notify Support Team',
        channel: '#customer-support',
        text: r'💬 Customer needs help: "{{$json.text}}" (User: {{$json.userId}})',
      )
      .httpRequest(
        name: 'Create Support Ticket',
        url: 'https://api.zendesk.com/api/v2/tickets',
        method: 'POST',
        additionalParams: {
          'body': {
            'ticket': {
              'subject': r'Chat escalation: {{$json.intent}}',
              'description': r'={{$json.text}}',
              'priority': 'high',
            }
          }
        },
      )
      .respondToWebhook(
        name: 'Transfer to Agent',
        responseCode: 200,
        responseBody: {
          'response': 'Let me connect you with a support agent...',
          'type': 'human_transfer',
        },
      )
      // Automated response path
      .newRow()
      .function(
        name: 'Generate Auto Response',
        code: r'''
const intent = $input.item.json.intent;

const responses = {
  pricing: 'Our pricing starts at $9/month. Visit example.com/pricing for details.',
  order_status: 'You can check your order status at example.com/orders',
  general: 'How can I help you today? Ask about pricing, orders, or support.'
};

return {
  response: responses[intent] || responses.general,
  type: 'automated',
  intent: intent
};
''',
      )
      .postgres(
        name: 'Log Bot Response',
        operation: 'insert',
        table: 'bot_responses',
      )
      .respondToWebhook(
        name: 'Send Auto Response',
        responseCode: 200,
        responseBody: {
          'response': r'={{$json.response}}',
          'type': 'bot',
        },
      )
      // Connect nodes
      .connect('Incoming Message', 'Parse Intent')
      .connect('Parse Intent', 'Log Conversation')
      .connect('Log Conversation', 'Needs Human Agent?')
      .connect('Needs Human Agent?', 'Notify Support Team', sourceIndex: 0)
      .connect('Notify Support Team', 'Create Support Ticket')
      .connect('Create Support Ticket', 'Transfer to Agent')
      .connect('Needs Human Agent?', 'Generate Auto Response', sourceIndex: 1)
      .connect('Generate Auto Response', 'Log Bot Response')
      .connect('Log Bot Response', 'Send Auto Response')
      .build();

  await workflow.saveToFile('$outputPath/12_chatbot_integration.json');
  print('   ✓ Generated: 12_chatbot_integration.json\n');
}

/// Example 11: Booking & Appointment System
/// Handle appointment bookings, check availability, send confirmations
Future<void> example11BookingSystem(String outputPath) async {
  print('📝 Example 11: Booking & Appointment System');

  final workflow = WorkflowBuilder.create()
      .name('Appointment Booking System')
      .tags(['booking', 'appointments', 'scheduling', 'calendar'])
      .active(true)
      // Receive booking request
      .webhookTrigger(
        name: 'Booking Request',
        path: 'appointments/book',
        method: 'POST',
      )
      // Validate booking data
      .function(
        name: 'Validate Request',
        code: r'''
const booking = $input.item.json;

// Validate required fields
if (!booking.customerName || !booking.email || !booking.date || !booking.time) {
  throw new Error('Missing required fields: customerName, email, date, time');
}

// Parse and validate date
const requestedDate = new Date(booking.date);
const now = new Date();

if (requestedDate < now) {
  throw new Error('Cannot book appointments in the past');
}

return {
  customerName: booking.customerName,
  email: booking.email,
  phone: booking.phone || '',
  service: booking.service || 'general',
  date: booking.date,
  time: booking.time,
  duration: booking.duration || 60,
  notes: booking.notes || '',
  requestedAt: now.toISOString()
};
''',
      )
      // Check availability in database
      .postgres(
        name: 'Check Availability',
        operation: 'select',
        query: r"SELECT COUNT(*) as count FROM appointments WHERE date = '{{$json.date}}' AND time = '{{$json.time}}' AND status != 'cancelled'",
      )
      // Determine if slot is available
      .ifNode(
        name: 'Slot Available?',
        conditions: [
          {
            'leftValue': r'={{$json.count}}',
            'operation': 'equals',
            'rightValue': 0,
          }
        ],
      )
      // Slot unavailable path
      .newRow()
      .respondToWebhook(
        name: 'Return Unavailable',
        responseCode: 409,
        responseBody: {
          'status': 'error',
          'message': 'Selected time slot is not available',
          'suggestion': 'Please choose a different time',
        },
      )
      // Slot available - create booking
      .newRow()
      .function(
        name: 'Generate Booking ID',
        code: r'''
const data = $input.item.json;
return {
  ...data,
  bookingId: `BK${Date.now()}`,
  status: 'confirmed',
  confirmationCode: Math.random().toString(36).substring(2, 8).toUpperCase()
};
''',
      )
      .postgres(
        name: 'Save Booking',
        operation: 'insert',
        table: 'appointments',
      )
      // Send confirmation email
      .emailSend(
        name: 'Send Confirmation Email',
        fromEmail: 'bookings@example.com',
        toEmail: r'={{$json.email}}',
        subject: r'Appointment Confirmed - {{$json.bookingId}}',
        message: r'''
Hi {{$json.customerName}},

Your appointment has been confirmed!

Booking Details:
• Confirmation Code: {{$json.confirmationCode}}
• Service: {{$json.service}}
• Date: {{$json.date}}
• Time: {{$json.time}}
• Duration: {{$json.duration}} minutes

To cancel or reschedule, please use your confirmation code.

See you soon!
''',
      )
      // Send SMS reminder (if phone provided)
      .function(
        name: 'Prepare SMS',
        code: r'''
const data = $input.item.json;

if (data.phone && data.phone.length > 0) {
  return {
    to: data.phone,
    message: `Appointment confirmed for ${data.date} at ${data.time}. Code: ${data.confirmationCode}`
  };
}

return null;
''',
      )
      // Notify team on Slack
      .slack(
        name: 'Notify Team',
        channel: '#appointments',
        text: r'📅 New booking: {{$json.customerName}} - {{$json.service}} on {{$json.date}} at {{$json.time}}',
      )
      // Return success response
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 201,
        responseBody: {
          'status': 'success',
          'bookingId': r'={{$json.bookingId}}',
          'confirmationCode': r'={{$json.confirmationCode}}',
          'message': 'Appointment booked successfully',
        },
      )
      // Connect nodes
      .connect('Booking Request', 'Validate Request')
      .connect('Validate Request', 'Check Availability')
      .connect('Check Availability', 'Slot Available?')
      .connect('Slot Available?', 'Return Unavailable', sourceIndex: 1)
      .connect('Slot Available?', 'Generate Booking ID', sourceIndex: 0)
      .connect('Generate Booking ID', 'Save Booking')
      .connect('Save Booking', 'Send Confirmation Email')
      .connect('Send Confirmation Email', 'Prepare SMS')
      .connect('Prepare SMS', 'Notify Team')
      .connect('Notify Team', 'Return Success')
      .build();

  await workflow.saveToFile('$outputPath/13_booking_system.json');
  print('   ✓ Generated: 13_booking_system.json\n');
}

/// Example 12: Journaling & Daily Reflection System
/// Store journal entries, analyze mood patterns, send reflection prompts
Future<void> example12JournalingSystem(String outputPath) async {
  print('📝 Example 12: Journaling & Daily Reflection');

  final workflow = WorkflowBuilder.create()
      .name('Digital Journaling System')
      .tags(['journaling', 'wellness', 'reflection', 'mood-tracking'])
      .active(true)
      // Receive journal entry
      .webhookTrigger(
        name: 'Submit Entry',
        path: 'journal/entry',
        method: 'POST',
      )
      // Process and enrich entry
      .function(
        name: 'Process Entry',
        code: r'''
const entry = $input.item.json;

// Calculate word count
const wordCount = (entry.content || '').split(/\s+/).filter(w => w.length > 0).length;

// Extract mood (simple keyword analysis)
const content = (entry.content || '').toLowerCase();
let detectedMood = 'neutral';

if (content.includes('happy') || content.includes('great') || content.includes('wonderful')) {
  detectedMood = 'positive';
} else if (content.includes('sad') || content.includes('anxious') || content.includes('stressed')) {
  detectedMood = 'negative';
}

// Override with explicit mood if provided
const mood = entry.mood || detectedMood;

return {
  userId: entry.userId,
  title: entry.title || `Entry - ${new Date().toLocaleDateString()}`,
  content: entry.content,
  mood: mood,
  tags: entry.tags || [],
  wordCount: wordCount,
  timestamp: new Date().toISOString(),
  entryId: `JE${Date.now()}`,
  isPrivate: entry.isPrivate !== false
};
''',
      )
      // Save to database
      .postgres(
        name: 'Save Entry',
        operation: 'insert',
        table: 'journal_entries',
      )
      // Get user's mood history
      .postgres(
        name: 'Get Recent Moods',
        operation: 'select',
        query: r"SELECT mood, timestamp FROM journal_entries WHERE userId = '{{$json.userId}}' ORDER BY timestamp DESC LIMIT 7",
      )
      // Analyze mood patterns
      .function(
        name: 'Analyze Mood Trends',
        code: r'''
const recentMoods = $input.item.json || [];

// Count moods
const moodCounts = {};
recentMoods.forEach(entry => {
  moodCounts[entry.mood] = (moodCounts[entry.mood] || 0) + 1;
});

// Determine trend
let trend = 'stable';
const posCount = moodCounts['positive'] || 0;
const negCount = moodCounts['negative'] || 0;

if (posCount > negCount + 2) {
  trend = 'improving';
} else if (negCount > posCount + 2) {
  trend = 'concerning';
}

return {
  entryId: recentMoods[0]?.entryId,
  userId: recentMoods[0]?.userId,
  moodTrend: trend,
  positiveCount: posCount,
  negativeCount: negCount,
  totalEntries: recentMoods.length,
  needsSupport: negCount >= 3
};
''',
      )
      // Check if user needs support
      .ifNode(
        name: 'Needs Support?',
        conditions: [
          {
            'leftValue': r'={{$json.needsSupport}}',
            'operation': 'equals',
            'rightValue': true,
          }
        ],
      )
      // Send supportive message
      .newRow()
      .emailSend(
        name: 'Send Support Resources',
        fromEmail: 'wellness@example.com',
        toEmail: 'user@example.com',
        subject: 'We care about your wellbeing',
        message: r'''
Hi,

We noticed you might be going through a challenging time.

Remember, it's okay to not be okay. Here are some resources that might help:
• Meditation exercises
• Professional support contacts
• Community forums

Take care of yourself.
''',
      )
      // Normal path - send insights
      .newRow()
      .function(
        name: 'Generate Insights',
        code: r'''
const data = $input.item.json;

const insights = [
  `You've written ${data.totalEntries} entries this week - great consistency!`,
  `Your mood trend is ${data.moodTrend}.`,
  `Keep reflecting on your thoughts and feelings.`
];

return {
  userId: data.userId,
  insights: insights,
  streak: data.totalEntries,
  encouragement: data.moodTrend === 'improving' ? 'Things are looking up!' : 'Every day is a new opportunity.'
};
''',
      )
      // Save analytics
      .postgres(
        name: 'Save Analytics',
        operation: 'insert',
        table: 'journal_analytics',
      )
      .respondToWebhook(
        name: 'Return Response',
        responseCode: 201,
        responseBody: {
          'status': 'success',
          'message': 'Entry saved successfully',
          'insights': r'={{$json.insights}}',
        },
      )
      // Connect nodes
      .connect('Submit Entry', 'Process Entry')
      .connect('Process Entry', 'Save Entry')
      .connect('Save Entry', 'Get Recent Moods')
      .connect('Get Recent Moods', 'Analyze Mood Trends')
      .connect('Analyze Mood Trends', 'Needs Support?')
      .connect('Needs Support?', 'Send Support Resources', sourceIndex: 0)
      .connect('Needs Support?', 'Generate Insights', sourceIndex: 1)
      .connect('Generate Insights', 'Save Analytics')
      .connect('Save Analytics', 'Return Response')
      .build();

  await workflow.saveToFile('$outputPath/14_journaling_system.json');
  print('   ✓ Generated: 14_journaling_system.json\n');
}

/// Example 13: Real-time Chat Application
/// Handle chat messages, store conversations, manage presence
Future<void> example13ChatWorkflow(String outputPath) async {
  print('📝 Example 13: Real-time Chat Application');

  final workflow = WorkflowBuilder.create()
      .name('Real-time Chat Message Handler')
      .tags(['chat', 'messaging', 'real-time', 'communication'])
      .active(true)
      // Receive chat message
      .webhookTrigger(
        name: 'New Message',
        path: 'chat/message',
        method: 'POST',
      )
      // Validate and process message
      .function(
        name: 'Process Message',
        code: r'''
const msg = $input.item.json;

// Validate
if (!msg.senderId || !msg.channelId || !msg.content) {
  throw new Error('Missing required fields: senderId, channelId, content');
}

// Detect message type
let messageType = 'text';
if (msg.content.startsWith('http://') || msg.content.startsWith('https://')) {
  messageType = 'link';
} else if (msg.fileUrl) {
  messageType = 'file';
}

// Check for mentions
const mentions = [];
const mentionRegex = /@(\w+)/g;
let match;
while ((match = mentionRegex.exec(msg.content)) !== null) {
  mentions.push(match[1]);
}

return {
  messageId: `MSG${Date.now()}`,
  senderId: msg.senderId,
  senderName: msg.senderName || 'Unknown',
  channelId: msg.channelId,
  content: msg.content,
  messageType: messageType,
  mentions: mentions,
  fileUrl: msg.fileUrl || null,
  timestamp: new Date().toISOString(),
  edited: false
};
''',
      )
      // Store message in database
      .postgres(
        name: 'Save Message',
        operation: 'insert',
        table: 'chat_messages',
      )
      // Update channel's last activity
      .postgres(
        name: 'Update Channel Activity',
        operation: 'update',
        table: 'channels',
        additionalParams: {
          'where': r"id = '{{$json.channelId}}'",
          'set': {'lastActivity': r'{{$json.timestamp}}'},
        },
      )
      // Check if message has mentions
      .ifNode(
        name: 'Has Mentions?',
        conditions: [
          {
            'leftValue': r'={{$json.mentions.length}}',
            'operation': 'larger',
            'rightValue': 0,
          }
        ],
      )
      // Send mention notifications
      .newRow()
      .function(
        name: 'Prepare Notifications',
        code: r'''
const data = $input.item.json;

return data.mentions.map(username => ({
  recipientUsername: username,
  messageId: data.messageId,
  senderId: data.senderId,
  senderName: data.senderName,
  channelId: data.channelId,
  preview: data.content.substring(0, 100),
  type: 'mention'
}));
''',
      )
      .postgres(
        name: 'Queue Notifications',
        operation: 'insert',
        table: 'notifications',
      )
      .slack(
        name: 'Notify Mentioned Users',
        channel: '#chat-notifications',
        text: r'💬 {{$json.senderName}} mentioned @{{$json.recipientUsername}} in {{$json.channelId}}',
      )
      // No mentions - continue
      .newRow()
      .function(
        name: 'Log Activity',
        code: r'''
return {
  type: 'message_sent',
  messageId: $input.item.json.messageId,
  channelId: $input.item.json.channelId
};
''',
      )
      // Check for moderation (spam/abuse detection)
      .function(
        name: 'Content Moderation',
        code: r'''
const content = ($input.item.json.content || '').toLowerCase();

// Simple spam detection
const spamKeywords = ['buy now', 'click here', 'free money', 'limited offer'];
const isSpam = spamKeywords.some(keyword => content.includes(keyword));

// Check for excessive caps
const capsRatio = (content.match(/[A-Z]/g) || []).length / content.length;
const isYelling = capsRatio > 0.7 && content.length > 10;

return {
  messageId: $input.item.json.messageId,
  isSpam: isSpam,
  isYelling: isYelling,
  requiresReview: isSpam || isYelling,
  flagReason: isSpam ? 'potential spam' : (isYelling ? 'excessive caps' : null)
};
''',
      )
      // Flag for review if needed
      .ifNode(
        name: 'Needs Review?',
        conditions: [
          {
            'leftValue': r'={{$json.requiresReview}}',
            'operation': 'equals',
            'rightValue': true,
          }
        ],
      )
      // Flag for moderation
      .newRow()
      .postgres(
        name: 'Flag for Moderation',
        operation: 'insert',
        table: 'moderation_queue',
      )
      .slack(
        name: 'Alert Moderators',
        channel: '#moderation',
        text: r'⚠️ Message flagged: {{$json.messageId}} - Reason: {{$json.flagReason}}',
      )
      // Normal message - broadcast
      .newRow()
      .respondToWebhook(
        name: 'Broadcast Success',
        responseCode: 200,
        responseBody: {
          'status': 'sent',
          'messageId': r'={{$json.messageId}}',
          'timestamp': r'={{$json.timestamp}}',
        },
      )
      // Connect nodes
      .connect('New Message', 'Process Message')
      .connect('Process Message', 'Save Message')
      .connect('Save Message', 'Update Channel Activity')
      .connect('Update Channel Activity', 'Has Mentions?')
      .connect('Has Mentions?', 'Prepare Notifications', sourceIndex: 0)
      .connect('Prepare Notifications', 'Queue Notifications')
      .connect('Queue Notifications', 'Notify Mentioned Users')
      .connect('Has Mentions?', 'Log Activity', sourceIndex: 1)
      .connect('Log Activity', 'Content Moderation')
      .connect('Notify Mentioned Users', 'Content Moderation')
      .connect('Content Moderation', 'Needs Review?')
      .connect('Needs Review?', 'Flag for Moderation', sourceIndex: 0)
      .connect('Flag for Moderation', 'Alert Moderators')
      .connect('Needs Review?', 'Broadcast Success', sourceIndex: 1)
      .build();

  await workflow.saveToFile('$outputPath/15_chat_workflow.json');
  print('   ✓ Generated: 15_chat_workflow.json\n');
}

/// Example 14: Invoice Generation for Booking System
/// Generate and send invoices for completed appointments
Future<void> example14InvoiceWorkflow(String outputPath) async {
  print('📝 Example 14: Invoice Generation for Bookings');

  final workflow = WorkflowBuilder.create()
      .name('Automated Invoice Generation System')
      .tags(['invoicing', 'billing', 'bookings', 'payments', 'accounting'])
      .active(true)
      // Trigger: Appointment completed or manual invoice request
      .webhookTrigger(
        name: 'Invoice Request',
        path: 'invoices/generate',
        method: 'POST',
      )
      // Validate and fetch booking details
      .function(
        name: 'Validate Request',
        code: r'''
const request = $input.item.json;

if (!request.bookingId) {
  throw new Error('Booking ID is required');
}

return {
  bookingId: request.bookingId,
  sendEmail: request.sendEmail !== false,
  includeTax: request.includeTax !== false,
  requestedBy: request.requestedBy || 'system',
  requestedAt: new Date().toISOString()
};
''',
      )
      // Fetch booking details from database
      .postgres(
        name: 'Get Booking Details',
        operation: 'select',
        query: r"SELECT * FROM appointments WHERE bookingId = '{{$json.bookingId}}' LIMIT 1",
      )
      // Fetch customer information
      .postgres(
        name: 'Get Customer Info',
        operation: 'select',
        query: r"SELECT * FROM customers WHERE id = '{{$json.customerId}}' LIMIT 1",
      )
      // Calculate invoice amounts
      .function(
        name: 'Calculate Invoice',
        code: r'''
const booking = $input.item.json;

// Get service pricing
const basePrice = booking.servicePrice || 100.00;
const duration = booking.duration || 60;
const hourlyRate = booking.hourlyRate || 100.00;

// Calculate amounts
const subtotal = (duration / 60) * hourlyRate;
const taxRate = 0.10; // 10% tax
const taxAmount = subtotal * taxRate;
const total = subtotal + taxAmount;

// Generate invoice number
const invoiceNumber = `INV-${new Date().getFullYear()}-${String(Date.now()).slice(-6)}`;

return {
  invoiceNumber: invoiceNumber,
  invoiceDate: new Date().toISOString().split('T')[0],
  dueDate: new Date(Date.now() + 30*24*60*60*1000).toISOString().split('T')[0], // 30 days
  bookingId: booking.bookingId,
  customerId: booking.customerId,
  customerName: booking.customerName,
  customerEmail: booking.customerEmail,
  customerAddress: booking.customerAddress || '',
  serviceDate: booking.date,
  serviceTime: booking.time,
  serviceName: booking.service,
  duration: duration,
  hourlyRate: hourlyRate,
  subtotal: subtotal.toFixed(2),
  taxRate: (taxRate * 100).toFixed(0),
  taxAmount: taxAmount.toFixed(2),
  total: total.toFixed(2),
  status: 'pending',
  currency: 'USD'
};
''',
      )
      // Save invoice to database
      .postgres(
        name: 'Save Invoice',
        operation: 'insert',
        table: 'invoices',
      )
      // Generate PDF invoice (simulate with function)
      .function(
        name: 'Generate PDF',
        code: r'''
const invoice = $input.item.json;

// In real implementation, use PDF generation service
// For now, create HTML template
const htmlInvoice = `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; margin: 40px; }
    .header { text-align: center; margin-bottom: 30px; }
    .invoice-details { margin-bottom: 20px; }
    .customer-info { margin-bottom: 20px; }
    table { width: 100%; border-collapse: collapse; margin-top: 20px; }
    th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
    .total { font-weight: bold; font-size: 1.2em; }
    .footer { margin-top: 40px; text-align: center; color: #666; }
  </style>
</head>
<body>
  <div class="header">
    <h1>INVOICE</h1>
    <p>Your Company Name</p>
  </div>

  <div class="invoice-details">
    <p><strong>Invoice #:</strong> ${invoice.invoiceNumber}</p>
    <p><strong>Date:</strong> ${invoice.invoiceDate}</p>
    <p><strong>Due Date:</strong> ${invoice.dueDate}</p>
  </div>

  <div class="customer-info">
    <h3>Bill To:</h3>
    <p>${invoice.customerName}</p>
    <p>${invoice.customerEmail}</p>
    <p>${invoice.customerAddress}</p>
  </div>

  <table>
    <thead>
      <tr>
        <th>Service</th>
        <th>Date</th>
        <th>Duration</th>
        <th>Rate</th>
        <th>Amount</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>${invoice.serviceName}</td>
        <td>${invoice.serviceDate} ${invoice.serviceTime}</td>
        <td>${invoice.duration} min</td>
        <td>$${invoice.hourlyRate}/hr</td>
        <td>$${invoice.subtotal}</td>
      </tr>
      <tr>
        <td colspan="4" style="text-align: right;">Subtotal:</td>
        <td>$${invoice.subtotal}</td>
      </tr>
      <tr>
        <td colspan="4" style="text-align: right;">Tax (${invoice.taxRate}%):</td>
        <td>$${invoice.taxAmount}</td>
      </tr>
      <tr class="total">
        <td colspan="4" style="text-align: right;">TOTAL:</td>
        <td>$${invoice.total} ${invoice.currency}</td>
      </tr>
    </tbody>
  </table>

  <div class="footer">
    <p>Thank you for your business!</p>
    <p>Payment is due within 30 days. Please reference invoice number on payment.</p>
  </div>
</body>
</html>
`;

return {
  ...invoice,
  pdfHtml: htmlInvoice,
  pdfUrl: `https://example.com/invoices/${invoice.invoiceNumber}.pdf`
};
''',
      )
      // Store PDF in cloud storage (simulate)
      .httpRequest(
        name: 'Upload to Cloud Storage',
        url: 'https://api.cloudinary.com/v1_1/upload',
        method: 'POST',
        additionalParams: {
          'body': {
            'file': r'={{$json.pdfHtml}}',
            'folder': 'invoices',
          }
        },
      )
      // Send invoice via email
      .emailSend(
        name: 'Email Invoice',
        fromEmail: 'billing@example.com',
        toEmail: r'={{$json.customerEmail}}',
        subject: r'Invoice {{$json.invoiceNumber}} - Payment Due',
        message: r'''
Dear {{$json.customerName}},

Thank you for choosing our services!

Please find your invoice attached for the service provided on {{$json.serviceDate}}.

Invoice Details:
• Invoice Number: {{$json.invoiceNumber}}
• Amount Due: ${{$json.total}} {{$json.currency}}
• Due Date: {{$json.dueDate}}

Service Summary:
• Service: {{$json.serviceName}}
• Date: {{$json.serviceDate}} at {{$json.serviceTime}}
• Duration: {{$json.duration}} minutes

You can view and pay your invoice online at:
{{$json.pdfUrl}}

Payment Methods:
• Credit Card
• Bank Transfer
• PayPal

If you have any questions, please don't hesitate to contact us.

Best regards,
Billing Department
''',
      )
      // Send copy to accounting team
      .emailSend(
        name: 'Notify Accounting',
        fromEmail: 'billing@example.com',
        toEmail: 'accounting@example.com',
        subject: r'New Invoice Generated: {{$json.invoiceNumber}}',
        message: r'''
Invoice generated successfully:

• Invoice #: {{$json.invoiceNumber}}
• Customer: {{$json.customerName}}
• Amount: ${{$json.total}} {{$json.currency}}
• Status: Pending
• Booking: {{$json.bookingId}}

View invoice: {{$json.pdfUrl}}
''',
      )
      // Log to Slack
      .slack(
        name: 'Notify Team',
        channel: '#billing',
        text: r'💰 Invoice {{$json.invoiceNumber}} generated for {{$json.customerName}} - ${{$json.total}} {{$json.currency}}',
      )
      // Schedule payment reminder (7 days before due)
      .function(
        name: 'Schedule Reminder',
        code: r'''
const invoice = $input.item.json;
const dueDate = new Date(invoice.dueDate);
const reminderDate = new Date(dueDate.getTime() - 7*24*60*60*1000);

return {
  invoiceNumber: invoice.invoiceNumber,
  customerId: invoice.customerId,
  customerEmail: invoice.customerEmail,
  reminderDate: reminderDate.toISOString(),
  reminderType: 'payment_due_soon',
  amount: invoice.total
};
''',
      )
      // Save reminder to queue
      .postgres(
        name: 'Queue Reminder',
        operation: 'insert',
        table: 'scheduled_reminders',
      )
      // Update booking status
      .postgres(
        name: 'Update Booking Status',
        operation: 'update',
        table: 'appointments',
        additionalParams: {
          'where': r"bookingId = '{{$json.bookingId}}'",
          'set': {
            'invoiceGenerated': true,
            'invoiceNumber': r'={{$json.invoiceNumber}}',
          },
        },
      )
      // Return success response
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 201,
        responseBody: {
          'status': 'success',
          'invoiceNumber': r'={{$json.invoiceNumber}}',
          'amount': r'={{$json.total}}',
          'currency': r'={{$json.currency}}',
          'pdfUrl': r'={{$json.pdfUrl}}',
          'emailSent': true,
          'message': 'Invoice generated and sent successfully',
        },
      )
      // Connect all nodes
      .connect('Invoice Request', 'Validate Request')
      .connect('Validate Request', 'Get Booking Details')
      .connect('Get Booking Details', 'Get Customer Info')
      .connect('Get Customer Info', 'Calculate Invoice')
      .connect('Calculate Invoice', 'Save Invoice')
      .connect('Save Invoice', 'Generate PDF')
      .connect('Generate PDF', 'Upload to Cloud Storage')
      .connect('Upload to Cloud Storage', 'Email Invoice')
      .connect('Email Invoice', 'Notify Accounting')
      .connect('Notify Accounting', 'Notify Team')
      .connect('Notify Team', 'Schedule Reminder')
      .connect('Schedule Reminder', 'Queue Reminder')
      .connect('Queue Reminder', 'Update Booking Status')
      .connect('Update Booking Status', 'Return Success')
      .build();

  await workflow.saveToFile('$outputPath/16_invoice_generation.json');
  print('   ✓ Generated: 16_invoice_generation.json\n');
}

/// Example 15: Supabase Booking System
/// Complete booking system using Supabase as backend with real-time features
Future<void> example15SupabaseBooking(String outputPath) async {
  print('📝 Example 15: Supabase Booking System');

  final workflow = WorkflowBuilder.create()
      .name('Supabase Booking System')
      .tags(['supabase', 'booking', 'real-time', 'appointments'])
      .active(true)
      // Receive booking request
      .webhookTrigger(
        name: 'Booking Request',
        path: 'supabase/bookings/create',
        method: 'POST',
      )
      // Validate booking data
      .function(
        name: 'Validate & Prepare',
        code: r'''
const booking = $input.item.json;

// Validate required fields
if (!booking.customer_name || !booking.customer_email || !booking.service_id || !booking.booking_date || !booking.booking_time) {
  throw new Error('Missing required fields');
}

// Parse date and validate
const bookingDateTime = new Date(`${booking.booking_date}T${booking.booking_time}`);
const now = new Date();

if (bookingDateTime < now) {
  throw new Error('Cannot book appointments in the past');
}

// Prepare data for Supabase
return {
  customer_name: booking.customer_name,
  customer_email: booking.customer_email,
  customer_phone: booking.customer_phone || null,
  service_id: booking.service_id,
  booking_date: booking.booking_date,
  booking_time: booking.booking_time,
  duration_minutes: booking.duration_minutes || 60,
  notes: booking.notes || '',
  status: 'pending',
  created_at: now.toISOString(),
  metadata: booking.metadata || {}
};
''',
      )
      // Check availability in Supabase
      .httpRequest(
        name: 'Check Availability',
        url: 'https://your-project.supabase.co/rest/v1/bookings',
        method: 'GET',
        additionalParams: {
          'qs': {
            'booking_date': r'eq.{{$json.booking_date}}',
            'booking_time': r'eq.{{$json.booking_time}}',
            'status': r'neq.cancelled',
            'select': 'id',
          },
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
          },
        },
      )
      // Check if slot is available
      .function(
        name: 'Evaluate Availability',
        code: r'''
const bookingData = $input.first().json;
const existingBookings = $input.last().json;

return {
  ...bookingData,
  isAvailable: existingBookings.length === 0,
  conflictCount: existingBookings.length
};
''',
      )
      .ifNode(
        name: 'Slot Available?',
        conditions: [
          {
            'leftValue': r'={{$json.isAvailable}}',
            'operation': 'equals',
            'rightValue': true,
          }
        ],
      )
      // Unavailable - return error
      .newRow()
      .respondToWebhook(
        name: 'Return Conflict',
        responseCode: 409,
        responseBody: {
          'success': false,
          'error': 'Time slot not available',
          'message': 'The selected time is already booked. Please choose another time.',
        },
      )
      // Available - create booking in Supabase
      .newRow()
      .httpRequest(
        name: 'Create Booking in Supabase',
        url: 'https://your-project.supabase.co/rest/v1/bookings',
        method: 'POST',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          'body': {
            'customer_name': r'={{$json.customer_name}}',
            'customer_email': r'={{$json.customer_email}}',
            'customer_phone': r'={{$json.customer_phone}}',
            'service_id': r'={{$json.service_id}}',
            'booking_date': r'={{$json.booking_date}}',
            'booking_time': r'={{$json.booking_time}}',
            'duration_minutes': r'={{$json.duration_minutes}}',
            'notes': r'={{$json.notes}}',
            'status': 'confirmed',
            'metadata': r'={{$json.metadata}}',
          },
        },
      )
      // Get service details from Supabase
      .httpRequest(
        name: 'Get Service Details',
        url: r'https://your-project.supabase.co/rest/v1/services?id=eq.{{$json.service_id}}',
        method: 'GET',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
          },
        },
      )
      // Merge booking and service data
      .function(
        name: 'Prepare Confirmation Data',
        code: r'''
const booking = $input.first().json[0];
const service = $input.last().json[0];

// Generate confirmation code
const confirmationCode = Math.random().toString(36).substring(2, 8).toUpperCase();

return {
  booking_id: booking.id,
  confirmation_code: confirmationCode,
  customer_name: booking.customer_name,
  customer_email: booking.customer_email,
  customer_phone: booking.customer_phone,
  service_name: service.name,
  service_price: service.price,
  service_duration: booking.duration_minutes,
  booking_date: booking.booking_date,
  booking_time: booking.booking_time,
  status: booking.status,
  notes: booking.notes
};
''',
      )
      // Update booking with confirmation code in Supabase
      .httpRequest(
        name: 'Save Confirmation Code',
        url: r'https://your-project.supabase.co/rest/v1/bookings?id=eq.{{$json.booking_id}}',
        method: 'PATCH',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
          },
          'body': {
            'confirmation_code': r'={{$json.confirmation_code}}',
          },
        },
      )
      // Send confirmation email via Supabase Edge Function or direct SMTP
      .emailSend(
        name: 'Send Confirmation Email',
        fromEmail: 'bookings@example.com',
        toEmail: r'={{$json.customer_email}}',
        subject: r'Booking Confirmed - {{$json.confirmation_code}}',
        message: r'''
Hi {{$json.customer_name}},

Your booking has been confirmed! ✅

📅 Booking Details:
━━━━━━━━━━━━━━━━━━━━━━━━━
• Confirmation Code: {{$json.confirmation_code}}
• Service: {{$json.service_name}}
• Date: {{$json.booking_date}}
• Time: {{$json.booking_time}}
• Duration: {{$json.service_duration}} minutes
• Price: ${{$json.service_price}}

📝 Notes:
{{$json.notes}}

━━━━━━━━━━━━━━━━━━━━━━━━━

To cancel or reschedule, please use your confirmation code.

Need help? Reply to this email or call us.

See you soon!

Best regards,
Your Team
''',
      )
      // Send SMS notification if phone provided
      .function(
        name: 'Check SMS Eligibility',
        code: r'''
const data = $input.item.json;

if (data.customer_phone && data.customer_phone.length > 0) {
  return {
    ...data,
    send_sms: true,
    sms_message: `Booking confirmed for ${data.booking_date} at ${data.booking_time}. Code: ${data.confirmation_code}`
  };
}

return {
  ...data,
  send_sms: false
};
''',
      )
      // Trigger Supabase real-time notification
      .httpRequest(
        name: 'Notify via Supabase Realtime',
        url: 'https://your-project.supabase.co/rest/v1/rpc/notify_new_booking',
        method: 'POST',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
          },
          'body': {
            'booking_id': r'={{$json.booking_id}}',
            'customer_name': r'={{$json.customer_name}}',
            'service_name': r'={{$json.service_name}}',
            'booking_time': r'={{$json.booking_date}} {{$json.booking_time}}',
          },
        },
      )
      // Log to Slack
      .slack(
        name: 'Notify Team',
        channel: '#bookings',
        text: r'📅 New booking: {{$json.customer_name}} - {{$json.service_name}} on {{$json.booking_date}} at {{$json.booking_time}} (Code: {{$json.confirmation_code}})',
      )
      // Return success response
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 201,
        responseBody: {
          'success': true,
          'booking_id': r'={{$json.booking_id}}',
          'confirmation_code': r'={{$json.confirmation_code}}',
          'message': 'Booking confirmed successfully',
          'booking': {
            'customer_name': r'={{$json.customer_name}}',
            'service_name': r'={{$json.service_name}}',
            'date': r'={{$json.booking_date}}',
            'time': r'={{$json.booking_time}}',
            'duration': r'={{$json.service_duration}}',
            'price': r'={{$json.service_price}}',
          },
        },
      )
      // Connect all nodes
      .connect('Booking Request', 'Validate & Prepare')
      .connect('Validate & Prepare', 'Check Availability')
      .connect('Check Availability', 'Evaluate Availability')
      .connect('Evaluate Availability', 'Slot Available?')
      .connect('Slot Available?', 'Return Conflict', sourceIndex: 1)
      .connect('Slot Available?', 'Create Booking in Supabase', sourceIndex: 0)
      .connect('Create Booking in Supabase', 'Get Service Details')
      .connect('Get Service Details', 'Prepare Confirmation Data')
      .connect('Prepare Confirmation Data', 'Save Confirmation Code')
      .connect('Save Confirmation Code', 'Send Confirmation Email')
      .connect('Send Confirmation Email', 'Check SMS Eligibility')
      .connect('Check SMS Eligibility', 'Notify via Supabase Realtime')
      .connect('Notify via Supabase Realtime', 'Notify Team')
      .connect('Notify Team', 'Return Success')
      .build();

  await workflow.saveToFile('$outputPath/17_supabase_booking_system.json');
  print('   ✓ Generated: 17_supabase_booking_system.json\n');
}

/// Example 16: Supabase Booking with Auto-Invoice Generation
/// Complete booking and invoicing system integrated with Supabase
Future<void> example16SupabaseBookingInvoice(String outputPath) async {
  print('📝 Example 16: Supabase Booking with Auto-Invoice');

  final workflow = WorkflowBuilder.create()
      .name('Supabase Booking & Invoice System')
      .tags(['supabase', 'booking', 'invoice', 'billing', 'automation'])
      .active(true)
      // Webhook to trigger booking completion and invoicing
      .webhookTrigger(
        name: 'Booking Completed',
        path: 'supabase/bookings/complete',
        method: 'POST',
      )
      // Validate and extract booking ID
      .function(
        name: 'Validate Booking ID',
        code: r'''
const request = $input.item.json;

if (!request.booking_id) {
  throw new Error('booking_id is required');
}

return {
  booking_id: request.booking_id,
  trigger_invoice: request.trigger_invoice !== false,
  send_email: request.send_email !== false,
  timestamp: new Date().toISOString()
};
''',
      )
      // Fetch booking details from Supabase
      .httpRequest(
        name: 'Get Booking from Supabase',
        url: r'https://your-project.supabase.co/rest/v1/bookings?id=eq.{{$json.booking_id}}&select=*,customer:customers(*),service:services(*)&limit=1',
        method: 'GET',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
          },
        },
      )
      // Transform booking data
      .function(
        name: 'Prepare Booking Data',
        code: r'''
const bookings = $input.item.json;

if (!bookings || bookings.length === 0) {
  throw new Error('Booking not found');
}

const booking = bookings[0];

return {
  booking_id: booking.id,
  booking_date: booking.booking_date,
  booking_time: booking.booking_time,
  status: booking.status,
  duration_minutes: booking.duration_minutes,
  notes: booking.notes,
  confirmation_code: booking.confirmation_code,
  customer_id: booking.customer.id,
  customer_name: booking.customer.name,
  customer_email: booking.customer.email,
  customer_phone: booking.customer.phone,
  customer_address: booking.customer.address || '',
  service_id: booking.service.id,
  service_name: booking.service.name,
  service_price: booking.service.price,
  hourly_rate: booking.service.hourly_rate || 100
};
''',
      )
      // Check if booking is completed
      .ifNode(
        name: 'Booking Completed?',
        conditions: [
          {
            'leftValue': r'={{$json.status}}',
            'operation': 'equals',
            'rightValue': 'completed',
          }
        ],
      )
      // Not completed - return error
      .newRow()
      .respondToWebhook(
        name: 'Return Not Completed',
        responseCode: 400,
        responseBody: {
          'success': false,
          'error': 'Booking is not completed',
          'status': r'={{$json.status}}',
        },
      )
      // Completed - generate invoice
      .newRow()
      .function(
        name: 'Calculate Invoice',
        code: r'''
const booking = $input.item.json;

// Calculate amounts
const duration_hours = booking.duration_minutes / 60;
const subtotal = duration_hours * booking.hourly_rate;
const tax_rate = 0.10; // 10% tax
const tax_amount = subtotal * tax_rate;
const total = subtotal + tax_amount;

// Generate invoice number
const invoice_number = `INV-${new Date().getFullYear()}-${String(Date.now()).slice(-6)}`;
const invoice_date = new Date().toISOString().split('T')[0];
const due_date = new Date(Date.now() + 30*24*60*60*1000).toISOString().split('T')[0];

return {
  // Booking info
  booking_id: booking.booking_id,
  booking_date: booking.booking_date,
  booking_time: booking.booking_time,
  confirmation_code: booking.confirmation_code,

  // Customer info
  customer_id: booking.customer_id,
  customer_name: booking.customer_name,
  customer_email: booking.customer_email,
  customer_address: booking.customer_address,

  // Service info
  service_name: booking.service_name,
  duration_minutes: booking.duration_minutes,
  hourly_rate: booking.hourly_rate,

  // Invoice calculations
  invoice_number: invoice_number,
  invoice_date: invoice_date,
  due_date: due_date,
  subtotal: subtotal.toFixed(2),
  tax_rate: (tax_rate * 100).toFixed(0),
  tax_amount: tax_amount.toFixed(2),
  total: total.toFixed(2),
  currency: 'USD',
  status: 'pending'
};
''',
      )
      // Save invoice to Supabase
      .httpRequest(
        name: 'Create Invoice in Supabase',
        url: 'https://your-project.supabase.co/rest/v1/invoices',
        method: 'POST',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          'body': {
            'booking_id': r'={{$json.booking_id}}',
            'customer_id': r'={{$json.customer_id}}',
            'invoice_number': r'={{$json.invoice_number}}',
            'invoice_date': r'={{$json.invoice_date}}',
            'due_date': r'={{$json.due_date}}',
            'subtotal': r'={{$json.subtotal}}',
            'tax_rate': r'={{$json.tax_rate}}',
            'tax_amount': r'={{$json.tax_amount}}',
            'total': r'={{$json.total}}',
            'currency': r'={{$json.currency}}',
            'status': 'pending',
            'line_items': [
              {
                'description': r'={{$json.service_name}}',
                'quantity': r'={{$json.duration_minutes}}',
                'unit': 'minutes',
                'rate': r'={{$json.hourly_rate}}',
                'amount': r'={{$json.subtotal}}',
              }
            ],
          },
        },
      )
      // Merge invoice data
      .function(
        name: 'Prepare Invoice Data',
        code: r'''
const invoiceData = $input.first().json;
const invoiceRecord = $input.last().json[0];

return {
  ...invoiceData,
  invoice_id: invoiceRecord.id,
  invoice_url: `https://example.com/invoices/${invoiceRecord.invoice_number}`,
  pdf_url: `https://example.com/invoices/${invoiceRecord.invoice_number}.pdf`
};
''',
      )
      // Update booking with invoice reference in Supabase
      .httpRequest(
        name: 'Link Invoice to Booking',
        url: r'https://your-project.supabase.co/rest/v1/bookings?id=eq.{{$json.booking_id}}',
        method: 'PATCH',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
          },
          'body': {
            'invoice_id': r'={{$json.invoice_id}}',
            'invoice_number': r'={{$json.invoice_number}}',
            'invoiced_at': r'={{$json.invoice_date}}',
          },
        },
      )
      // Generate PDF invoice (HTML template)
      .function(
        name: 'Generate Invoice PDF',
        code: r'''
const inv = $input.item.json;

const invoiceHTML = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif; padding: 40px; }
    .header { text-align: center; margin-bottom: 40px; border-bottom: 3px solid #4F46E5; padding-bottom: 20px; }
    .header h1 { color: #4F46E5; font-size: 32px; margin-bottom: 10px; }
    .invoice-info { display: flex; justify-content: space-between; margin-bottom: 30px; }
    .info-block h3 { color: #4F46E5; margin-bottom: 10px; }
    .info-block p { margin: 5px 0; color: #374151; }
    table { width: 100%; border-collapse: collapse; margin: 20px 0; }
    th { background: #4F46E5; color: white; padding: 12px; text-align: left; }
    td { padding: 12px; border-bottom: 1px solid #E5E7EB; }
    .total-row { background: #F3F4F6; font-weight: bold; }
    .grand-total { background: #4F46E5; color: white; font-size: 18px; }
    .footer { margin-top: 40px; text-align: center; color: #6B7280; padding-top: 20px; border-top: 1px solid #E5E7EB; }
  </style>
</head>
<body>
  <div class="header">
    <h1>INVOICE</h1>
    <p style="color: #6B7280;">Your Company Name</p>
  </div>

  <div class="invoice-info">
    <div class="info-block">
      <h3>Invoice Details</h3>
      <p><strong>Invoice #:</strong> ${inv.invoice_number}</p>
      <p><strong>Date:</strong> ${inv.invoice_date}</p>
      <p><strong>Due Date:</strong> ${inv.due_date}</p>
      <p><strong>Booking:</strong> ${inv.confirmation_code}</p>
    </div>
    <div class="info-block">
      <h3>Bill To</h3>
      <p><strong>${inv.customer_name}</strong></p>
      <p>${inv.customer_email}</p>
      <p>${inv.customer_address}</p>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th>Service</th>
        <th>Date & Time</th>
        <th>Duration</th>
        <th>Rate</th>
        <th>Amount</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>${inv.service_name}</td>
        <td>${inv.booking_date} ${inv.booking_time}</td>
        <td>${inv.duration_minutes} minutes</td>
        <td>$${inv.hourly_rate}/hour</td>
        <td>$${inv.subtotal}</td>
      </tr>
      <tr class="total-row">
        <td colspan="4" style="text-align: right;">Subtotal:</td>
        <td>$${inv.subtotal}</td>
      </tr>
      <tr class="total-row">
        <td colspan="4" style="text-align: right;">Tax (${inv.tax_rate}%):</td>
        <td>$${inv.tax_amount}</td>
      </tr>
      <tr class="grand-total">
        <td colspan="4" style="text-align: right;">TOTAL DUE:</td>
        <td>$${inv.total} ${inv.currency}</td>
      </tr>
    </tbody>
  </table>

  <div class="footer">
    <p><strong>Thank you for your business!</strong></p>
    <p>Payment is due within 30 days. Please reference invoice number on payment.</p>
    <p>Questions? Contact us at billing@example.com</p>
  </div>
</body>
</html>
`;

return {
  ...inv,
  invoice_html: invoiceHTML
};
''',
      )
      // Send invoice email to customer
      .emailSend(
        name: 'Email Invoice to Customer',
        fromEmail: 'billing@example.com',
        toEmail: r'={{$json.customer_email}}',
        subject: r'Invoice {{$json.invoice_number}} - Payment Due ${{$json.total}}',
        message: r'''
Dear {{$json.customer_name}},

Thank you for your recent booking! Please find your invoice details below.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 INVOICE DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Invoice Number: {{$json.invoice_number}}
Invoice Date: {{$json.invoice_date}}
Due Date: {{$json.due_date}}
Booking Reference: {{$json.confirmation_code}}

Service: {{$json.service_name}}
Date & Time: {{$json.booking_date}} at {{$json.booking_time}}
Duration: {{$json.duration_minutes}} minutes

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 PAYMENT BREAKDOWN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Subtotal: ${{$json.subtotal}}
Tax ({{$json.tax_rate}}%): ${{$json.tax_amount}}
TOTAL DUE: ${{$json.total}} {{$json.currency}}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📥 View/Download Invoice:
{{$json.invoice_url}}

💳 Payment Methods:
• Credit Card
• Bank Transfer
• PayPal
• Stripe

Please pay by {{$json.due_date}} to avoid late fees.

Questions? Reply to this email or contact our billing team.

Best regards,
Billing Department
''',
      )
      // Send copy to accounting team
      .emailSend(
        name: 'Notify Accounting',
        fromEmail: 'billing@example.com',
        toEmail: 'accounting@example.com',
        subject: r'Invoice Generated: {{$json.invoice_number}} - {{$json.customer_name}}',
        message: r'''
New invoice generated and sent to customer:

Invoice #: {{$json.invoice_number}}
Customer: {{$json.customer_name}} ({{$json.customer_email}})
Booking: {{$json.confirmation_code}}
Service: {{$json.service_name}}
Amount: ${{$json.total}} {{$json.currency}}
Status: Pending
Due Date: {{$json.due_date}}

View: {{$json.invoice_url}}
''',
      )
      // Log to Supabase activity table
      .httpRequest(
        name: 'Log Activity in Supabase',
        url: 'https://your-project.supabase.co/rest/v1/activity_logs',
        method: 'POST',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
          },
          'body': {
            'type': 'invoice_generated',
            'booking_id': r'={{$json.booking_id}}',
            'invoice_id': r'={{$json.invoice_id}}',
            'customer_id': r'={{$json.customer_id}}',
            'metadata': {
              'invoice_number': r'={{$json.invoice_number}}',
              'amount': r'={{$json.total}}',
              'currency': r'={{$json.currency}}',
            },
          },
        },
      )
      // Notify team on Slack
      .slack(
        name: 'Notify Team',
        channel: '#billing',
        text: r'💰 Invoice {{$json.invoice_number}} generated for {{$json.customer_name}} - ${{$json.total}} {{$json.currency}} | Booking: {{$json.confirmation_code}}',
      )
      // Return success response
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 201,
        responseBody: {
          'success': true,
          'invoice_id': r'={{$json.invoice_id}}',
          'invoice_number': r'={{$json.invoice_number}}',
          'booking_id': r'={{$json.booking_id}}',
          'total': r'={{$json.total}}',
          'currency': r'={{$json.currency}}',
          'invoice_url': r'={{$json.invoice_url}}',
          'pdf_url': r'={{$json.pdf_url}}',
          'email_sent': true,
          'message': 'Invoice generated and sent successfully',
        },
      )
      // Connect all nodes
      .connect('Booking Completed', 'Validate Booking ID')
      .connect('Validate Booking ID', 'Get Booking from Supabase')
      .connect('Get Booking from Supabase', 'Prepare Booking Data')
      .connect('Prepare Booking Data', 'Booking Completed?')
      .connect('Booking Completed?', 'Return Not Completed', sourceIndex: 1)
      .connect('Booking Completed?', 'Calculate Invoice', sourceIndex: 0)
      .connect('Calculate Invoice', 'Create Invoice in Supabase')
      .connect('Create Invoice in Supabase', 'Prepare Invoice Data')
      .connect('Prepare Invoice Data', 'Link Invoice to Booking')
      .connect('Link Invoice to Booking', 'Generate Invoice PDF')
      .connect('Generate Invoice PDF', 'Email Invoice to Customer')
      .connect('Email Invoice to Customer', 'Notify Accounting')
      .connect('Notify Accounting', 'Log Activity in Supabase')
      .connect('Log Activity in Supabase', 'Notify Team')
      .connect('Notify Team', 'Return Success')
      .build();

  await workflow.saveToFile('$outputPath/18_supabase_booking_invoice.json');
  print('   ✓ Generated: 18_supabase_booking_invoice.json\n');
}

/// Example 17: Stripe Payment with Supabase Booking & Invoice
/// Complete payment flow: Stripe checkout → Supabase booking → Auto invoice
Future<void> example17StripeBookingInvoice(String outputPath) async {
  print('📝 Example 17: Stripe Payment + Booking + Invoice');

  final workflow = WorkflowBuilder.create()
      .name('Stripe Payment to Booking & Invoice')
      .tags(['stripe', 'supabase', 'booking', 'invoice', 'payment', 'e-commerce'])
      .active(true)
      // Webhook triggered by Stripe checkout completion
      .webhookTrigger(
        name: 'Stripe Checkout Completed',
        path: 'stripe/checkout/completed',
        method: 'POST',
      )
      // Validate Stripe webhook signature and extract data
      .function(
        name: 'Validate Stripe Webhook',
        code: r'''
const event = $input.item.json;

// Verify event type
if (event.type !== 'checkout.session.completed') {
  throw new Error('Unsupported event type: ' + event.type);
}

const session = event.data.object;

// Extract booking metadata from Stripe session
return {
  stripe_session_id: session.id,
  stripe_customer_id: session.customer,
  stripe_payment_intent: session.payment_intent,
  stripe_amount_total: session.amount_total / 100, // Convert cents to dollars
  stripe_currency: session.currency.toUpperCase(),
  payment_status: session.payment_status,

  // Booking data from Stripe metadata
  customer_email: session.customer_details?.email || session.customer_email,
  customer_name: session.customer_details?.name || session.metadata?.customer_name,
  customer_phone: session.customer_details?.phone || session.metadata?.customer_phone,
  service_id: session.metadata?.service_id,
  booking_date: session.metadata?.booking_date,
  booking_time: session.metadata?.booking_time,
  duration_minutes: parseInt(session.metadata?.duration_minutes) || 60,
  notes: session.metadata?.notes || '',

  timestamp: new Date().toISOString()
};
''',
      )
      // Check payment status
      .ifNode(
        name: 'Payment Successful?',
        conditions: [
          {
            'leftValue': r'={{$json.payment_status}}',
            'operation': 'equals',
            'rightValue': 'paid',
          }
        ],
      )
      // Payment failed - log and notify
      .newRow()
      .httpRequest(
        name: 'Log Failed Payment',
        url: 'https://your-project.supabase.co/rest/v1/payment_logs',
        method: 'POST',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
          },
          'body': {
            'stripe_session_id': r'={{$json.stripe_session_id}}',
            'status': 'failed',
            'amount': r'={{$json.stripe_amount_total}}',
            'currency': r'={{$json.stripe_currency}}',
            'error': 'Payment not completed',
          },
        },
      )
      .respondToWebhook(
        name: 'Return Payment Failed',
        responseCode: 400,
        responseBody: {
          'success': false,
          'error': 'Payment not completed',
        },
      )
      // Payment successful - create booking
      .newRow()
      .httpRequest(
        name: 'Create Booking in Supabase',
        url: 'https://your-project.supabase.co/rest/v1/bookings',
        method: 'POST',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          'body': {
            'customer_name': r'={{$json.customer_name}}',
            'customer_email': r'={{$json.customer_email}}',
            'customer_phone': r'={{$json.customer_phone}}',
            'service_id': r'={{$json.service_id}}',
            'booking_date': r'={{$json.booking_date}}',
            'booking_time': r'={{$json.booking_time}}',
            'duration_minutes': r'={{$json.duration_minutes}}',
            'notes': r'={{$json.notes}}',
            'status': 'confirmed',
            'payment_status': 'paid',
            'stripe_session_id': r'={{$json.stripe_session_id}}',
            'stripe_payment_intent': r'={{$json.stripe_payment_intent}}',
            'amount_paid': r'={{$json.stripe_amount_total}}',
            'currency': r'={{$json.stripe_currency}}',
          },
        },
      )
      // Get service details
      .httpRequest(
        name: 'Get Service Details',
        url: r'https://your-project.supabase.co/rest/v1/services?id=eq.{{$json.service_id}}&select=*&limit=1',
        method: 'GET',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
          },
        },
      )
      // Merge data and generate confirmation
      .function(
        name: 'Prepare Booking Confirmation',
        code: r'''
const paymentData = $input.first().json;
const booking = $input.item(1).json[0];
const service = $input.last().json[0];

// Generate confirmation code
const confirmationCode = Math.random().toString(36).substring(2, 8).toUpperCase();

return {
  // Payment info
  stripe_session_id: paymentData.stripe_session_id,
  stripe_payment_intent: paymentData.stripe_payment_intent,
  amount_paid: paymentData.stripe_amount_total,
  currency: paymentData.stripe_currency,

  // Booking info
  booking_id: booking.id,
  confirmation_code: confirmationCode,
  customer_name: booking.customer_name,
  customer_email: booking.customer_email,
  customer_phone: booking.customer_phone,
  booking_date: booking.booking_date,
  booking_time: booking.booking_time,
  duration_minutes: booking.duration_minutes,
  notes: booking.notes,

  // Service info
  service_id: service.id,
  service_name: service.name,
  service_description: service.description,
  service_price: service.price,
  hourly_rate: service.hourly_rate || 100
};
''',
      )
      // Update booking with confirmation code
      .httpRequest(
        name: 'Update Booking Confirmation',
        url: r'https://your-project.supabase.co/rest/v1/bookings?id=eq.{{$json.booking_id}}',
        method: 'PATCH',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
          },
          'body': {
            'confirmation_code': r'={{$json.confirmation_code}}',
            'status': 'confirmed',
          },
        },
      )
      // Generate invoice
      .function(
        name: 'Calculate Invoice',
        code: r'''
const data = $input.item.json;

// Use actual Stripe payment amount
const subtotal = data.amount_paid / 1.10; // Reverse calculate if tax included
const tax_rate = 0.10;
const tax_amount = subtotal * tax_rate;
const total = data.amount_paid;

// Generate invoice number
const invoice_number = `INV-${new Date().getFullYear()}-${String(Date.now()).slice(-6)}`;
const invoice_date = new Date().toISOString().split('T')[0];
const due_date = invoice_date; // Already paid via Stripe

return {
  ...data,
  invoice_number: invoice_number,
  invoice_date: invoice_date,
  due_date: due_date,
  subtotal: subtotal.toFixed(2),
  tax_rate: (tax_rate * 100).toFixed(0),
  tax_amount: tax_amount.toFixed(2),
  total: total.toFixed(2),
  payment_method: 'Stripe',
  invoice_status: 'paid' // Already paid via Stripe
};
''',
      )
      // Create invoice in Supabase
      .httpRequest(
        name: 'Create Invoice in Supabase',
        url: 'https://your-project.supabase.co/rest/v1/invoices',
        method: 'POST',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
            'Prefer': 'return=representation',
          },
          'body': {
            'booking_id': r'={{$json.booking_id}}',
            'invoice_number': r'={{$json.invoice_number}}',
            'invoice_date': r'={{$json.invoice_date}}',
            'due_date': r'={{$json.due_date}}',
            'subtotal': r'={{$json.subtotal}}',
            'tax_rate': r'={{$json.tax_rate}}',
            'tax_amount': r'={{$json.tax_amount}}',
            'total': r'={{$json.total}}',
            'currency': r'={{$json.currency}}',
            'status': 'paid',
            'payment_method': 'Stripe',
            'stripe_session_id': r'={{$json.stripe_session_id}}',
            'stripe_payment_intent': r'={{$json.stripe_payment_intent}}',
            'paid_at': r'={{$json.invoice_date}}',
            'line_items': [
              {
                'description': r'={{$json.service_name}}',
                'quantity': r'={{$json.duration_minutes}}',
                'unit': 'minutes',
                'rate': r'={{$json.hourly_rate}}',
                'amount': r'={{$json.subtotal}}',
              }
            ],
          },
        },
      )
      // Prepare confirmation data
      .function(
        name: 'Prepare Email Data',
        code: r'''
const data = $input.first().json;
const invoice = $input.last().json[0];

return {
  ...data,
  invoice_id: invoice.id,
  invoice_url: `https://example.com/invoices/${data.invoice_number}`,
  receipt_url: `https://example.com/receipts/${data.stripe_session_id}`
};
''',
      )
      // Send booking confirmation & receipt email
      .emailSend(
        name: 'Send Confirmation & Receipt',
        fromEmail: 'bookings@example.com',
        toEmail: r'={{$json.customer_email}}',
        subject: r'Payment Confirmed - Booking {{$json.confirmation_code}}',
        message: r'''
Hi {{$json.customer_name}},

Thank you for your payment! Your booking is confirmed. ✅

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💳 PAYMENT CONFIRMATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Amount Paid: ${{$json.total}} {{$json.currency}}
Payment Method: Stripe
Transaction ID: {{$json.stripe_payment_intent}}
Payment Status: PAID ✓

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 BOOKING DETAILS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Confirmation Code: {{$json.confirmation_code}}
Service: {{$json.service_name}}
Date: {{$json.booking_date}}
Time: {{$json.booking_time}}
Duration: {{$json.duration_minutes}} minutes

Notes: {{$json.notes}}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📄 INVOICE & RECEIPT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Invoice #: {{$json.invoice_number}}
Invoice: {{$json.invoice_url}}
Receipt: {{$json.receipt_url}}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Need to reschedule? Use your confirmation code.

Questions? Reply to this email.

See you soon!

Best regards,
Your Team
''',
      )
      // Send invoice to accounting
      .emailSend(
        name: 'Notify Accounting',
        fromEmail: 'billing@example.com',
        toEmail: 'accounting@example.com',
        subject: r'Stripe Payment Received: {{$json.invoice_number}} - ${{$json.total}}',
        message: r'''
Stripe payment processed and invoice generated:

Customer: {{$json.customer_name}} ({{$json.customer_email}})
Booking: {{$json.confirmation_code}}
Service: {{$json.service_name}}

Payment Details:
• Amount: ${{$json.total}} {{$json.currency}}
• Method: Stripe
• Session ID: {{$json.stripe_session_id}}
• Payment Intent: {{$json.stripe_payment_intent}}
• Status: PAID

Invoice #: {{$json.invoice_number}}
View: {{$json.invoice_url}}
''',
      )
      // Create Stripe customer in Supabase for future reference
      .httpRequest(
        name: 'Update Customer Stripe ID',
        url: r'https://your-project.supabase.co/rest/v1/customers?email=eq.{{$json.customer_email}}',
        method: 'PATCH',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
          },
          'body': {
            'stripe_customer_id': r'={{$json.stripe_customer_id}}',
            'last_payment_at': r'={{$json.invoice_date}}',
          },
        },
      )
      // Log activity
      .httpRequest(
        name: 'Log Payment Activity',
        url: 'https://your-project.supabase.co/rest/v1/activity_logs',
        method: 'POST',
        additionalParams: {
          'headers': {
            'apikey': 'your-supabase-anon-key',
            'Authorization': 'Bearer your-supabase-anon-key',
            'Content-Type': 'application/json',
          },
          'body': {
            'type': 'stripe_payment_completed',
            'booking_id': r'={{$json.booking_id}}',
            'invoice_id': r'={{$json.invoice_id}}',
            'metadata': {
              'stripe_session_id': r'={{$json.stripe_session_id}}',
              'stripe_payment_intent': r'={{$json.stripe_payment_intent}}',
              'amount': r'={{$json.total}}',
              'currency': r'={{$json.currency}}',
              'invoice_number': r'={{$json.invoice_number}}',
            },
          },
        },
      )
      // Notify team
      .slack(
        name: 'Notify Team',
        channel: '#bookings',
        text: r'💰 Stripe Payment: ${{$json.total}} {{$json.currency}} | {{$json.customer_name}} - {{$json.service_name}} | Booking: {{$json.confirmation_code}} | Invoice: {{$json.invoice_number}}',
      )
      // Return success
      .respondToWebhook(
        name: 'Return Success',
        responseCode: 200,
        responseBody: {
          'success': true,
          'booking_id': r'={{$json.booking_id}}',
          'confirmation_code': r'={{$json.confirmation_code}}',
          'invoice_id': r'={{$json.invoice_id}}',
          'invoice_number': r'={{$json.invoice_number}}',
          'stripe_session_id': r'={{$json.stripe_session_id}}',
          'amount_paid': r'={{$json.total}}',
          'currency': r'={{$json.currency}}',
          'message': 'Payment processed, booking confirmed, and invoice generated',
        },
      )
      // Connect all nodes
      .connect('Stripe Checkout Completed', 'Validate Stripe Webhook')
      .connect('Validate Stripe Webhook', 'Payment Successful?')
      .connect('Payment Successful?', 'Log Failed Payment', sourceIndex: 1)
      .connect('Log Failed Payment', 'Return Payment Failed')
      .connect('Payment Successful?', 'Create Booking in Supabase', sourceIndex: 0)
      .connect('Create Booking in Supabase', 'Get Service Details')
      .connect('Get Service Details', 'Prepare Booking Confirmation')
      .connect('Prepare Booking Confirmation', 'Update Booking Confirmation')
      .connect('Update Booking Confirmation', 'Calculate Invoice')
      .connect('Calculate Invoice', 'Create Invoice in Supabase')
      .connect('Create Invoice in Supabase', 'Prepare Email Data')
      .connect('Prepare Email Data', 'Send Confirmation & Receipt')
      .connect('Send Confirmation & Receipt', 'Notify Accounting')
      .connect('Notify Accounting', 'Update Customer Stripe ID')
      .connect('Update Customer Stripe ID', 'Log Payment Activity')
      .connect('Log Payment Activity', 'Notify Team')
      .connect('Notify Team', 'Return Success')
      .build();

  await workflow.saveToFile('$outputPath/19_stripe_booking_invoice.json');
  print('   ✓ Generated: 19_stripe_booking_invoice.json\n');
}
