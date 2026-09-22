class SyncOperationModel {
  final String id;
  final String tableName;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final String payload;
  final String createdAt;
  final String status; // 'PENDING', 'PROCESSING', 'SYNCED', 'FAILED'
  final int retryCount;

  SyncOperationModel({
    required this.id,
    required this.tableName,
    required this.operation,
    required this.payload,
    required this.createdAt,
    this.status = 'PENDING',
    this.retryCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'table_name': tableName,
      'operation': operation,
      'payload': payload,
      'created_at': createdAt,
      'status': status,
      'retry_count': retryCount,
    };
  }

  factory SyncOperationModel.fromMap(Map<String, dynamic> map) {
    return SyncOperationModel(
      id: map['id'] ?? '',
      tableName: map['table_name'] ?? '',
      operation: map['operation'] ?? '',
      payload: map['payload'] ?? '',
      createdAt: map['created_at'] ?? '',
      status: map['status'] ?? 'PENDING',
      retryCount: map['retry_count']?.toInt() ?? 0,
    );
  }

  SyncOperationModel copyWith({
    String? id,
    String? tableName,
    String? operation,
    String? payload,
    String? createdAt,
    String? status,
    int? retryCount,
  }) {
    return SyncOperationModel(
      id: id ?? this.id,
      tableName: tableName ?? this.tableName,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
