import 'dart:io';

/// Credential Manager for Workflow Generation
///
/// Loads credentials from environment variables or .env files
/// and provides them to workflow generators in the correct format.

/// Manages credentials for workflow generation
class CredentialManager {
  /// Loaded environment variables
  final Map<String, String> _env;

  /// Constructor with optional custom environment variables
  CredentialManager({Map<String, String>? env})
      : _env = env ?? Platform.environment;

  /// Load credentials from .env file
  factory CredentialManager.fromEnvFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw Exception('Environment file not found: $path');
    }

    final env = <String, String>{};
    final lines = file.readAsLinesSync();

    for (final line in lines) {
      final trimmed = line.trim();
      // Skip comments and empty lines
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      final parts = trimmed.split('=');
      if (parts.length >= 2) {
        final key = parts[0].trim();
        final value = parts.sublist(1).join('=').trim();
        env[key] = value;
      }
    }

    return CredentialManager(env: env);
  }

  /// Get n8n base URL
  String? get n8nBaseUrl => _env['N8N_BASE_URL'];

  /// Get n8n API key
  String? get n8nApiKey => _env['N8N_API_KEY'];

  /// Get Supabase URL
  String? get supabaseUrl => _env['SUPABASE_URL'];

  /// Get Supabase key
  String? get supabaseKey => _env['SUPABASE_KEY'];

  /// Get Supabase DB host
  String? get supabaseDbHost => _env['SUPABASE_DB_HOST'];

  /// Get Supabase DB password
  String? get supabaseDbPassword => _env['SUPABASE_DB_PASSWORD'];

  /// Check if n8n credentials are configured
  bool get hasN8nCredentials =>
      n8nBaseUrl != null && n8nApiKey != null;

  /// Check if Supabase credentials are configured
  bool get hasSupabaseCredentials =>
      supabaseUrl != null && supabaseKey != null;

  /// Check if PostgreSQL credentials are configured
  bool get hasPostgresCredentials =>
      supabaseDbHost != null && supabaseDbPassword != null;

  /// Get PostgreSQL credential in n8n format
  Map<String, dynamic>? getPostgresCredential({
    String? credentialId,
    String? credentialName,
  }) {
    if (!hasPostgresCredentials) return null;

    return {
      'postgres': {
        if (credentialId != null) 'id': credentialId,
        'name': credentialName ?? 'PostgreSQL',
      },
    };
  }

  /// Get Supabase credential in n8n format
  Map<String, dynamic>? getSupabaseCredential({
    String? credentialId,
    String? credentialName,
  }) {
    if (!hasSupabaseCredentials) return null;

    return {
      'supabaseApi': {
        if (credentialId != null) 'id': credentialId,
        'name': credentialName ?? 'Supabase',
      },
    };
  }

  /// Get AWS S3 credential in n8n format
  Map<String, dynamic>? getAwsCredential({
    String? credentialId,
    String? credentialName,
  }) {
    final awsAccessKeyId = _env['AWS_ACCESS_KEY_ID'];
    final awsSecretAccessKey = _env['AWS_SECRET_ACCESS_KEY'];

    if (awsAccessKeyId == null || awsSecretAccessKey == null) return null;

    return {
      'aws': {
        if (credentialId != null) 'id': credentialId,
        'name': credentialName ?? 'AWS',
      },
    };
  }

  /// Get Slack credential in n8n format
  Map<String, dynamic>? getSlackCredential({
    String? credentialId,
    String? credentialName,
  }) {
    final slackToken = _env['SLACK_TOKEN'];
    if (slackToken == null) return null;

    return {
      'slackApi': {
        if (credentialId != null) 'id': credentialId,
        'name': credentialName ?? 'Slack',
      },
    };
  }

  /// Get Stripe credential in n8n format
  Map<String, dynamic>? getStripeCredential({
    String? credentialId,
    String? credentialName,
  }) {
    final stripeSecretKey = _env['STRIPE_SECRET_KEY'];
    if (stripeSecretKey == null) return null;

    return {
      'stripeApi': {
        if (credentialId != null) 'id': credentialId,
        'name': credentialName ?? 'Stripe',
      },
    };
  }

  /// Get email SMTP credential in n8n format
  Map<String, dynamic>? getEmailCredential({
    String? credentialId,
    String? credentialName,
  }) {
    final smtpHost = _env['SMTP_HOST'];
    final smtpUser = _env['SMTP_USER'];

    if (smtpHost == null || smtpUser == null) return null;

    return {
      'smtp': {
        if (credentialId != null) 'id': credentialId,
        'name': credentialName ?? 'Email SMTP',
      },
    };
  }

  /// Get MongoDB credential in n8n format
  Map<String, dynamic>? getMongoDbCredential({
    String? credentialId,
    String? credentialName,
  }) {
    final mongoUrl = _env['MONGODB_URL'];
    if (mongoUrl == null) return null;

    return {
      'mongoDB': {
        if (credentialId != null) 'id': credentialId,
        'name': credentialName ?? 'MongoDB',
      },
    };
  }

  /// Get credential by type with optional fallback to placeholder
  Map<String, dynamic> getCredential(
    String type, {
    String? credentialId,
    String? credentialName,
    bool usePlaceholder = true,
  }) {
    Map<String, dynamic>? credential;

    switch (type.toLowerCase()) {
      case 'postgres':
      case 'postgresql':
        credential = getPostgresCredential(
          credentialId: credentialId,
          credentialName: credentialName,
        );
      case 'supabase':
        credential = getSupabaseCredential(
          credentialId: credentialId,
          credentialName: credentialName,
        );
      case 'aws':
      case 's3':
        credential = getAwsCredential(
          credentialId: credentialId,
          credentialName: credentialName,
        );
      case 'slack':
        credential = getSlackCredential(
          credentialId: credentialId,
          credentialName: credentialName,
        );
      case 'stripe':
        credential = getStripeCredential(
          credentialId: credentialId,
          credentialName: credentialName,
        );
      case 'email':
      case 'smtp':
        credential = getEmailCredential(
          credentialId: credentialId,
          credentialName: credentialName,
        );
      case 'mongodb':
        credential = getMongoDbCredential(
          credentialId: credentialId,
          credentialName: credentialName,
        );
    }

    // Return configured credential or placeholder
    if (credential != null) return credential;

    if (!usePlaceholder) {
      throw Exception(
        'Credential type "$type" not configured in environment. '
        'Add required environment variables or set usePlaceholder=true.',
      );
    }

    // Return placeholder credential
    return {
      type: {
        'id': 'credential_id',
        'name': credentialName ?? _getDefaultCredentialName(type),
      },
    };
  }

  /// Get default credential name for a type
  String _getDefaultCredentialName(String type) {
    switch (type.toLowerCase()) {
      case 'postgres':
      case 'postgresql':
        return 'PostgreSQL';
      case 'supabase':
        return 'Supabase';
      case 'aws':
      case 's3':
        return 'AWS';
      case 'slack':
        return 'Slack';
      case 'stripe':
        return 'Stripe';
      case 'email':
      case 'smtp':
        return 'Email SMTP';
      case 'mongodb':
        return 'MongoDB';
      default:
        return type.toUpperCase();
    }
  }

  /// Get a summary of configured credentials
  Map<String, bool> getCredentialStatus() {
    return {
      'n8n': hasN8nCredentials,
      'postgres': hasPostgresCredentials,
      'supabase': hasSupabaseCredentials,
      'aws': getAwsCredential() != null,
      'slack': getSlackCredential() != null,
      'stripe': getStripeCredential() != null,
      'email': getEmailCredential() != null,
      'mongodb': getMongoDbCredential() != null,
    };
  }

  /// Print credential status report
  void printStatus() {
    print('📋 Credential Manager Status:');
    final status = getCredentialStatus();
    for (final entry in status.entries) {
      final icon = entry.value ? '✅' : '❌';
      print('   $icon ${entry.key.padRight(12)}: ${entry.value ? 'Configured' : 'Not configured'}');
    }
  }
}
