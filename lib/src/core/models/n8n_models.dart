/// Generic validation result class for safe data parsing
///
/// Provides type-safe validation results with detailed error information
class ValidationResult<T> {
  final T? value;
  final List<String> errors;
  final bool isValid;

  const ValidationResult._({
    this.value,
    required this.errors,
    required this.isValid,
  });

  /// Create a successful validation result
  factory ValidationResult.success(T value) {
    return ValidationResult._(
      value: value,
      errors: const [],
      isValid: true,
    );
  }

  /// Create a failed validation result
  factory ValidationResult.failure(List<String> errors) {
    return ValidationResult._(
      value: null,
      errors: errors,
      isValid: false,
    );
  }

  /// Create a failed validation result with single error
  factory ValidationResult.error(String error) {
    return ValidationResult._(
      value: null,
      errors: [error],
      isValid: false,
    );
  }

  @override
  String toString() {
    if (isValid) {
      return 'ValidationResult.success($value)';
    } else {
      return 'ValidationResult.failure(${errors.join(', ')})';
    }
  }
}

/// Validator mixin providing static validation methods for reuse
mixin Validator {
  /// Validate required string field
  static String? validateRequired(dynamic value, String fieldName) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate email format
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) return null;

    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Invalid email format';
    }
    return null;
  }

  /// Validate phone number format
  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) return null;

    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'Invalid phone number format';
    }
    return null;
  }

  /// Validate URL format
  static String? validateUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return 'Invalid URL format';
      }
    } catch (e) {
      return 'Invalid URL format';
    }
    return null;
  }

  /// Validate number range
  static String? validateNumberRange(
      num? value, num min, num max, String fieldName) {
    if (value == null) return null;

    if (value < min || value > max) {
      return '$fieldName must be between $min and $max';
    }
    return null;
  }

  /// Validate string length
  static String? validateLength(
      String? value, int minLength, int maxLength, String fieldName) {
    if (value == null) return null;

    if (value.length < minLength || value.length > maxLength) {
      return '$fieldName must be between $minLength and $maxLength characters';
    }
    return null;
  }

  /// Validate date format
  static String? validateDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return null;

    try {
      DateTime.parse(dateStr);
    } catch (e) {
      return 'Invalid date format';
    }
    return null;
  }
}

/// Workflow execution status enumeration
enum WorkflowStatus {
  new_,
  running,
  success,
  error,
  waiting,
  canceled,
  crashed,
  unknown;

  /// Check if execution is finished (terminal state)
  bool get isFinished {
    return this == WorkflowStatus.success ||
        this == WorkflowStatus.error ||
        this == WorkflowStatus.canceled ||
        this == WorkflowStatus.crashed;
  }

  /// Check if execution is active (non-terminal state)
  bool get isActive {
    return this == WorkflowStatus.new_ ||
        this == WorkflowStatus.running ||
        this == WorkflowStatus.waiting;
  }

  /// Parse status from string
  static WorkflowStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return WorkflowStatus.new_;
      case 'running':
        return WorkflowStatus.running;
      case 'success':
        return WorkflowStatus.success;
      case 'error':
        return WorkflowStatus.error;
      case 'waiting':
        return WorkflowStatus.waiting;
      case 'canceled':
        return WorkflowStatus.canceled;
      case 'crashed':
        return WorkflowStatus.crashed;
      default:
        return WorkflowStatus.unknown;
    }
  }

  @override
  String toString() {
    switch (this) {
      case WorkflowStatus.new_:
        return 'new';
      default:
        return name;
    }
  }
}

/// Form field type enumeration supporting 15+ field types
enum FormFieldType {
  text,
  email,
  number,
  select,
  radio,
  checkbox,
  date,
  time,
  datetimeLocal,
  file,
  textarea,
  url,
  phone,
  slider,
  switch_;

  /// Parse field type from string
  static FormFieldType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return FormFieldType.text;
      case 'email':
        return FormFieldType.email;
      case 'number':
        return FormFieldType.number;
      case 'select':
        return FormFieldType.select;
      case 'radio':
        return FormFieldType.radio;
      case 'checkbox':
        return FormFieldType.checkbox;
      case 'date':
        return FormFieldType.date;
      case 'time':
        return FormFieldType.time;
      case 'datetime-local':
        return FormFieldType.datetimeLocal;
      case 'file':
        return FormFieldType.file;
      case 'textarea':
        return FormFieldType.textarea;
      case 'url':
        return FormFieldType.url;
      case 'phone':
        return FormFieldType.phone;
      case 'slider':
        return FormFieldType.slider;
      case 'switch':
        return FormFieldType.switch_;
      default:
        return FormFieldType.text;
    }
  }

  @override
  String toString() {
    switch (this) {
      case FormFieldType.datetimeLocal:
        return 'datetime-local';
      case FormFieldType.switch_:
        return 'switch';
      default:
        return name;
    }
  }
}

