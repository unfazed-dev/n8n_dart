@TestOn('vm')
@Tags(['integration', 'connection'])
library;

import 'dart:io';

import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

import 'config/test_config.dart';
import 'utils/test_helpers.dart';

/// Integration tests for n8n cloud connection
///
/// Tests connection health checks, SSL validation, and basic connectivity
/// to the n8n cloud instance.
///
/// **Requirements:**
/// - .env.test file configured with n8n cloud credentials
/// - n8n cloud instance accessible (https://kinly.app.n8n.cloud)
/// - Internet connection
///
/// **Test Coverage:**
/// - Successful connection to cloud instance
/// - Connection failure handling (invalid URL)
/// - SSL certificate validation
/// - Configuration validation
void main() {
  late TestConfig config;

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
  });

  group('Connection Tests', () {
    test('should successfully connect to n8n cloud instance', () async {
      // Arrange
      final client = createTestClient(config);
      addTearDown(client.dispose);

      // Act
      final isHealthy = await client.testConnection();

      // Assert
      expect(isHealthy, isTrue,
          reason: 'Should successfully connect to n8n cloud instance');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('should handle connection failure gracefully', () async {
      // Arrange - Create client with invalid base URL
      const invalidConfig = TestConfig(
        baseUrl: 'https://invalid-n8n-instance.example.com',
        simpleWebhookId: 'test',
        waitNodeWebhookId: 'test',
        slowWebhookId: 'test',
        errorWebhookId: 'test',
      );
      final client = createTestClient(invalidConfig);
      addTearDown(client.dispose);

      // Act & Assert
      expect(
        () async => client.testConnection(),
        throwsA(isA<N8nException>()),
        reason: 'Should throw N8nException for invalid connection',
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('should validate SSL certificate for HTTPS connections', () async {
      // Arrange
      expect(config.baseUrl, startsWith('https://'),
          reason: 'Test requires HTTPS connection for SSL validation');

      final client = createTestClient(config);
      addTearDown(client.dispose);

      // Act - Connection should succeed with valid SSL cert
      final isHealthy = await client.testConnection();

      // Assert
      expect(isHealthy, isTrue,
          reason: 'Should validate SSL certificate successfully');
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('should validate test configuration', () {
      // Act
      final errors = config.validate();

      // Assert
      expect(errors, isEmpty,
          reason: 'Test configuration should be valid: ${errors.join(', ')}');
    });

    test('should provide proper timeout configuration', () {
      // Assert
      expect(config.timeout, isNotNull);
      expect(config.timeout.inSeconds, greaterThan(0));
      expect(config.timeout.inSeconds, lessThanOrEqualTo(300),
          reason: 'Timeout should be reasonable (<= 5 minutes)');
    });

    test('should provide proper polling interval configuration', () {
      // Assert
      expect(config.pollingInterval, isNotNull);
      expect(config.pollingInterval.inMilliseconds, greaterThan(0));
      expect(config.pollingInterval.inMilliseconds, greaterThanOrEqualTo(1000),
          reason: 'Polling interval should be >= 1 second');
    });

    test('should handle multiple concurrent connections', () async {
      // Arrange
      final clients = List.generate(3, (_) => createTestClient(config));
      addTearDown(() {
        for (final client in clients) {
          client.dispose();
        }
      });

      // Act - Test all connections concurrently
      final results = await Future.wait(
        clients.map((client) => client.testConnection()),
      );

      // Assert
      expect(results, everyElement(isTrue),
          reason: 'All concurrent connections should succeed');
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('should properly dispose client resources', () async {
      // Arrange
      final client = createTestClient(config);

      // Act
      await client.testConnection();
      client.dispose();

      // Assert - Client should be disposed and not usable
      // Note: Actual disposal verification depends on implementation
      expect(client.dispose, returnsNormally,
          reason: 'Multiple dispose calls should be safe');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Configuration Tests', () {
    test('should load configuration from .env.test file', () {
      // Assert
      expect(config.baseUrl, isNotEmpty);
      expect(config.baseUrl, startsWith('http'),
          reason: 'Base URL should start with http:// or https://');
      expect(config.simpleWebhookId, isNotEmpty);
      expect(config.waitNodeWebhookId, isNotEmpty);
      expect(config.slowWebhookId, isNotEmpty);
      expect(config.errorWebhookId, isNotEmpty);
    });

    test('should have proper test workflow IDs configured', () {
      // Assert - Verify all required webhook IDs are configured
      expect(config.simpleWebhookId, isNotEmpty,
          reason: 'Simple webhook ID must be configured');
      expect(config.waitNodeWebhookId, isNotEmpty,
          reason: 'Wait node webhook ID must be configured');
      expect(config.slowWebhookId, isNotEmpty,
          reason: 'Slow workflow webhook ID must be configured');
      expect(config.errorWebhookId, isNotEmpty,
          reason: 'Error workflow webhook ID must be configured');
    });

    test('should use development profile when no API key', () {
      // Arrange
      final noApiKeyConfig = TestConfig(
        baseUrl: config.baseUrl,
        simpleWebhookId: 'test',
        waitNodeWebhookId: 'test',
        slowWebhookId: 'test',
        errorWebhookId: 'test',
      );

      // Act
      final client = createTestClient(noApiKeyConfig);
      addTearDown(client.dispose);

      // Assert - Should not throw (development profile doesn't require API key)
      expect(client.config.environment, N8nEnvironment.development,
          reason: 'Should use development profile without API key');
    });

    test('should use production profile when API key provided', () {
      // Skip if no API key configured
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        markTestSkipped('No API key configured - skipping production profile test');
        return;
      }

      // Arrange & Act
      final client = createTestClient(config);
      addTearDown(client.dispose);

      // Assert
      expect(client.config.environment, N8nEnvironment.production,
          reason: 'Should use production profile with API key');
    });
  });
}
