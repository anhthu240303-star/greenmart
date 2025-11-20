class BatchHistoryService {
  // Simple in-memory session history. Each entry: { batchId, timestamp, payload }
  static final List<Map<String, dynamic>> _history = [];

  static void add(String batchId, Map<String, dynamic> payload) {
    _history.add({
      'batchId': batchId,
      'timestamp': DateTime.now().toIso8601String(),
      'payload': Map<String, dynamic>.from(payload),
    });
  }

  static List<Map<String, dynamic>> getFor(String batchId) {
    return _history.where((h) => h['batchId'] == batchId).toList().reversed.toList();
  }

  static void clear() => _history.clear();
}
