/// n8n_dart Flutter Integration
///
/// This library provides guidance for integrating n8n_dart in Flutter applications.
/// The core `n8n_dart` package is pure Dart and works perfectly in Flutter apps.
///
/// ## Using n8n_dart in Flutter
///
/// ```dart
/// import 'package:n8n_dart/n8n_dart.dart';
/// import 'package:rxdart/rxdart.dart';
///
/// // Create a reactive wrapper for Flutter
/// class N8nFlutterService {
///   final N8nClient client;
///   final BehaviorSubject<WorkflowExecution?> _execution$ =
///       BehaviorSubject.seeded(null);
///
///   Stream<WorkflowExecution?> get execution$ => _execution$.stream;
///
///   N8nFlutterService({required N8nServiceConfig config})
///       : client = N8nClient(config: config);
///
///   Future<void> startWorkflow(String webhookId, Map<String, dynamic>? data) async {
///     final executionId = await client.startWorkflow(webhookId, data);
///
///     // Start polling
///     Timer.periodic(Duration(seconds: 2), (timer) async {
///       try {
///         final execution = await client.getExecutionStatus(executionId);
///         _execution$.add(execution);
///
///         if (execution.isFinished) {
///           timer.cancel();
///         }
///       } catch (error) {
///         timer.cancel();
///         _execution$.addError(error);
///       }
///     });
///   }
///
///   void dispose() {
///     _execution$.close();
///     client.dispose();
///   }
/// }
/// ```
///
/// ## Using with StreamBuilder
///
/// ```dart
/// StreamBuilder<WorkflowExecution?>(
///   stream: n8nService.execution$,
///   builder: (context, snapshot) {
///     if (!snapshot.hasData) return CircularProgressIndicator();
///
///     final execution = snapshot.data!;
///     if (execution.waitingForInput) {
///       return buildDynamicForm(execution.waitNodeData!);
///     }
///
///     return StatusDisplay(status: execution.status);
///   },
/// )
/// ```
///
/// **Note:** The core n8n_dart package is pure Dart with no Flutter dependencies.
/// Create your own reactive wrappers using RxDart and the core N8nClient as shown above.
library n8n_dart_flutter;

// Export core functionality - works perfectly in Flutter
export 'n8n_dart.dart';
