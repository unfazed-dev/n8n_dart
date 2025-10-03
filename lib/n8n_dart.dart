/// n8n_dart - Production-ready Dart package for n8n workflow automation
///
/// This library provides a comprehensive, type-safe client for interacting with
/// n8n workflow automation platform. It supports both pure Dart applications
/// and Flutter mobile/web apps.
///
/// ## Features
///
/// - ✅ Pure Dart core (no Flutter dependencies)
/// - ✅ Type-safe models with validation
/// - ✅ Intelligent error handling with retry logic
/// - ✅ Smart polling with multiple strategies
/// - ✅ Stream resilience with recovery mechanisms
/// - ✅ Configuration profiles for common use cases
/// - ✅ Webhook validation and health checks
///
/// ## Core Usage (Dart)
///
/// ```dart
/// import 'package:n8n_dart/n8n_dart.dart';
///
/// void main() async {
///   // Create client
///   final client = N8nClient(
///     config: N8nConfigProfiles.production(
///       baseUrl: 'https://n8n.example.com',
///       apiKey: 'your-api-key',
///     ),
///   );
///
///   // Start workflow
///   final executionId = await client.startWorkflow(
///     'my-webhook-id',
///     {'name': 'John', 'action': 'process'},
///   );
///
///   // Get status
///   final execution = await client.getExecutionStatus(executionId);
///   print('Status: ${execution.status}');
///
///   // Dispose
///   client.dispose();
/// }
/// ```
///
/// ## Flutter Usage
///
/// For Flutter-specific features (reactive streams, widgets), use:
/// ```dart
/// import 'package:n8n_dart/n8n_dart_flutter.dart';
/// ```
///
/// ## Configuration
///
/// The package provides several preset configurations:
///
/// - `N8nConfigProfiles.minimal()` - Basic usage
/// - `N8nConfigProfiles.development()` - Development with logging
/// - `N8nConfigProfiles.production()` - Production with security
/// - `N8nConfigProfiles.resilient()` - For unreliable networks
/// - `N8nConfigProfiles.highPerformance()` - For demanding apps
/// - `N8nConfigProfiles.batteryOptimized()` - For mobile devices
///
/// Or build custom configuration:
/// ```dart
/// final config = N8nConfigBuilder()
///   .baseUrl('https://n8n.example.com')
///   .environment(N8nEnvironment.production)
///   .security(SecurityConfig.production(apiKey: 'key'))
///   .build();
/// ```
library n8n_dart;

// Core models
export 'src/core/models/n8n_models.dart';

// Configuration
export 'src/core/configuration/n8n_configuration.dart';

// Services
export 'src/core/services/n8n_client.dart';
export 'src/core/services/polling_manager.dart';
export 'src/core/services/stream_recovery.dart';

// Exceptions
export 'src/core/exceptions/error_handling.dart';

// Workflow Generator
export 'src/workflow_generator/models/workflow_models.dart';
export 'src/workflow_generator/workflow_builder.dart';
export 'src/workflow_generator/templates/workflow_templates.dart';
