/// Constantes globales de la aplicación.
class AppConstants {
  AppConstants._();

  static const String appName = 'Electronic Store';
  static const String appVersion = '1.0.0';

  // SQLite
  static const String dbName = 'electronic_store.db';
  static const int dbVersion = 2;

  // FIFO
  static const int lowStockThreshold = 5;
}
