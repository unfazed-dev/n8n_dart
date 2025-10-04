import 'package:n8n_dart/n8n_dart.dart';
import 'package:test/test.dart';

void main() {
  group('FormFieldType', () {
    group('fromString()', () {
      test('parses password type', () {
        expect(
          FormFieldType.fromString('password'),
          equals(FormFieldType.password),
        );
      });

      test('parses hidden as hiddenField', () {
        expect(
          FormFieldType.fromString('hidden'),
          equals(FormFieldType.hiddenField),
        );
      });

      test('parses hiddenfield as hiddenField (case insensitive)', () {
        expect(
          FormFieldType.fromString('hiddenfield'),
          equals(FormFieldType.hiddenField),
        );
        expect(
          FormFieldType.fromString('HIDDENFIELD'),
          equals(FormFieldType.hiddenField),
        );
      });

      test('parses html type', () {
        expect(
          FormFieldType.fromString('html'),
          equals(FormFieldType.html),
        );
      });

      test('parses existing types correctly', () {
        expect(FormFieldType.fromString('text'), equals(FormFieldType.text));
        expect(FormFieldType.fromString('email'), equals(FormFieldType.email));
        expect(
          FormFieldType.fromString('number'),
          equals(FormFieldType.number),
        );
      });
    });

    group('toString()', () {
      test('serializes password type', () {
        expect(FormFieldType.password.toString(), equals('password'));
      });

      test('serializes hiddenField as "hidden"', () {
        expect(FormFieldType.hiddenField.toString(), equals('hidden'));
      });

      test('serializes html type', () {
        expect(FormFieldType.html.toString(), equals('html'));
      });

      test('serializes existing special types correctly', () {
        expect(
          FormFieldType.datetimeLocal.toString(),
          equals('datetime-local'),
        );
        expect(FormFieldType.switch_.toString(), equals('switch'));
      });

      test('serializes regular types using name', () {
        expect(FormFieldType.text.toString(), equals('text'));
        expect(FormFieldType.email.toString(), equals('email'));
      });
    });
  });

  group('FormFieldConfig - Password Validation', () {
    test('validates password with minimum length requirement', () {
      const field = FormFieldConfig(
        name: 'password',
        label: 'Password',
        type: FormFieldType.password,
        required: true,
        metadata: {'minLength': 8},
      );

      // Too short
      final shortResult = field.validateValue('abc123');
      expect(shortResult.isValid, isFalse);
      expect(
        shortResult.errors.first,
        contains('must be at least 8 characters'),
      );

      // Valid length
      final validResult = field.validateValue('abcdefgh');
      expect(validResult.isValid, isTrue);
    });

    test('validates password with uppercase requirement', () {
      const field = FormFieldConfig(
        name: 'password',
        label: 'Password',
        type: FormFieldType.password,
        required: true,
        metadata: {'requiresUppercase': true},
      );

      // No uppercase
      final noUpperResult = field.validateValue('password123');
      expect(noUpperResult.isValid, isFalse);
      expect(
        noUpperResult.errors.first,
        contains('must contain at least one uppercase letter'),
      );

      // Has uppercase
      final validResult = field.validateValue('Password123');
      expect(validResult.isValid, isTrue);
    });

    test('validates password with lowercase requirement', () {
      const field = FormFieldConfig(
        name: 'password',
        label: 'Password',
        type: FormFieldType.password,
        required: true,
        metadata: {'requiresLowercase': true},
      );

      // No lowercase
      final noLowerResult = field.validateValue('PASSWORD123');
      expect(noLowerResult.isValid, isFalse);
      expect(
        noLowerResult.errors.first,
        contains('must contain at least one lowercase letter'),
      );

      // Has lowercase
      final validResult = field.validateValue('Password123');
      expect(validResult.isValid, isTrue);
    });

    test('validates password with number requirement', () {
      const field = FormFieldConfig(
        name: 'password',
        label: 'Password',
        type: FormFieldType.password,
        required: true,
        metadata: {'requiresNumber': true},
      );

      // No number
      final noNumberResult = field.validateValue('Password');
      expect(noNumberResult.isValid, isFalse);
      expect(
        noNumberResult.errors.first,
        contains('must contain at least one number'),
      );

      // Has number
      final validResult = field.validateValue('Password1');
      expect(validResult.isValid, isTrue);
    });

    test('validates password with special character requirement', () {
      const field = FormFieldConfig(
        name: 'password',
        label: 'Password',
        type: FormFieldType.password,
        required: true,
        metadata: {'requiresSpecial': true},
      );

      // No special character
      final noSpecialResult = field.validateValue('Password123');
      expect(noSpecialResult.isValid, isFalse);
      expect(
        noSpecialResult.errors.first,
        contains('must contain at least one special character'),
      );

      // Has special character
      final validResult = field.validateValue('Password123!');
      expect(validResult.isValid, isTrue);
    });

    test('validates password with multiple requirements', () {
      const field = FormFieldConfig(
        name: 'password',
        label: 'Password',
        type: FormFieldType.password,
        required: true,
        metadata: {
          'minLength': 8,
          'requiresUppercase': true,
          'requiresLowercase': true,
          'requiresNumber': true,
          'requiresSpecial': true,
        },
      );

      // Fails all requirements
      final failResult = field.validateValue('abc');
      expect(failResult.isValid, isFalse);
      expect(failResult.errors.length, greaterThan(1));

      // Passes all requirements
      final validResult = field.validateValue('Password123!');
      expect(validResult.isValid, isTrue);
    });

    test('allows password without metadata', () {
      const field = FormFieldConfig(
        name: 'password',
        label: 'Password',
        type: FormFieldType.password,
        required: true,
      );

      final result = field.validateValue('anypassword');
      expect(result.isValid, isTrue);
    });
  });

  group('FormFieldConfig - HiddenField Validation', () {
    test('hidden field is always valid with any value', () {
      const field = FormFieldConfig(
        name: 'hidden',
        label: 'Hidden Field',
        type: FormFieldType.hiddenField,
      );

      expect(field.validateValue('any value').isValid, isTrue);
      expect(field.validateValue('').isValid, isTrue);
      expect(field.validateValue('123').isValid, isTrue);
    });

    test('hidden field ignores required flag', () {
      const field = FormFieldConfig(
        name: 'hidden',
        label: 'Hidden Field',
        type: FormFieldType.hiddenField,
        required: true,
      );

      // Even empty values are valid for hidden fields
      expect(field.validateValue('').isValid, isTrue);
    });

    test('hidden field with default value', () {
      const field = FormFieldConfig(
        name: 'state',
        label: 'State',
        type: FormFieldType.hiddenField,
        defaultValue: 'initial',
      );

      expect(field.defaultValue, equals('initial'));
      expect(field.validateValue('initial').isValid, isTrue);
      expect(field.validateValue('changed').isValid, isTrue);
    });
  });

  group('FormFieldConfig - HTML Validation', () {
    test('html field validates without sanitization requirement', () {
      const field = FormFieldConfig(
        name: 'content',
        label: 'Content',
        type: FormFieldType.html,
      );

      final result = field.validateValue('<p>Hello World</p>');
      expect(result.isValid, isTrue);
    });

    test('html field detects dangerous tags when sanitization enabled', () {
      const field = FormFieldConfig(
        name: 'content',
        label: 'Content',
        type: FormFieldType.html,
        metadata: {'requiresSanitization': true},
      );

      // Test script tag
      final scriptResult = field.validateValue('<script>alert("xss")</script>');
      expect(scriptResult.isValid, isFalse);
      expect(
        scriptResult.errors.first,
        contains('potentially unsafe HTML content'),
      );

      // Test iframe tag
      final iframeResult = field.validateValue('<iframe src="evil.com"></iframe>');
      expect(iframeResult.isValid, isFalse);

      // Test onclick attribute
      final onclickResult = field.validateValue('<div onclick="alert()">Click</div>');
      expect(onclickResult.isValid, isFalse);

      // Test onerror attribute
      final onerrorResult = field.validateValue('<img onerror="alert()" src="">');
      expect(onerrorResult.isValid, isFalse);

      // Test object tag
      final objectResult = field.validateValue('<object data="evil"></object>');
      expect(objectResult.isValid, isFalse);

      // Test embed tag
      final embedResult = field.validateValue('<embed src="evil">');
      expect(embedResult.isValid, isFalse);
    });

    test('html field allows safe tags when sanitization enabled', () {
      const field = FormFieldConfig(
        name: 'content',
        label: 'Content',
        type: FormFieldType.html,
        metadata: {'requiresSanitization': true},
      );

      const safeHtml = '''
        <div>
          <h1>Title</h1>
          <p>Paragraph with <strong>bold</strong> and <em>italic</em></p>
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
          </ul>
        </div>
      ''';

      final result = field.validateValue(safeHtml);
      expect(result.isValid, isTrue);
    });

    test('html field case-insensitive dangerous tag detection', () {
      const field = FormFieldConfig(
        name: 'content',
        label: 'Content',
        type: FormFieldType.html,
        metadata: {'requiresSanitization': true},
      );

      // Uppercase tags should also be detected
      final upperResult = field.validateValue('<SCRIPT>alert("xss")</SCRIPT>');
      expect(upperResult.isValid, isFalse);

      // Mixed case
      final mixedResult = field.validateValue('<ScRiPt>alert("xss")</ScRiPt>');
      expect(mixedResult.isValid, isFalse);
    });
  });

  group('FormFieldConfig - Integration Tests', () {
    test('creates form with all field types including new ones', () {
      final fields = [
        const FormFieldConfig(
          name: 'username',
          label: 'Username',
          type: FormFieldType.text,
          required: true,
        ),
        const FormFieldConfig(
          name: 'password',
          label: 'Password',
          type: FormFieldType.password,
          required: true,
          metadata: {'minLength': 8, 'requiresNumber': true},
        ),
        const FormFieldConfig(
          name: 'sessionId',
          label: 'Session ID',
          type: FormFieldType.hiddenField,
          defaultValue: 'abc123',
        ),
        const FormFieldConfig(
          name: 'instructions',
          label: 'Instructions',
          type: FormFieldType.html,
          metadata: {'requiresSanitization': true},
        ),
      ];

      expect(fields.length, equals(4));
      expect(fields[0].type, equals(FormFieldType.text));
      expect(fields[1].type, equals(FormFieldType.password));
      expect(fields[2].type, equals(FormFieldType.hiddenField));
      expect(fields[3].type, equals(FormFieldType.html));
    });

    test('validates complete form with new field types', () {
      const passwordField = FormFieldConfig(
        name: 'password',
        label: 'Password',
        type: FormFieldType.password,
        required: true,
        metadata: {'minLength': 8},
      );

      const hiddenField = FormFieldConfig(
        name: 'csrf',
        label: 'CSRF Token',
        type: FormFieldType.hiddenField,
        defaultValue: 'token123',
      );

      const htmlField = FormFieldConfig(
        name: 'bio',
        label: 'Biography',
        type: FormFieldType.html,
        metadata: {'requiresSanitization': true},
      );

      // Valid values
      expect(passwordField.validateValue('SecurePass123').isValid, isTrue);
      expect(hiddenField.validateValue('token123').isValid, isTrue);
      expect(htmlField.validateValue('<p>Safe content</p>').isValid, isTrue);

      // Invalid values
      expect(passwordField.validateValue('short').isValid, isFalse);
      expect(htmlField.validateValue('<script>bad</script>').isValid, isFalse);
    });
  });
}
