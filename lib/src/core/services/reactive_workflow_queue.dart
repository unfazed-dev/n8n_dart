/// Reactive Workflow Queue
///
/// Queue-based workflow execution with automatic throttling and management
library;

import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../models/n8n_models.dart';
import 'reactive_n8n_client.dart';

/// Queue-based workflow execution with automatic throttling
///
/// Features:
/// - BehaviorSubject for queue state
/// - Automatic throttling to prevent server overload
/// - Queue metrics and monitoring
/// - Priority-based processing (optional)
/// - Configurable concurrency limits
class ReactiveWorkflowQueue {
  final ReactiveN8nClient _client;
  final BehaviorSubject<List<QueuedWorkflow>> _queue$ =
      BehaviorSubject.seeded([]);
  final PublishSubject<QueueEvent> _events$ = PublishSubject();
  final ReactiveQueueConfig _config;
  final _uuid = const Uuid();

  ReactiveWorkflowQueue({
    required ReactiveN8nClient client,
    ReactiveQueueConfig? config,
  })  : _client = client,
        _config = config ?? ReactiveQueueConfig.standard();

  /// Stream of queue state (current items)
  Stream<List<QueuedWorkflow>> get queue$ => _queue$.stream;

  /// Stream of queue length
  Stream<int> get queueLength$ => _queue$.stream.map((q) => q.length);

  /// Stream of pending items
  Stream<List<QueuedWorkflow>> get pendingItems$ =>
      _queue$.stream.map((q) => q.where((i) => i.status == QueueStatus.pending).toList());

  /// Stream of processing items
  Stream<List<QueuedWorkflow>> get processingItems$ =>
      _queue$.stream.map((q) => q.where((i) => i.status == QueueStatus.processing).toList());

  /// Stream of completed items
  Stream<List<QueuedWorkflow>> get completedItems$ =>
      _queue$.stream.map((q) => q.where((i) => i.status == QueueStatus.completed).toList());

  /// Stream of failed items
  Stream<List<QueuedWorkflow>> get failedItems$ =>
      _queue$.stream.map((q) => q.where((i) => i.status == QueueStatus.failed).toList());

  /// Stream of queue events
  Stream<QueueEvent> get events$ => _events$.stream;

  /// Stream of queue metrics
  Stream<QueueMetrics> get metrics$ => _queue$.stream.map((queue) {
        final pending = queue.where((i) => i.status == QueueStatus.pending).length;
        final processing = queue.where((i) => i.status == QueueStatus.processing).length;
        final completed = queue.where((i) => i.status == QueueStatus.completed).length;
        final failed = queue.where((i) => i.status == QueueStatus.failed).length;

        return QueueMetrics(
          totalItems: queue.length,
          pendingCount: pending,
          processingCount: processing,
          completedCount: completed,
          failedCount: failed,
          timestamp: DateTime.now(),
        );
      });

  /// Enqueue a workflow for execution
  ///
  /// Returns the ID of the queued item
  String enqueue({
    required String webhookId,
    required Map<String, dynamic> data,
    int priority = 0,
    Map<String, dynamic>? metadata,
  }) {
    final item = QueuedWorkflow(
      id: _uuid.v4(),
      webhookId: webhookId,
      data: data,
      status: QueueStatus.pending,
      enqueuedAt: DateTime.now(),
      priority: priority,
      metadata: metadata,
    );

    final current = _queue$.value;
    final updated = [...current, item];

    // Sort by priority (higher priority first)
    updated.sort((a, b) => b.priority.compareTo(a.priority));

    _queue$.add(updated);
    _events$.add(QueueItemEnqueuedEvent(item: item));

    return item.id;
  }

  /// Enqueue multiple workflows
  List<String> enqueueMultiple(List<QueuedWorkflow> items) {
    final current = _queue$.value;
    final updated = [...current, ...items];

    // Sort by priority
    updated.sort((a, b) => b.priority.compareTo(a.priority));

    _queue$.add(updated);

    for (final item in items) {
      _events$.add(QueueItemEnqueuedEvent(item: item));
    }

    return items.map((i) => i.id).toList();
  }

  /// Remove item from queue
  void remove(String itemId) {
    final current = _queue$.value;
    final item = current.firstWhere((i) => i.id == itemId,
        orElse: () => throw QueueException('Item not found: $itemId'));

    if (item.status == QueueStatus.processing) {
      throw QueueException('Cannot remove item that is currently processing: $itemId');
    }

    _queue$.add(current.where((i) => i.id != itemId).toList());
    _events$.add(QueueItemRemovedEvent(itemId: itemId));
  }

  /// Clear completed items
  void clearCompleted() {
    final current = _queue$.value;
    final remaining = current.where((i) => i.status != QueueStatus.completed).toList();
    _queue$.add(remaining);
    _events$.add(QueueClearedEvent(clearedType: 'completed'));
  }

