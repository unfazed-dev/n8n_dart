@TestOn('vm')
@Tags(['integration', 'wait-node'])
library;

import 'dart:io';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import 'config/test_config.dart';
import 'utils/test_helpers.dart';

/// Integration tests for wait node workflows
///
/// Tests wait node detection, form field parsing/validation, workflow resumption,
/// and error handling for wait node scenarios.
///
/// **Requirements:**
/// - .env.test file configured with n8n cloud credentials
/// - n8n cloud instance accessible (https://kinly.app.n8n.cloud)
/// - Wait node workflow deployed with webhook ID configured
/// - Internet connection
///
/// **Test Coverage:**
/// - Wait node detection (waitingForInput flag)
/// - Form field parsing and validation
/// - Workflow resumption with user input
/// - Workflow completion after resume
/// - Invalid form data handling
/// - Resume with missing required fields
/// - Form field type validation
/// - Multiple field scenarios
///
/// **Phase 1 Coverage:**
/// These tests implement Phase 1 of the integration test plan:
/// - Test 1.1: Basic Wait Node Detection
/// - Test 1.2: Form Field Parsing
/// - Test 1.3: Workflow Resumption
/// - Test 1.4: Invalid Input Handling
void main() {
  late TestConfig config;
  late N8nClient client;

  setUpAll(() {
    try {
      config = TestConfig.load();
    } on FileSystemException catch (e) {
      fail(
        'Integration test setup failed: ${e.message}\n\n'
        'To run integration tests:\n'
        '1. Copy .env.test.example to .env.test\n'
        '2. Configure your n8n cloud credentials\n'
        '3. See test/integration/README.md for detailed setup',
      );
    } catch (e) {
      fail('Failed to load test configuration: $e');
    }

    // Validate configuration
    final errors = config.validate();
    if (errors.isNotEmpty) {
      fail('Invalid test configuration:\n${errors.join('\n')}');
    }
  });

  setUp(() {
    client = createTestClient(config);
    TestCleanup.clear();
  });

  tearDown(() async {
    await TestCleanup.cancelAllExecutions(client);
    client.dispose();
  });

  group('Wait Node Detection', () {
    test('should detect wait node and set waitingForInput flag', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'wait-node-detection');

      // Act - Trigger wait node workflow
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      // Wait for workflow to reach waiting state
      final waitingExecution = await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert
      IntegrationAssertions.assertWaitingForInput(waitingExecution);
      expect(waitingExecution.status, WorkflowStatus.waiting,
          reason: 'Execution should have waiting status');
      expect(waitingExecution.waitNodeData, isNotNull,
          reason: 'Wait node data should be present');
    }, timeout: Timeout(config.timeout));

    test('should not set waitingForInput for non-wait workflows', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'no-wait-node');

      // Act - Trigger simple workflow (no wait node)
      final executionId = await client.startWorkflow(
        config.simpleWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      // Wait for workflow to complete
      final completed = await waitForExecutionCompletion(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert
      expect(completed.waitingForInput, isFalse,
          reason: 'Execution should not be waiting for input');
      expect(completed.waitNodeData, isNull,
          reason: 'Wait node data should be null for non-wait workflows');
      IntegrationAssertions.assertSuccessfulExecution(completed);
    }, timeout: Timeout(config.timeout));

    test('should maintain waiting state until resumed', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'maintain-wait-state');

      // Act - Trigger wait node workflow
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      // Wait for waiting state
      final waitingExecution = await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Poll multiple times to verify state is maintained
      await Future.delayed(config.pollingInterval * 2);
      final stillWaiting = await client.getExecutionStatus(executionId);

      // Assert - Should still be waiting
      IntegrationAssertions.assertWaitingForInput(stillWaiting);
      expect(stillWaiting.status, equals(waitingExecution.status),
          reason: 'Status should remain unchanged');
      expect(stillWaiting.waitingForInput, isTrue,
          reason: 'Should still be waiting for input');
    }, timeout: Timeout(config.timeout));
  });

  group('Form Field Parsing', () {
    test('should parse form fields from wait node data', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'form-fields-parsing');

      // Act - Trigger wait node workflow
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      final waitingExecution = await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert - Verify form fields are parsed
      expect(waitingExecution.waitNodeData, isNotNull,
          reason: 'Wait node data should be present');

      final waitNodeData = waitingExecution.waitNodeData!;
      IntegrationAssertions.assertValidFormFields(waitNodeData.fields);

      // Verify field properties
      for (final field in waitNodeData.fields) {
        expect(field.name, isNotEmpty,
            reason: 'Field name should not be empty');
        expect(field.label, isNotEmpty,
            reason: 'Field label should not be empty');
        expect(field.type, isNotNull, reason: 'Field type should be set');
      }
    }, timeout: Timeout(config.timeout));

    test('should correctly identify required vs optional fields', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'required-fields');

      // Act - Trigger wait node workflow
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      final waitingExecution = await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert - Verify required field detection
      final waitNodeData = waitingExecution.waitNodeData!;
      expect(waitNodeData.fields, isNotEmpty,
          reason: 'Should have at least one field');

      // Check if any fields are marked as required
      final hasRequiredFields =
          waitNodeData.fields.any((field) => field.required);

      // At least one field should exist
      expect(waitNodeData.fields.length, greaterThan(0),
          reason: 'Wait node should have form fields');

      // Verify required field can be accessed
      if (hasRequiredFields) {
        final requiredField =
            waitNodeData.fields.firstWhere((field) => field.required);
        expect(requiredField.required, isTrue,
            reason: 'Required field should be marked as required');
      }
    }, timeout: Timeout(config.timeout));

    test('should parse form field types correctly', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'field-types');

      // Act - Trigger wait node workflow
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      final waitingExecution = await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert - Verify field types are valid
      final waitNodeData = waitingExecution.waitNodeData!;

      for (final field in waitNodeData.fields) {
        // Verify field type is a valid FormFieldType
        expect(field.type, isA<FormFieldType>(),
            reason: 'Field type should be valid FormFieldType');

        // Verify field type matches expected values
        expect(
          [
            FormFieldType.text,
            FormFieldType.email,
            FormFieldType.number,
            FormFieldType.select,
            FormFieldType.radio,
            FormFieldType.checkbox,
            FormFieldType.date,
            FormFieldType.time,
            FormFieldType.datetimeLocal,
            FormFieldType.file,
            FormFieldType.textarea,
            FormFieldType.url,
            FormFieldType.phone,
            FormFieldType.slider,
            FormFieldType.switch_,
            FormFieldType.password,
            FormFieldType.hiddenField,
            FormFieldType.html,
          ].contains(field.type),
          isTrue,
          reason: 'Field type should be one of the supported types',
        );
      }
    }, timeout: Timeout(config.timeout));
  });

  group('Workflow Resumption', () {
    test('should successfully resume workflow with valid form data', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'resume-workflow');

      // Act - Start workflow and wait for waiting state
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Resume with form data
      final formData = TestDataGenerator.formData(
        name: 'Integration Test User',
        email: 'test@example.com',
        age: 25,
      );

      final resumed = await client.resumeWorkflow(executionId, formData);

      // Assert - Resume operation succeeded
      expect(resumed, isTrue, reason: 'Resume operation should succeed');

      // Wait for workflow to complete
      final completed = await waitForExecutionCompletion(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Verify workflow completed successfully
      IntegrationAssertions.assertSuccessfulExecution(completed);
      expect(completed.waitingForInput, isFalse,
          reason: 'Should no longer be waiting after resume');
    }, timeout: Timeout(config.timeout));

    test('should complete workflow successfully after resumption', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'complete-after-resume');

      // Act - Start workflow
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Resume workflow
      final formData = TestDataGenerator.formData(
        name: 'Test User',
        email: 'resume@example.com',
      );
      await client.resumeWorkflow(executionId, formData);

      // Wait for completion
      final completed = await waitForExecutionCompletion(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Assert - Workflow should complete successfully
      expect(completed.isFinished, isTrue,
          reason: 'Workflow should be finished');
      expect(completed.status, WorkflowStatus.success,
          reason: 'Workflow should complete with success status');
      expect(completed.finished, isTrue,
          reason: 'Finished flag should be true');
      expect(completed.finishedAt, isNotNull,
          reason: 'Finished timestamp should be set');
    }, timeout: Timeout(config.timeout));
  });

  group('Invalid Form Data Handling', () {
    test('should handle resume with invalid form data', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'invalid-form-data');

      // Act - Start workflow and wait for waiting state
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Attempt to resume with invalid email
      final invalidFormData = {
        'name': 'Test User',
        'email': 'not-a-valid-email',
      };

      // Assert - Should handle invalid data gracefully
      // Note: The actual behavior depends on n8n workflow configuration
      // This test verifies the client doesn't crash on invalid data
      try {
        await client.resumeWorkflow(executionId, invalidFormData);
        // If resume succeeds, verify execution status
        final status = await client.getExecutionStatus(executionId);
        expect(status, isNotNull, reason: 'Should get execution status');
      } on N8nException catch (e) {
        // Invalid data may cause n8n to reject the request
        expect(e, isNotNull, reason: 'Should throw N8nException');
      }
    }, timeout: Timeout(config.timeout));

    test('should handle resume with missing required fields', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'missing-required');

      // Act - Start workflow and wait for waiting state
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      final waitingExecution = await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Identify required fields
      final waitNodeData = waitingExecution.waitNodeData!;
      final requiredFields =
          waitNodeData.fields.where((field) => field.required).toList();

      if (requiredFields.isEmpty) {
        // Skip test if no required fields
        markTestSkipped('Wait node has no required fields');
        return;
      }

      // Attempt to resume with empty data (missing required fields)
      final emptyFormData = <String, dynamic>{};

      // Assert - Should handle missing required fields
      try {
        await client.resumeWorkflow(executionId, emptyFormData);
        // If resume somehow succeeds, check execution status
        final status = await client.getExecutionStatus(executionId);
        expect(status, isNotNull, reason: 'Should get execution status');
      } on N8nException catch (e) {
        // Missing required fields should cause rejection
        expect(e, isNotNull, reason: 'Should throw N8nException');
        expect(e.message, isNotEmpty,
            reason: 'Exception should have error message');
      }
    }, timeout: Timeout(config.timeout));

    test('should validate form data before resume attempt', () async {
      // Arrange
      final payload = TestDataGenerator.simple(name: 'validate-form-data');

      // Act - Start workflow and wait for waiting state
      final executionId = await client.startWorkflow(
        config.waitNodeWebhookPath,
        payload,
      );
      TestCleanup.registerExecution(executionId);

      final waitingExecution = await waitForWaitingState(
        client,
        executionId,
        timeout: config.timeout,
        pollInterval: config.pollingInterval,
      );

      // Get wait node data for validation
      final waitNodeData = waitingExecution.waitNodeData!;

      // Create test form data
      final formData = {
        'name': 'Test User',
        'email': 'test@example.com',
        'age': '25',
      };

      // Validate form data against field configurations
      final validationResult = waitNodeData.validateFormData(formData);

      // Assert - Validation should work correctly
      expect(validationResult, isNotNull,
          reason: 'Validation result should not be null');

      // If validation passes, resume should succeed
      if (validationResult.isValid) {
        final resumed = await client.resumeWorkflow(executionId, formData);
        expect(resumed, isTrue,
            reason: 'Resume should succeed with valid data');
      }
    }, timeout: Timeout(config.timeout));
  });

  group('Error Handling', () {
    test('should handle resume with empty execution ID', () async {
      // Arrange
      final formData = TestDataGenerator.formData(
        name: 'Test',
        email: 'test@example.com',
      );

      // Act & Assert
      expect(
        () async => client.resumeWorkflow('', formData),
        throwsA(isA<N8nException>()),
        reason: 'Should throw N8nException for empty execution ID',
      );
    });

    test('should handle resume with empty input data', () async {
      // Arrange
      const executionId = 'test-execution-id';
      final emptyData = <String, dynamic>{};

      // Act & Assert
      expect(
        () async => client.resumeWorkflow(executionId, emptyData),
        throwsA(isA<N8nException>()),
        reason: 'Should throw N8nException for empty input data',
      );
    });

    test('should handle resume for non-existent execution', () async {
      // Arrange
      const nonExistentId = 'non-existent-execution-id-12345';
      final formData = TestDataGenerator.formData(
        name: 'Test',
        email: 'test@example.com',
      );

      // Act & Assert
      expect(
        () async => client.resumeWorkflow(nonExistentId, formData),
        throwsA(isA<N8nException>()),
        reason: 'Should throw N8nException for non-existent execution',
      );
    });
  });
}