/// Form field configuration for dynamic form generation
class FormFieldConfig with Validator {
  final String name;
  final String label;
  final FormFieldType type;
  final bool required;
  final String? placeholder;
  final String? defaultValue;
  final List<String>? options;
  final String? validation;
  final Map<String, dynamic>? metadata;

  const FormFieldConfig({
    required this.name,
    required this.label,
    required this.type,
    this.required = false,
    this.placeholder,
    this.defaultValue,
    this.options,
    this.validation,
    this.metadata,
  });

  /// Create FormFieldConfig from JSON with validation
  static ValidationResult<FormFieldConfig> fromJsonSafe(
      Map<String, dynamic> json) {
    final errors = <String>[];

    // Validate required fields
    final nameError = Validator.validateRequired(json['name'], 'name');
    if (nameError != null) errors.add(nameError);

    final labelError = Validator.validateRequired(json['label'], 'label');
    if (labelError != null) errors.add(labelError);

    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors);
    }

    try {
      final config = FormFieldConfig(
        name: json['name'] as String,
        label: json['label'] as String,
        type: FormFieldType.fromString(json['type'] as String? ?? 'text'),
        required: json['required'] as bool? ?? false,
        placeholder: json['placeholder'] as String?,
        defaultValue: json['defaultValue'] as String?,
        options: (json['options'] as List<dynamic>?)?.cast<String>(),
        validation: json['validation'] as String?,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

      return ValidationResult.success(config);
    } catch (e) {
      return ValidationResult.error('Failed to parse FormFieldConfig: $e');
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'label': label,
      'type': type.toString(),
      'required': required,
      if (placeholder != null) 'placeholder': placeholder,
      if (defaultValue != null) 'defaultValue': defaultValue,
      if (options != null) 'options': options,
      if (validation != null) 'validation': validation,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Validate field value against configuration
  ValidationResult<String> validateValue(dynamic value) {
    final errors = <String>[];
    final stringValue = value?.toString();

    // Check required
    if (required) {
      final requiredError = Validator.validateRequired(value, label);
      if (requiredError != null) errors.add(requiredError);
    }

    // Skip further validation if value is empty and not required
    if (stringValue == null || stringValue.isEmpty) {
      return errors.isEmpty
          ? ValidationResult.success(stringValue ?? '')
          : ValidationResult.failure(errors);
    }

    // Type-specific validation
    switch (type) {
      case FormFieldType.email:
        final emailError = Validator.validateEmail(stringValue);
        if (emailError != null) errors.add(emailError);
        break;

      case FormFieldType.phone:
        final phoneError = Validator.validatePhone(stringValue);
        if (phoneError != null) errors.add(phoneError);
        break;

      case FormFieldType.url:
        final urlError = Validator.validateUrl(stringValue);
        if (urlError != null) errors.add(urlError);
        break;

      case FormFieldType.number:
        if (double.tryParse(stringValue) == null) {
          errors.add('$label must be a valid number');
        }
        break;

      case FormFieldType.date:
      case FormFieldType.time:
      case FormFieldType.datetimeLocal:
        final dateError = Validator.validateDate(stringValue);
        if (dateError != null) errors.add(dateError);
        break;

      case FormFieldType.select:
      case FormFieldType.radio:
        if (options != null && !options!.contains(stringValue)) {
          errors.add('$label must be one of: ${options!.join(', ')}');
        }
        break;

      default:
        // No additional validation for other types
        break;
    }

    return errors.isEmpty
        ? ValidationResult.success(stringValue)
        : ValidationResult.failure(errors);
  }

  @override
  String toString() {
    return 'FormFieldConfig(name: $name, label: $label, type: $type, required: $required)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FormFieldConfig &&
        other.name == name &&
        other.label == label &&
        other.type == type &&
        other.required == required;
  }

  @override
  int get hashCode {
    return Object.hash(name, label, type, required);
  }
}

/// Wait node data for dynamic form generation
class WaitNodeData with Validator {
  final String nodeId;
  final String nodeName;
  final String? description;
  final List<FormFieldConfig> fields;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const WaitNodeData({
    required this.nodeId,
    required this.nodeName,
    this.description,
    required this.fields,
    this.metadata,
    required this.createdAt,
    this.expiresAt,
  });

  /// Create WaitNodeData from JSON with validation
  static ValidationResult<WaitNodeData> fromJsonSafe(
      Map<String, dynamic> json) {
    final errors = <String>[];

    // Validate required fields
    final nodeIdError = Validator.validateRequired(json['nodeId'], 'nodeId');
    if (nodeIdError != null) errors.add(nodeIdError);

    final nodeNameError =
        Validator.validateRequired(json['nodeName'], 'nodeName');
    if (nodeNameError != null) errors.add(nodeNameError);

    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors);
    }

    try {
      // Parse fields
      final fieldsJson = json['fields'] as List<dynamic>? ?? [];
      final fields = <FormFieldConfig>[];

      for (int i = 0; i < fieldsJson.length; i++) {
        final fieldResult =
            FormFieldConfig.fromJsonSafe(fieldsJson[i] as Map<String, dynamic>);

        if (fieldResult.isValid) {
          fields.add(fieldResult.value!);
        } else {
          errors.add('Field $i: ${fieldResult.errors.join(', ')}');
        }
      }

      if (errors.isNotEmpty) {
        return ValidationResult.failure(errors);
      }

      // Parse dates
      DateTime? createdAt;
      DateTime? expiresAt;

      if (json['createdAt'] != null) {
        try {
          createdAt = DateTime.parse(json['createdAt'] as String);
        } catch (e) {
          errors.add('Invalid createdAt format');
        }
      } else {
        createdAt = DateTime.now();
      }

      if (json['expiresAt'] != null) {
        try {
          expiresAt = DateTime.parse(json['expiresAt'] as String);
        } catch (e) {
          errors.add('Invalid expiresAt format');
        }
      }

      if (errors.isNotEmpty) {
        return ValidationResult.failure(errors);
      }

      final waitNodeData = WaitNodeData(
        nodeId: json['nodeId'] as String,
        nodeName: json['nodeName'] as String,
        description: json['description'] as String?,
        fields: fields,
        metadata: json['metadata'] as Map<String, dynamic>?,
        createdAt: createdAt!,
        expiresAt: expiresAt,
      );

      return ValidationResult.success(waitNodeData);
    } catch (e) {
      return ValidationResult.error('Failed to parse WaitNodeData: $e');
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'nodeName': nodeName,
      if (description != null) 'description': description,
      'fields': fields.map((f) => f.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
    };
  }

  /// Check if wait node has expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get field by name
  FormFieldConfig? getField(String name) {
    try {
      return fields.firstWhere((field) => field.name == name);
    } catch (e) {
      return null;
    }
  }

  /// Validate form data against field configurations
  ValidationResult<Map<String, String>> validateFormData(
      Map<String, dynamic> formData) {
    final errors = <String>[];
    final validatedData = <String, String>{};

    // Validate each field
    for (final field in fields) {
      final value = formData[field.name];
      final validationResult = field.validateValue(value);

      if (validationResult.isValid) {
        validatedData[field.name] = validationResult.value!;
      } else {
        errors.addAll(validationResult.errors);
      }
    }

    return errors.isEmpty
        ? ValidationResult.success(validatedData)
        : ValidationResult.failure(errors);
  }

  @override
  String toString() {
    return 'WaitNodeData(nodeId: $nodeId, nodeName: $nodeName, fields: ${fields.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WaitNodeData &&
        other.nodeId == nodeId &&
        other.nodeName == nodeName;
  }

  @override
  int get hashCode {
    return Object.hash(nodeId, nodeName);
  }
}

