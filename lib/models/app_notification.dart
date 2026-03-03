/// In-app notification from the backend.
class AppNotification {
  final String id;
  final String category; // transaction, approval, team, system, customer, security
  final String title;
  final String message;
  final bool isRead;
  final String? readAt;
  final String? relatedObjectId;
  final String createdAt;

  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    this.isRead = false,
    this.readAt,
    this.relatedObjectId,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        category: json['category'] ?? '',
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        isRead: json['is_read'] ?? false,
        readAt: json['read_at'],
        relatedObjectId: json['related_object_id'],
        createdAt: json['created_at'] ?? '',
      );
}
