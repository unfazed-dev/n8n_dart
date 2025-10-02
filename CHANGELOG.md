# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-02

### Added
- Initial release of n8n_dart package
- Core `N8nClient` for pure Dart applications
- Type-safe models with validation (`ValidationResult<T>`)
- Comprehensive configuration system with 6 preset profiles
- Smart polling manager with 4 strategies
- Intelligent error handling with retry logic and circuit breaker
- Stream resilience with 5 recovery strategies
- Support for 15+ dynamic form field types
- Webhook validation and health checks
- Flutter integration reference implementation
- Complete documentation and examples
- Production-ready error handling

### Features
- Workflow execution lifecycle management
- Wait node handling with dynamic form validation
- Exponential backoff retry mechanism
- Circuit breaker pattern for fault tolerance
- Activity-aware adaptive polling
- Battery-optimized configurations for mobile
- Custom header support for authentication
- SSL/TLS validation (configurable)
- Comprehensive logging with log levels
- Memory leak prevention with proper disposal

## [Unreleased]

### Planned
- WebSocket support for real-time updates
- Offline execution queue
- GraphQL API support
- Webhook registration API
- Execution history management
- Multi-workflow orchestration
- Custom node type support
- Visual workflow builder (Flutter widget)
- OpenTelemetry integration
- gRPC transport option