  /// Clear failed items
  void clearFailed() {
    final current = _queue$.value;
    final remaining = current.where((i) => i.status != QueueStatus.failed).toList();
    _queue$.add(remaining);
    _events$.add(QueueClearedEvent(clearedType: 'failed'));
  }

  /// Clear all items
  void clear() {
    _queue$.add([]);
    _events$.add(QueueClearedEvent(clearedType: 'all'));
  }

  /// Process queue with automatic throttling
  ///
  /// Returns a stream of completed workflow executions
  /// - Throttles based on config.throttleDuration
  /// - Limits concurrent executions to config.maxConcurrent
  /// - Retries failed items based on config.retryFailedItems
  /// - Emits WorkflowExecution as each completes
  Stream<WorkflowExecution> processQueue() {
    return _queue$.stream
        .switchMap((queue) {
          final pending = queue
              .where((item) => item.status == QueueStatus.pending)
              .toList();

          return Stream.fromIterable(pending);
        })
        .throttleTime(_config.throttleDuration)
        .asyncMap((item) async {
          // Update status to processing
          _updateItemStatus(item.id, QueueStatus.processing);
          _events$.add(QueueItemProcessingEvent(item: item));

          try {
            // Start workflow
            final execution = await _client
                .startWorkflow(item.webhookId, item.data)
                .first;

            // Wait for completion if configured
            final result = _config.waitForCompletion
                ? await _client.pollExecutionStatus(execution.id).last
                : execution;

            // Update status to completed
            _updateItemStatus(item.id, QueueStatus.completed, executionId: result.id);
            _events$.add(QueueItemCompletedEvent(item: item, execution: result));

            return result;
          } catch (error) {
            // Update status to failed
            _updateItemStatus(item.id, QueueStatus.failed, error: error.toString());
            _events$.add(QueueItemFailedEvent(item: item, error: error));

            // Retry if configured
            if (_config.retryFailedItems && item.retryCount < _config.maxRetries) {
              _retryItem(item);
            }

            rethrow;
          }
        })
        .onErrorResume((error, stackTrace) {
          // Continue processing despite errors
          return const Stream.empty();
        });
  }

  /// Process queue with concurrency limit
  ///
  /// Processes multiple items concurrently up to maxConcurrent limit
  Stream<WorkflowExecution> processQueueConcurrent() {
    return _queue$.stream
        .switchMap((queue) {
          final pending = queue
              .where((item) => item.status == QueueStatus.pending)
              .take(_config.maxConcurrent)
              .toList();

          return Rx.merge(pending.map(_processItem));
        });
  }

  /// Process a single queue item
  Stream<WorkflowExecution> _processItem(QueuedWorkflow item) async* {
    _updateItemStatus(item.id, QueueStatus.processing);
    _events$.add(QueueItemProcessingEvent(item: item));

    try {
      final execution = await _client.startWorkflow(item.webhookId, item.data).first;

      final result = _config.waitForCompletion
          ? await _client.pollExecutionStatus(execution.id).last
          : execution;

      _updateItemStatus(item.id, QueueStatus.completed, executionId: result.id);
      _events$.add(QueueItemCompletedEvent(item: item, execution: result));

      yield result;
    } catch (error) {
      _updateItemStatus(item.id, QueueStatus.failed, error: error.toString());
      _events$.add(QueueItemFailedEvent(item: item, error: error));

      if (_config.retryFailedItems && item.retryCount < _config.maxRetries) {
        _retryItem(item);
      }

      rethrow;
    }
  }

  /// Update queue item status
  void _updateItemStatus(
    String itemId,
    QueueStatus status, {
    String? executionId,
    String? error,
  }) {
    final current = _queue$.value;
    final updated = current.map((item) {
      if (item.id == itemId) {
        return item.copyWith(
          status: status,
          executionId: executionId,
          error: error,
          processedAt: status == QueueStatus.completed || status == QueueStatus.failed
              ? DateTime.now()
              : null,
        );
      }
      return item;
    }).toList();

    _queue$.add(updated);
  }

  /// Retry a failed queue item
  void _retryItem(QueuedWorkflow item) {
    final current = _queue$.value;
    final updated = current.map((i) {
      if (i.id == item.id) {
        return i.copyWith(
          status: QueueStatus.pending,
          retryCount: i.retryCount + 1,
        );
      }
      return i;
    }).toList();

    _queue$.add(updated);
    _events$.add(QueueItemRetriedEvent(item: item));
  }

  /// Dispose resources
  void dispose() {
    _queue$.close();
    _events$.close();
  }
}

