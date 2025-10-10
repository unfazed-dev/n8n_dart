# Contributing to n8n_dart

Thank you for your interest in contributing to n8n_dart! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Testing Guidelines](#testing-guidelines)
- [Code Style](#code-style)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Project Structure](#project-structure)

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/n8n_dart.git
   cd n8n_dart
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/n8n_dart.git
   ```
4. **Install dependencies**:
   ```bash
   dart pub get
   ```

## Development Setup

### Prerequisites

- Dart SDK 3.0.0 or higher
- Git
- Code editor (VS Code, IntelliJ IDEA, or Android Studio recommended)

### Optional (for integration tests)

- n8n cloud instance access
- n8n cloud credentials (base URL, API key)

## Testing Guidelines

### Running Tests

```bash
# Run all tests
dart test

# Run unit tests only
dart test test/ --exclude-tags=integration

# Run integration tests only (requires n8n cloud credentials)
dart test --tags=integration test/integration/

# Run specific test file
dart test test/core/services/n8n_client_test.dart

# Run tests with coverage
dart test --coverage=coverage
```

### Test Requirements

**All contributions MUST include tests:**

1. **Unit Tests** (Required)
   - Place in `test/` directory
   - Mirror the structure of `lib/` directory
   - Test file naming: `*_test.dart`
   - Minimum coverage: 80% for new code

2. **Integration Tests** (When applicable)
   - Place in `test/integration/` directory
   - Use `@Tags(['integration'])` annotation
   - Test against real n8n workflows when possible
   - Document any n8n cloud setup requirements

### Writing Good Tests

**DO:**
- ✅ Write clear, descriptive test names
- ✅ Follow AAA pattern (Arrange, Act, Assert)
- ✅ Test edge cases and error conditions
- ✅ Use mocks/stubs for external dependencies
- ✅ Keep tests isolated and independent
- ✅ Clean up resources (dispose clients, close streams)

**DON'T:**
- ❌ Test implementation details
- ❌ Create flaky tests (timing-dependent, order-dependent)
- ❌ Leave commented-out code
- ❌ Hardcode credentials or sensitive data

### Test Example

```dart
import 'package:test/test.dart';
import 'package:n8n_dart/n8n_dart.dart';

void main() {
  group('WorkflowExecution', () {
    test('fromJson parses valid execution data', () {
      // Arrange
      final json = {
        'id': 'exec-123',
        'finished': true,
        'mode': 'webhook',
        'startedAt': '2025-01-01T00:00:00.000Z',
        'stoppedAt': '2025-01-01T00:00:10.000Z',
        'workflowId': 'wf-456',
        'status': 'success',
      };

      // Act
      final result = WorkflowExecution.fromJsonSafe(json);

      // Assert
      expect(result.isValid, isTrue);
      expect(result.value!.id, equals('exec-123'));
      expect(result.value!.finished, isTrue);
      expect(result.value!.status, equals(WorkflowStatus.success));
    });

    test('fromJsonSafe handles invalid data gracefully', () {
      // Arrange
      final json = {'invalid': 'data'};

      // Act
      final result = WorkflowExecution.fromJsonSafe(json);

      // Assert
      expect(result.isValid, isFalse);
      expect(result.error, isNotNull);
    });
  });
}
```

## Code Style

### Dart Style Guide

Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).

**Key points:**
- Use `dart format .` to auto-format code
- Line length: 80 characters (enforced by formatter)
- Use trailing commas for better diffs
- Prefer `final` over `var` when possible
- Use `const` constructors when applicable

### Linting

**CRITICAL: `dart analyze` MUST show "No issues found!" before committing.**

```bash
# Run analyzer
dart analyze

# Auto-fix lint issues
dart fix --apply
```

Common issues auto-fixed by `dart fix`:
- `directives_ordering` - Alphabetize imports
- `avoid_redundant_argument_values` - Remove default values
- `prefer_int_literals` - Use `1` not `1.0`
- `unnecessary_await_in_return` - Remove redundant awaits
- `prefer_const_constructors` - Add const where possible

### Code Organization

```dart
// 1. Dart/Flutter imports
import 'dart:async';
import 'dart:convert';

// 2. Package imports (alphabetically)
import 'package:http/http.dart' as http;
import 'package:rxdart/rxdart.dart';

// 3. Relative imports (alphabetically)
import '../models/n8n_models.dart';
import '../utils/validation.dart';

// 4. Code
class MyClass {
  // ...
}
```

## Commit Messages

### Format

```
<type>: <description>

[optional body]

[optional footer]
```

### Types

- `feat:` - New feature
- `fix:` - Bug fix
- `test:` - Adding or updating tests
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `perf:` - Performance improvements
- `style:` - Code style/formatting changes
- `chore:` - Maintenance tasks

### Guidelines

- Use lowercase for commit messages
- Keep title under 72 characters
- Use present tense ("add feature" not "added feature")
- Be descriptive but concise
- Reference issues with #issue-number

### Examples

**Good:**
```
feat: add reactive polling manager with 6 strategies

Implemented ReactivePollingManager with support for:
- Balanced, aggressive, minimal, adaptive, exponential, fibonacci strategies
- Auto-stop polling when execution completes
- Configurable intervals and max attempts

Closes #42
```

**Good:**
```
fix: resolve circuit breaker state transition race condition

The circuit breaker could transition from open to half-open while
a request was in flight, causing unexpected behavior.

Fixed by adding proper state locking.
```

**Bad:**
```
updates
```

**Bad:**
```
feat: added new feature -- generated with Claude Code
```

## Pull Request Process

### Before Submitting

1. **Update your fork:**
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run all checks:**
   ```bash
   # Format code
   dart format .

   # Run analyzer (MUST pass)
   dart analyze

   # Run tests
   dart test

   # Check coverage
   dart test --coverage=coverage
   ```

3. **Update documentation** if needed:
   - Update README.md for new features
   - Add/update code comments
   - Update CHANGELOG.md

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Checklist
- [ ] Tests added/updated
- [ ] `dart analyze` passes (0 issues)
- [ ] `dart test` passes (all tests)
- [ ] Documentation updated
- [ ] CHANGELOG.md updated

## Testing
Describe how you tested these changes

## Related Issues
Closes #123
```

### Review Process

1. Maintainer will review within 1-2 weeks
2. Address feedback promptly
3. Keep PR focused (one feature/fix per PR)
4. Squash commits if requested
5. PR will be merged once approved

## Project Structure

```
n8n_dart/
├── lib/
│   ├── n8n_dart.dart              # Main library export
│   └── src/
│       ├── core/
│       │   ├── models/            # Data models
│       │   ├── services/          # Core services
│       │   └── config/            # Configuration
│       └── workflow_generator/    # Workflow generation
│           ├── workflow_builder.dart
│           ├── templates/         # Pre-built templates
│           └── models/            # Generator models
├── test/
│   ├── core/                      # Unit tests (mirror lib/)
│   ├── workflow_generator/        # Generator unit tests
│   └── integration/               # Integration tests
│       ├── README.md
│       ├── config/                # Test configuration
│       ├── utils/                 # Test utilities
│       └── docs/                  # Test documentation
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md (this file)
└── pubspec.yaml
```

### Key Directories

- **`lib/src/core/`** - Core n8n client functionality
- **`lib/src/workflow_generator/`** - Programmatic workflow creation
- **`test/`** - Unit tests (mirror `lib/` structure)
- **`test/integration/`** - Integration tests requiring n8n cloud

## Development Guidelines

### Adding a New Feature

1. **Create an issue** describing the feature
2. **Discuss approach** with maintainers
3. **Create a branch:**
   ```bash
   git checkout -b feature/my-new-feature
   ```
4. **Implement feature** with tests
5. **Update documentation**
6. **Submit pull request**

### Fixing a Bug

1. **Create an issue** (if one doesn't exist)
2. **Write a failing test** that reproduces the bug
3. **Fix the bug**
4. **Verify test passes**
5. **Submit pull request**

### Adding Integration Tests

1. **Document n8n workflow requirements** in test file
2. **Use `@Tags(['integration'])`** annotation
3. **Handle missing credentials gracefully**:
   ```dart
   @Tags(['integration'])
   void main() {
     test('workflow execution', () async {
       final config = TestConfig.load();
       if (config.baseUrl.isEmpty) {
         markTestSkipped('No n8n credentials configured');
         return;
       }
       // ... test code
     });
   }
   ```

4. **Document setup in test/integration/README.md**

## Questions?

- Open an issue for questions
- Check existing issues and PRs
- Review documentation in `test/integration/docs/`

## Thank You!

Your contributions make n8n_dart better for everyone! 🎉