/// Workflow execution model with comprehensive validation
class WorkflowExecution with Validator {
  final String id;
  final String workflowId;
  final WorkflowStatus status;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final Map<String, dynamic>? data;
  final String? error;
  final bool waitingForInput;
  final WaitNodeData? waitNodeData;
  final Map<String, dynamic>? metadata;
  final int retryCount;
  final Duration? executionTime;

  const WorkflowExecution({
    required this.id,
    required this.workflowId,
    required this.status,
    required this.startedAt,
    this.finishedAt,
    this.data,
    this.error,
    this.waitingForInput = false,
    this.waitNodeData,
    this.metadata,
    this.retryCount = 0,
    this.executionTime,
  });

  /// Create WorkflowExecution from JSON with validation
  static ValidationResult<WorkflowExecution> fromJsonSafe(
      Map<String, dynamic> json) {
    final errors = <String>[];

    // Validate required fields
    final idError = Validator.validateRequired(json['id'], 'id');
    if (idError != null) errors.add(idError);

    final workflowIdError =
        Validator.validateRequired(json['workflowId'], 'workflowId');
    if (workflowIdError != null) errors.add(workflowIdError);

    if (errors.isNotEmpty) {
      return ValidationResult.failure(errors);
    }

    try {
      // Parse dates
      DateTime? startedAt;
      DateTime? finishedAt;

      if (json['startedAt'] != null) {
        try {
          startedAt = DateTime.parse(json['startedAt'] as String);
        } catch (e) {
          errors.add('Invalid startedAt format');
        }
      } else {
        startedAt = DateTime.now();
      }

      if (json['finishedAt'] != null) {
        try {
          finishedAt = DateTime.parse(json['finishedAt'] as String);
        } catch (e) {
          errors.add('Invalid finishedAt format');
        }
      }

      // Parse wait node data if present
      WaitNodeData? waitNodeData;
      if (json['waitNodeData'] != null) {
        final waitNodeResult = WaitNodeData.fromJsonSafe(
            json['waitNodeData'] as Map<String, dynamic>);

        if (waitNodeResult.isValid) {
          waitNodeData = waitNodeResult.value;
        } else {
          errors.add('WaitNodeData: ${waitNodeResult.errors.join(', ')}');
        }
      }

      if (errors.isNotEmpty) {
        return ValidationResult.failure(errors);
      }

      // Parse execution time
      Duration? executionTime;
      if (json['executionTime'] != null) {
        final executionTimeMs = json['executionTime'] as int?;
        if (executionTimeMs != null) {
          executionTime = Duration(milliseconds: executionTimeMs);
        }
      }

      final execution = WorkflowExecution(
        id: json['id'] as String,
        workflowId: json['workflowId'] as String,
        status:
            WorkflowStatus.fromString(json['status'] as String? ?? 'unknown'),
        startedAt: startedAt!,
        finishedAt: finishedAt,
        data: json['data'] as Map<String, dynamic>?,
        error: json['error'] as String?,
        waitingForInput: json['waitingForInput'] as bool? ?? false,
        waitNodeData: waitNodeData,
        metadata: json['metadata'] as Map<String, dynamic>?,
        retryCount: json['retryCount'] as int? ?? 0,
        executionTime: executionTime,
      );

      return ValidationResult.success(execution);
    } catch (e) {
      return ValidationResult.error('Failed to parse WorkflowExecution: $e');
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workflowId': workflowId,
      'status': status.toString(),
      'startedAt': startedAt.toIso8601String(),
      if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
      if (data != null) 'data': data,
      if (error != null) 'error': error,
      'waitingForInput': waitingForInput,
      if (waitNodeData != null) 'waitNodeData': waitNodeData!.toJson(),
      if (metadata != null) 'metadata': metadata,
      'retryCount': retryCount,
      if (executionTime != null) 'executionTime': executionTime!.inMilliseconds,
    };
  }

