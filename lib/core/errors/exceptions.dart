class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException($code): $message';
}

class ApiException extends AppException {
  final int? statusCode;

  ApiException({
    required super.message,
    super.code,
    super.originalError,
    this.statusCode,
  });
}

class DatabaseException extends AppException {
  DatabaseException({
    required super.message,
    super.code,
    super.originalError,
  });
}

class QueueException extends AppException {
  QueueException({
    required super.message,
    super.code,
    super.originalError,
  });
}

class StorageException extends AppException {
  StorageException({
    required super.message,
    super.code,
    super.originalError,
  });
}
