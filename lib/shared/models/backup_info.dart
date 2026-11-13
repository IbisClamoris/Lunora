class BackupInfo {
  final String id;
  final String fileName;
  final String filePath;
  final DateTime createdAt;
  final int fileSize;
  final String status;

  const BackupInfo({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.fileSize,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fileName': fileName,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'fileSize': fileSize,
      'status': status,
    };
  }

  factory BackupInfo.fromMap(Map<String, dynamic> map) {
    return BackupInfo(
      id: map['id'] as String,
      fileName: map['fileName'] as String,
      filePath: map['filePath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      fileSize: map['fileSize'] as int,
      status: map['status'] as String,
    );
  }
}
