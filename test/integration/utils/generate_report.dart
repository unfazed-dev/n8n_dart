#!/usr/bin/env dart

/// HTML test report generator for CI/CD
///
/// This script generates an HTML report from Dart test JSON output.
/// The report includes test results, execution times, and failure details.
///
/// Usage:
/// ```bash
/// dart run test/integration/utils/generate_report.dart test-results.json test-report.html
/// ```
///
/// Exit codes:
/// - 0: Report generated successfully
/// - 1: Error generating report
library;

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart generate_report.dart <input.json> <output.html>');
    exit(1);
  }

  final inputFile = args[0];
  final outputFile = args[1];

  try {
    print('📊 Generating HTML test report...');
    print('   Input: $inputFile');
    print('   Output: $outputFile');

    // Read test results
    final jsonContent = File(inputFile).readAsStringSync();
    final lines = jsonContent.split('\n').where((line) => line.isNotEmpty);

    var totalTests = 0;
    var passedTests = 0;
    var failedTests = 0;
    var skippedTests = 0;
    final testResults = <Map<String, dynamic>>[];
    final errors = <Map<String, dynamic>>[];
    var startTime = DateTime.now();
    var endTime = DateTime.now();

    // Parse JSON lines
    for (final line in lines) {
      try {
        final event = jsonDecode(line) as Map<String, dynamic>;
        final type = event['type'] as String?;

        if (type == 'start') {
          startTime = DateTime.fromMillisecondsSinceEpoch(
            event['time'] as int,
          );
        } else if (type == 'done') {
          endTime = DateTime.fromMillisecondsSinceEpoch(
            event['time'] as int,
          );
        } else if (type == 'testStart') {
          totalTests++;
        } else if (type == 'testDone') {
          final test = event['test'] as Map<String, dynamic>;
          final result = event['result'] as String;
          final skipped = event['skipped'] as bool? ?? false;

          if (skipped) {
            skippedTests++;
          } else if (result == 'success') {
            passedTests++;
          } else if (result == 'error' || result == 'failure') {
            failedTests++;
          }

          testResults.add({
            'name': test['name'],
            'result': result,
            'skipped': skipped,
            'time': event['time'],
          });
        } else if (type == 'error') {
          errors.add({
            'error': event['error'],
            'stackTrace': event['stackTrace'],
            'testID': event['testID'],
          });
        }
      } catch (e) {
        // Skip malformed lines
        continue;
      }
    }

    final duration = endTime.difference(startTime);
    final successRate =
        totalTests > 0 ? (passedTests / totalTests * 100).toStringAsFixed(1) : '0.0';

    // Generate HTML report
    final html = _generateHtmlReport(
      totalTests: totalTests,
      passedTests: passedTests,
      failedTests: failedTests,
      skippedTests: skippedTests,
      successRate: successRate,
      duration: duration,
      testResults: testResults,
      errors: errors,
      timestamp: DateTime.now(),
    );

    // Write report
    File(outputFile).writeAsStringSync(html);

    print('✅ Report generated successfully');
    print('   Total tests: $totalTests');
    print('   Passed: $passedTests');
    print('   Failed: $failedTests');
    print('   Skipped: $skippedTests');
    print('   Success rate: $successRate%');
    print('   Duration: ${duration.inSeconds}s');

    exit(0);
  } catch (e, stackTrace) {
    print('❌ Error generating report:');
    print(e);
    print('\nStack trace:');
    print(stackTrace);
    exit(1);
  }
}

