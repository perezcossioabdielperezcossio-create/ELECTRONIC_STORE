class DatabaseException    implements Exception { final String message; const DatabaseException(this.message); }
class NetworkException     implements Exception { final String message; const NetworkException(this.message); }
class ValidationException  implements Exception { final String message; const ValidationException(this.message); }
class NotFoundException    implements Exception { final String message; const NotFoundException(this.message); }
class InsufficientStockException implements Exception { final String message; const InsufficientStockException(this.message); }
class AntiLossException    implements Exception { final String message; const AntiLossException(this.message); }
