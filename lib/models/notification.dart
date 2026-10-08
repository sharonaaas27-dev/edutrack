/// Notification model for the notification center.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    this.isRead = false,
    this.createdAt,
    this.type,
  });

  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String? type;

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: (map['id'] ?? map['notification_id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      message: (map['message'] ?? map['body'] ?? '').toString(),
      isRead: (map['is_read'] ?? map['isRead'] ?? false) == true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString())
              : null),
      type: map['type']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
      'type': type,
    };
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      type: type,
    );
  }
}
