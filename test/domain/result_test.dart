import 'package:test/test.dart';
import '../../lib/domain/result.dart';

void main() {
  group('Result', () {
    group('Success', () {
      test('isSuccess returns true', () {
        const result = Success<int, String>(42);
        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
      });

      test('valueOrNull returns value', () {
        const result = Success<int, String>(42);
        expect(result.valueOrNull, equals(42));
      });

      test('errorOrNull returns null', () {
        const result = Success<int, String>(42);
        expect(result.errorOrNull, isNull);
      });

      test('valueOrThrow returns value', () {
        const result = Success<int, String>(42);
        expect(result.valueOrThrow, equals(42));
      });

      test('when calls success callback', () {
        const result = Success<int, String>(42);
        final output = result.when(
          success: (v) => 'got $v',
          failure: (e) => 'error: $e',
        );
        expect(output, equals('got 42'));
      });

      test('map transforms value', () {
        const result = Success<int, String>(42);
        final mapped = result.map((v) => v * 2);
        expect(mapped.valueOrNull, equals(84));
      });
    });

    group('Failure', () {
      test('isSuccess returns false', () {
        const result = Failure<int, String>('error');
        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
      });

      test('valueOrNull returns null', () {
        const result = Failure<int, String>('error');
        expect(result.valueOrNull, isNull);
      });

      test('errorOrNull returns error', () {
        const result = Failure<int, String>('error');
        expect(result.errorOrNull, equals('error'));
      });

      test('valueOrThrow throws', () {
        const result = Failure<int, String>('error');
        expect(() => result.valueOrThrow, throwsStateError);
      });

      test('when calls failure callback', () {
        const result = Failure<int, String>('oops');
        final output = result.when(
          success: (v) => 'got $v',
          failure: (e) => 'error: $e',
        );
        expect(output, equals('error: oops'));
      });

      test('map preserves error', () {
        const result = Failure<int, String>('error');
        final mapped = result.map((v) => v * 2);
        expect(mapped.errorOrNull, equals('error'));
      });
    });
  });

  group('DomainError', () {
    test('ValidationError has correct message', () {
      const error = ValidationError('Invalid qty');
      expect(error.message, equals('Invalid qty'));
      expect(error.toString(), equals('Invalid qty'));
    });

    test('InfrastructureError has correct message', () {
      const error = InfrastructureError('Connection failed');
      expect(error.message, equals('Connection failed'));
    });

    test('NotFoundError has correct message', () {
      const error = NotFoundError('Item not found');
      expect(error.message, equals('Item not found'));
    });

    test('AuthorizationError has correct message', () {
      const error = AuthorizationError('Access denied');
      expect(error.message, equals('Access denied'));
    });
  });
}