String _generateHtmlReport({
  required int totalTests,
  required int passedTests,
  required int failedTests,
  required int skippedTests,
  required String successRate,
  required Duration duration,
  required List<Map<String, dynamic>> testResults,
  required List<Map<String, dynamic>> errors,
  required DateTime timestamp,
}) {
  final statusIcon = failedTests == 0 ? '✅' : '❌';
  final statusText = failedTests == 0 ? 'PASSED' : 'FAILED';
  final statusColor = failedTests == 0 ? '#4CAF50' : '#f44336';

  return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Integration Test Report - n8n_dart</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      line-height: 1.6;
      color: #333;
      background: #f5f5f5;
      padding: 20px;
    }

    .container {
      max-width: 1200px;
      margin: 0 auto;
      background: white;
      border-radius: 8px;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      overflow: hidden;
    }

    .header {
      background: $statusColor;
      color: white;
      padding: 30px;
      text-align: center;
    }

    .header h1 {
      font-size: 2.5em;
      margin-bottom: 10px;
    }

    .header .status {
      font-size: 1.5em;
      font-weight: bold;
    }

    .metrics {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
      gap: 20px;
      padding: 30px;
      background: #fafafa;
    }

    .metric {
      text-align: center;
      padding: 20px;
      background: white;
      border-radius: 8px;
      box-shadow: 0 1px 3px rgba(0,0,0,0.1);
    }

    .metric .value {
      font-size: 2.5em;
      font-weight: bold;
      color: #2196F3;
    }

    .metric .label {
      font-size: 0.9em;
      color: #666;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-top: 5px;
    }

    .metric.success .value { color: #4CAF50; }
    .metric.failure .value { color: #f44336; }
    .metric.skipped .value { color: #FF9800; }

    .section {
      padding: 30px;
      border-top: 1px solid #eee;
    }

    .section h2 {
      font-size: 1.5em;
      margin-bottom: 20px;
      color: #2196F3;
    }

    .test-list {
      list-style: none;
    }

    .test-item {
      padding: 15px;
      margin-bottom: 10px;
      background: #fafafa;
      border-radius: 4px;
      border-left: 4px solid #ddd;
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .test-item.success { border-left-color: #4CAF50; }
    .test-item.failure { border-left-color: #f44336; }
    .test-item.skipped { border-left-color: #FF9800; }

    .test-name {
      font-weight: 500;
    }

    .test-status {
      padding: 4px 12px;
      border-radius: 12px;
      font-size: 0.85em;
      font-weight: bold;
      text-transform: uppercase;
    }

    .test-status.success {
      background: #4CAF50;
      color: white;
    }

    .test-status.failure {
      background: #f44336;
      color: white;
    }

    .test-status.skipped {
      background: #FF9800;
      color: white;
    }

    .error-box {
      background: #ffebee;
      border: 1px solid #ef5350;
      border-radius: 4px;
      padding: 15px;
      margin-bottom: 15px;
      font-family: 'Courier New', monospace;
      font-size: 0.9em;
    }

    .error-box pre {
      white-space: pre-wrap;
      word-wrap: break-word;
    }

    .footer {
      padding: 20px 30px;
      background: #fafafa;
      text-align: center;
      font-size: 0.9em;
      color: #666;
    }

    .timestamp {
      margin-top: 10px;
      font-size: 0.85em;
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>$statusIcon Integration Test Report</h1>
      <div class="status">$statusText</div>
    </div>

    <div class="metrics">
      <div class="metric">
        <div class="value">$totalTests</div>
        <div class="label">Total Tests</div>
      </div>
      <div class="metric success">
        <div class="value">$passedTests</div>
        <div class="label">Passed</div>
      </div>
      <div class="metric failure">
        <div class="value">$failedTests</div>
        <div class="label">Failed</div>
      </div>
      <div class="metric skipped">
        <div class="value">$skippedTests</div>
        <div class="label">Skipped</div>
      </div>
      <div class="metric">
        <div class="value">$successRate%</div>
        <div class="label">Success Rate</div>
      </div>
      <div class="metric">
        <div class="value">${duration.inSeconds}s</div>
        <div class="label">Duration</div>
      </div>
    </div>

    ${_generateTestResultsSection(testResults)}

    ${errors.isNotEmpty ? _generateErrorsSection(errors) : ''}

    <div class="footer">
      <div>Generated by n8n_dart Integration Test Suite</div>
      <div class="timestamp">Report generated: ${timestamp.toIso8601String()}</div>
    </div>
  </div>
</body>
</html>
''';
}

String _generateTestResultsSection(List<Map<String, dynamic>> testResults) {
  if (testResults.isEmpty) {
    return '<div class="section"><h2>Test Results</h2><p>No test results available.</p></div>';
  }

  final items = testResults.map((test) {
    final name = test['name'] as String;
    final result = test['result'] as String;
    final skipped = test['skipped'] as bool;

    final statusClass = skipped
        ? 'skipped'
        : result == 'success'
            ? 'success'
            : 'failure';
    final statusText = skipped
        ? 'Skipped'
        : result == 'success'
            ? 'Passed'
            : 'Failed';

    return '''
      <li class="test-item $statusClass">
        <span class="test-name">$name</span>
        <span class="test-status $statusClass">$statusText</span>
      </li>
    ''';
  }).join();

  return '''
    <div class="section">
      <h2>📋 Test Results</h2>
      <ul class="test-list">
        $items
      </ul>
    </div>
  ''';
}

String _generateErrorsSection(List<Map<String, dynamic>> errors) {
  if (errors.isEmpty) return '';

  final errorBoxes = errors.map((error) {
    final errorMsg = error['error'] as String;
    final stackTrace = error['stackTrace'] as String? ?? '';

    return '''
      <div class="error-box">
        <strong>Error:</strong>
        <pre>$errorMsg</pre>
        ${stackTrace.isNotEmpty ? '<strong>Stack Trace:</strong><pre>$stackTrace</pre>' : ''}
      </div>
    ''';
  }).join();

  return '''
    <div class="section">
      <h2>❌ Errors</h2>
      $errorBoxes
    </div>
  ''';
}
