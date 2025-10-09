import 'dart:io';
import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('CredentialManager', () {
    late Directory tempDir;
    late File tempEnvFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('n8n_test_');
      tempEnvFile = File('${tempDir.path}/.env.test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    group('Constructor', () {
      test('creates instance with default environment', () {
        final manager = CredentialManager();
        expect(manager, isNotNull);
      });

      test('creates instance with custom environment', () {
        final customEnv = {'N8N_BASE_URL': 'https://test.n8n.cloud'};
        final manager = CredentialManager(env: customEnv);
        expect(manager.n8nBaseUrl, equals('https://test.n8n.cloud'));
      });
    });

    group('fromEnvFile', () {
      test('loads credentials from .env file', () {
        tempEnvFile.writeAsStringSync('''
# Test environment file
N8N_BASE_URL=https://test.n8n.cloud
N8N_API_KEY=test_api_key_123

SUPABASE_URL=https://test.supabase.co
SUPABASE_KEY=test_supabase_key

POSTGRES_HOST=db.example.com
POSTGRES_PASSWORD=test_password
''');

        final manager = CredentialManager.fromEnvFile(tempEnvFile.path);
        expect(manager.n8nBaseUrl, equals('https://test.n8n.cloud'));
        expect(manager.n8nApiKey, equals('test_api_key_123'));
        expect(manager.supabaseUrl, equals('https://test.supabase.co'));
        expect(manager.supabaseKey, equals('test_supabase_key'));
      });

      test('handles values with equals signs', () {
        tempEnvFile.writeAsStringSync('''
N8N_API_KEY=abc=123=xyz
''');

        final manager = CredentialManager.fromEnvFile(tempEnvFile.path);
        expect(manager.n8nApiKey, equals('abc=123=xyz'));
      });

      test('skips comments and empty lines', () {
        tempEnvFile.writeAsStringSync('''
# This is a comment
N8N_BASE_URL=https://test.n8n.cloud

# Another comment
N8N_API_KEY=test_key
''');

        final manager = CredentialManager.fromEnvFile(tempEnvFile.path);
        expect(manager.n8nBaseUrl, equals('https://test.n8n.cloud'));
        expect(manager.n8nApiKey, equals('test_key'));
      });

      test('throws if file does not exist', () {
        expect(
          () => CredentialManager.fromEnvFile('/nonexistent/.env'),
          throwsException,
        );
      });
    });

    group('Credential Status Checks', () {
      test('hasN8nCredentials returns true when both URL and key are set', () {
        final manager = CredentialManager(env: {
          'N8N_BASE_URL': 'https://test.n8n.cloud',
          'N8N_API_KEY': 'test_key',
        });
        expect(manager.hasN8nCredentials, isTrue);
      });

      test('hasN8nCredentials returns false when URL is missing', () {
        final manager = CredentialManager(env: {
          'N8N_API_KEY': 'test_key',
        });
        expect(manager.hasN8nCredentials, isFalse);
      });

      test('hasSupabaseCredentials returns true when both URL and key are set',
          () {
        final manager = CredentialManager(env: {
          'SUPABASE_URL': 'https://test.supabase.co',
          'SUPABASE_KEY': 'test_key',
        });
        expect(manager.hasSupabaseCredentials, isTrue);
      });

      test('hasPostgresCredentials returns true when host and password are set',
          () {
        final manager = CredentialManager(env: {
          'SUPABASE_DB_HOST': 'db.example.com',
          'SUPABASE_DB_PASSWORD': 'test_password',
        });
        expect(manager.hasPostgresCredentials, isTrue);
      });
    });

    group('Credential Getters', () {
      test('getPostgresCredential returns correctly formatted credential', () {
        final manager = CredentialManager(env: {
          'SUPABASE_DB_HOST': 'db.example.com',
          'SUPABASE_DB_PASSWORD': 'test_password',
        });

        final credential = manager.getPostgresCredential(
          credentialId: 'cred_123',
          credentialName: 'My PostgreSQL',
        );

        expect(credential, isNotNull);
        expect(credential!['postgres'], isNotNull);
        expect(credential['postgres']['id'], equals('cred_123'));
        expect(credential['postgres']['name'], equals('My PostgreSQL'));
      });

      test('getPostgresCredential uses default name when not provided', () {
        final manager = CredentialManager(env: {
          'SUPABASE_DB_HOST': 'db.example.com',
          'SUPABASE_DB_PASSWORD': 'test_password',
        });

        final credential = manager.getPostgresCredential(
          credentialId: 'cred_123',
        );

        expect(credential!['postgres']['name'], equals('PostgreSQL'));
      });

      test('getPostgresCredential returns null when not configured', () {
        final manager = CredentialManager(env: {});
        expect(manager.getPostgresCredential(), isNull);
      });

      test('getSupabaseCredential returns correctly formatted credential', () {
        final manager = CredentialManager(env: {
          'SUPABASE_URL': 'https://test.supabase.co',
          'SUPABASE_KEY': 'test_key',
        });

        final credential = manager.getSupabaseCredential(
          credentialId: 'cred_456',
          credentialName: 'My Supabase',
        );

        expect(credential, isNotNull);
        expect(credential!['supabaseApi'], isNotNull);
        expect(credential['supabaseApi']['id'], equals('cred_456'));
        expect(credential['supabaseApi']['name'], equals('My Supabase'));
      });

      test('getAwsCredential returns credential when configured', () {
        final manager = CredentialManager(env: {
          'AWS_ACCESS_KEY_ID': 'test_access_key',
          'AWS_SECRET_ACCESS_KEY': 'test_secret_key',
        });

        final credential = manager.getAwsCredential(credentialId: 'aws_123');
        expect(credential, isNotNull);
        expect(credential!['aws']['id'], equals('aws_123'));
      });

      test('getSlackCredential returns credential when configured', () {
        final manager = CredentialManager(env: {
          'SLACK_TOKEN': 'xoxb-test-token',
        });

        final credential = manager.getSlackCredential(credentialId: 'slack_123');
        expect(credential, isNotNull);
        expect(credential!['slackApi']['id'], equals('slack_123'));
      });

      test('getStripeCredential returns credential when configured', () {
        final manager = CredentialManager(env: {
          'STRIPE_SECRET_KEY': 'sk_test_123',
        });

        final credential =
            manager.getStripeCredential(credentialId: 'stripe_123');
        expect(credential, isNotNull);
        expect(credential!['stripeApi']['id'], equals('stripe_123'));
      });

      test('getEmailCredential returns credential when configured', () {
        final manager = CredentialManager(env: {
          'SMTP_HOST': 'smtp.example.com',
          'SMTP_USER': 'user@example.com',
        });

        final credential = manager.getEmailCredential(credentialId: 'email_123');
        expect(credential, isNotNull);
        expect(credential!['smtp']['id'], equals('email_123'));
      });

      test('getMongoDbCredential returns credential when configured', () {
        final manager = CredentialManager(env: {
          'MONGODB_URL': 'mongodb://localhost:27017',
        });

        final credential =
            manager.getMongoDbCredential(credentialId: 'mongo_123');
        expect(credential, isNotNull);
        expect(credential!['mongoDB']['id'], equals('mongo_123'));
      });
    });

    group('getCredential - Generic Method', () {
      test('returns postgres credential by type', () {
        final manager = CredentialManager(env: {
          'SUPABASE_DB_HOST': 'db.example.com',
          'SUPABASE_DB_PASSWORD': 'test_password',
        });

        final credential = manager.getCredential('postgres');
        expect(credential['postgres'], isNotNull);
      });

      test('returns placeholder when credential not configured', () {
        final manager = CredentialManager(env: {});

        final credential = manager.getCredential('postgres');
        expect(credential['postgres'], isNotNull);
        expect(credential['postgres']['id'], equals('credential_id'));
        expect(credential['postgres']['name'], equals('PostgreSQL'));
      });

      test('throws when credential not configured and usePlaceholder=false',
          () {
        final manager = CredentialManager(env: {});

        expect(
          () => manager.getCredential('postgres', usePlaceholder: false),
          throwsException,
        );
      });

      test('handles case-insensitive credential types', () {
        final manager = CredentialManager(env: {
          'SUPABASE_DB_HOST': 'db.example.com',
          'SUPABASE_DB_PASSWORD': 'test_password',
        });

        final credential1 = manager.getCredential('postgres');
        final credential2 = manager.getCredential('POSTGRES');
        final credential3 = manager.getCredential('PostgreSQL');

        expect(credential1['postgres'], isNotNull);
        expect(credential2['postgres'], isNotNull);
        expect(credential3['postgres'], isNotNull);
      });

      test('returns correct credential for all supported types', () {
        final manager = CredentialManager(env: {
          'SUPABASE_DB_HOST': 'db.example.com',
          'SUPABASE_DB_PASSWORD': 'pass',
          'SUPABASE_URL': 'https://test.supabase.co',
          'SUPABASE_KEY': 'key',
          'AWS_ACCESS_KEY_ID': 'aws_key',
          'AWS_SECRET_ACCESS_KEY': 'aws_secret',
          'SLACK_TOKEN': 'slack_token',
          'STRIPE_SECRET_KEY': 'stripe_key',
          'SMTP_HOST': 'smtp.example.com',
          'SMTP_USER': 'user@example.com',
          'MONGODB_URL': 'mongodb://localhost',
        });

        expect(manager.getCredential('postgres')['postgres'], isNotNull);
        expect(manager.getCredential('supabase')['supabaseApi'], isNotNull);
        expect(manager.getCredential('aws')['aws'], isNotNull);
        expect(manager.getCredential('slack')['slackApi'], isNotNull);
        expect(manager.getCredential('stripe')['stripeApi'], isNotNull);
        expect(manager.getCredential('email')['smtp'], isNotNull);
        expect(manager.getCredential('mongodb')['mongoDB'], isNotNull);
      });
    });

    group('getCredentialStatus', () {
      test('returns status map for all credential types', () {
        final manager = CredentialManager(env: {
          'N8N_BASE_URL': 'https://test.n8n.cloud',
          'N8N_API_KEY': 'test_key',
          'SUPABASE_DB_HOST': 'db.example.com',
          'SUPABASE_DB_PASSWORD': 'test_password',
        });

        final status = manager.getCredentialStatus();
        expect(status['n8n'], isTrue);
        expect(status['postgres'], isTrue);
        expect(status['supabase'], isFalse);
        expect(status['aws'], isFalse);
      });
    });

    group('Integration with .env.test', () {
      test('loads credentials from project .env.test file', () {
        const envTestPath = '.env.test';
        final file = File(envTestPath);

        if (!file.existsSync()) {
          // Skip if .env.test doesn't exist
          return;
        }

        final manager = CredentialManager.fromEnvFile(envTestPath);
        expect(manager.n8nBaseUrl, isNotNull);
        expect(manager.n8nApiKey, isNotNull);
        expect(manager.hasN8nCredentials, isTrue);
      });
    });
  });
}