  /// Check if execution is finished
  bool get isFinished => status.isFinished;

  /// Check if execution is active
  bool get isActive => status.isActive;

  /// Check if execution was successful
  bool get isSuccessful => status == WorkflowStatus.success;

  /// Check if execution failed
  bool get isFailed =>
      status == WorkflowStatus.error || status == WorkflowStatus.crashed;

  /// Get execution duration
  Duration get duration {
    if (executionTime != null) {
      return executionTime!;
    }

    final endTime = finishedAt ?? DateTime.now();
    return endTime.difference(startedAt);
  }

  /// Create a copy with updated fields
  WorkflowExecution copyWith({
    String? id,
    String? workflowId,
    WorkflowStatus? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    Map<String, dynamic>? data,
    String? error,
    bool? waitingForInput,
    WaitNodeData? waitNodeData,
    Map<String, dynamic>? metadata,
    int? retryCount,
    Duration? executionTime,
  }) {
    return WorkflowExecution(
      id: id ?? this.id,
      workflowId: workflowId ?? this.workflowId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      data: data ?? this.data,
      error: error ?? this.error,
      waitingForInput: waitingForInput ?? this.waitingForInput,
      waitNodeData: waitNodeData ?? this.waitNodeData,
      metadata: metadata ?? this.metadata,
      retryCount: retryCount ?? this.retryCount,
      executionTime: executionTime ?? this.executionTime,
    );
  }

  @override
  String toString() {
    return 'WorkflowExecution(id: $id, status: $status, waitingForInput: $waitingForInput)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkflowExecution &&
        other.id == id &&
        other.workflowId == workflowId &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(id, workflowId, status);
  }
}