/// Queued workflow item
class QueuedWorkflow {
  final String id;
  final String webhookId;
  final Map<String, dynamic> data;
  final QueueStatus status;
  final DateTime enqueuedAt;
  final DateTime? processedAt;
  final int priority;
  final String? executionId;
  final String? error;
  final int retryCount;
  final Map<String, dynamic>? metadata;

  const QueuedWorkflow({
    required this.id,
    required this.webhookId,
    required this.data,
    required this.status,
    required this.enqueuedAt,
    this.processedAt,
    this.priority = 0,
    this.executionId,
    this.error,
    this.retryCount = 0,
    this.metadata,
  });

  QueuedWorkflow copyWith({
    QueueStatus? status,
    DateTime? processedAt,
    String? executionId,
    String? error,
    int? retryCount,
  }) {
    return QueuedWorkflow(
      id: id,
      webhookId: webhookId,
      data: data,
      status: status ?? this.status,
      enqueuedAt: enqueuedAt,
      processedAt: processedAt ?? this.processedAt,
      priority: priority,
      executionId: executionId ?? this.executionId,
      error: error ?? this.error,
      retryCount: retryCount ?? this.retryCount,
      metadata: metadata,
    );
  }
}

/// Queue status enum
enum QueueStatus {
  pending,
  processing,
  completed,
  failed,
}

/// Queue configuration
class ReactiveQueueConfig {
  final Duration throttleDuration;
  final int maxConcurrent;
  final bool waitForCompletion;
  final bool retryFailedItems;
  final int maxRetries;

  const ReactiveQueueConfig({
    required this.throttleDuration,
    required this.maxConcurrent,
    required this.waitForCompletion,
    required this.retryFailedItems,
    required this.maxRetries,
  });

  factory ReactiveQueueConfig.standard() => const ReactiveQueueConfig(
        throttleDuration: Duration(seconds: 1),
        maxConcurrent: 3,
        waitForCompletion: true,
        retryFailedItems: true,
        maxRetries: 3,
      );

  factory ReactiveQueueConfig.fast() => const ReactiveQueueConfig(
        throttleDuration: Duration(milliseconds: 500),
        maxConcurrent: 5,
        waitForCompletion: false,
        retryFailedItems: false,
        maxRetries: 0,
      );

  factory ReactiveQueueConfig.reliable() => const ReactiveQueueConfig(
        throttleDuration: Duration(seconds: 2),
        maxConcurrent: 2,
        waitForCompletion: true,
        retryFailedItems: true,
        maxRetries: 5,
      );
}

/// Queue metrics
class QueueMetrics {
  final int totalItems;
  final int pendingCount;
  final int processingCount;
  final int completedCount;
  final int failedCount;
  final DateTime timestamp;

  const QueueMetrics({
    required this.totalItems,
    required this.pendingCount,
    required this.processingCount,
    required this.completedCount,
    required this.failedCount,
    required this.timestamp,
  });

  double get completionRate {
    if (totalItems == 0) return 0;
    return completedCount / totalItems;
  }

  double get failureRate {
    if (totalItems == 0) return 0;
    return failedCount / totalItems;
  }
}

/// Queue events
abstract class QueueEvent {
  final DateTime timestamp;

  const QueueEvent({required this.timestamp});
}

class QueueItemEnqueuedEvent extends QueueEvent {
  final QueuedWorkflow item;

  QueueItemEnqueuedEvent({required this.item}) : super(timestamp: DateTime.now());
}

class QueueItemProcessingEvent extends QueueEvent {
  final QueuedWorkflow item;

  QueueItemProcessingEvent({required this.item}) : super(timestamp: DateTime.now());
}

class QueueItemCompletedEvent extends QueueEvent {
  final QueuedWorkflow item;
  final WorkflowExecution execution;

  QueueItemCompletedEvent({required this.item, required this.execution})
      : super(timestamp: DateTime.now());
}

class QueueItemFailedEvent extends QueueEvent {
  final QueuedWorkflow item;
  final Object error;

  QueueItemFailedEvent({required this.item, required this.error})
      : super(timestamp: DateTime.now());
}

class QueueItemRetriedEvent extends QueueEvent {
  final QueuedWorkflow item;

  QueueItemRetriedEvent({required this.item}) : super(timestamp: DateTime.now());
}

class QueueItemRemovedEvent extends QueueEvent {
  final String itemId;

  QueueItemRemovedEvent({required this.itemId}) : super(timestamp: DateTime.now());
}

class QueueClearedEvent extends QueueEvent {
  final String clearedType;

  QueueClearedEvent({required this.clearedType}) : super(timestamp: DateTime.now());
}

/// Queue exception
class QueueException implements Exception {
  final String message;

  const QueueException(this.message);

  @override
  String toString() => 'QueueException: $message';
}
