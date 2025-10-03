/// Example: Generating n8n Workflows Programmatically
///
/// This example demonstrates how to use the n8n_dart workflow generator
/// to create n8n workflow JSON files that can be imported into n8n.

import 'dart:io';
import 'package:n8n_dart/n8n_dart.dart';

void main() async {
  print('🚀 n8n Workflow Generator Examples\n');

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

  print('\n✅ All workflows generated successfully!');
  print('📁 Check the "generated_workflows" directory for JSON files.');
  print('\n📤 Import these files into n8n:');
  print('   1. Open n8n UI');
  print('   2. Click "..." menu → Import from File');
  print('   3. Select the generated JSON file');
  print('   4. Configure credentials (if needed)');
  print('   5. Activate the workflow\n');
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

  // Save to file
  await workflow.saveToFile('$outputPath/01_simple_webhook_to_db.json');
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
