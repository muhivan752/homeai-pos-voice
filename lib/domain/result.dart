/// Result type for clean error handling.
/// Similar to Either/Result pattern in functional programming.
///
/// Usage:
/// ```dart
/// Future<Result<CartTotal, String>> readTotal() async {
///   try {
///     return Success(cartTotal);
///   } catch (e) {
///     return Failure('Failed to read total: $e');
///   }
/// }
///
/// final result = await readTotal();
/// result.when(
///   success: (total) => print('Total: ${total.grandTotal}'),
///   failure: (error) => print('Error: $error'),
/// );
/// ```
sealed class Result<T, E> {
  const Result();

  /// Pattern matching for Result
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  });

  /// Map success value
  Result<U, E> map<U>(U Function(T value) transform);

  /// Map failure error
  Result<T, F> mapError<F>(F Function(E error) transform);

  /// Returns true if this is a Success
  bool get isSuccess;

  /// Returns true if this is a Failure
  bool get isFailure => !isSuccess;

  /// Get value or null
  T? get valueOrNull;

  /// Get error or null
  E? get errorOrNull;

  /// Get value or throw
  T get valueOrThrow;
}

/// Success result containing a value
class Success<T, E> extends Result<T, E> {
  final T value;

  const Success(this.value);

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) =>
      success(value);

  @override
  Result<U, E> map<U>(U Function(T value) transform) =>
      Success(transform(value));

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) => Success(value);

  @override
  bool get isSuccess => true;

  @override
  T? get valueOrNull => value;

  @override
  E? get errorOrNull => null;

  @override
  T get valueOrThrow => value;

  @override
  bool operator ==(Object other) =>
      other is Success<T, E> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

/// Failure result containing an error
class Failure<T, E> extends Result<T, E> {
  final E error;

  const Failure(this.error);

  @override
  R when<R>({
    required R Function(T value) success,
    required R Function(E error) failure,
  }) =>
      failure(error);

  @override
  Result<U, E> map<U>(U Function(T value) transform) => Failure(error);

  @override
  Result<T, F> mapError<F>(F Function(E error) transform) =>
      Failure(transform(error));

  @override
  bool get isSuccess => false;

  @override
  T? get valueOrNull => null;

  @override
  E? get errorOrNull => error;

  @override
  T get valueOrThrow => throw StateError('Cannot get value from Failure: $error');

  @override
  bool operator ==(Object other) =>
      other is Failure<T, E> && other.error == error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'Failure($error)';
}

/// Domain-specific error types
sealed class DomainError {
  final String message;
  const DomainError(this.message);

  @override
  String toString() => message;
}

/// Error dari business rule validation
class ValidationError extends DomainError {
  const ValidationError(super.message);
}

/// Error dari infrastructure (ERP, network, dll)
class InfrastructureError extends DomainError {
  const InfrastructureError(super.message);
}

/// Error tidak ditemukan (item, invoice, dll)
class NotFoundError extends DomainError {
  const NotFoundError(super.message);
}

/// Error authorization
class AuthorizationError extends DomainError {
  const AuthorizationError(super.message);
}
