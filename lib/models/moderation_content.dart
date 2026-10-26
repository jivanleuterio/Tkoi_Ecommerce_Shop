class ModerationContent {
  final String id;
  final String contentType;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String status;
  final String reason;
  final String ownerId;
  final DateTime createdAt;

  const ModerationContent({
    required this.id,
    required this.contentType,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.status,
    required this.reason,
    required this.ownerId,
    required this.createdAt,
  });

  factory ModerationContent.fromMap(Map<String, dynamic> map) =>
      ModerationContent(
        id: map['id'] as String,
        contentType: map['content_type'] as String? ?? 'product',
        title: map['title'] as String? ?? 'Untitled content',
        subtitle: map['subtitle'] as String? ?? '',
        imageUrl: map['image_url'] as String?,
        status: map['moderation_status'] as String? ?? 'clear',
        reason: map['moderation_reason'] as String? ?? '',
        ownerId: map['owner_id'] as String? ?? '',
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
