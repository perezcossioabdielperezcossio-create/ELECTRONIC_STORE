/// Gestiona la sincronización offline-first con el backend remoto.
class SyncManager {
  const SyncManager();

  /// Encola una operación pendiente para sincronizar cuando haya conexión.
  Future<void> enqueue(String table, Map<String, dynamic> payload) async {
    // TODO: implementar cola con drift o sqflite
  }

  /// Intenta sincronizar todas las operaciones pendientes.
  Future<void> syncPending() async {
    // TODO: implementar lógica de reintento con backoff
  }
}
