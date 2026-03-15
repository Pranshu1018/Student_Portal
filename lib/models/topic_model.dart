class Topic {
  final int id;
  final int subjectId;
  final String title;
  final String? videoUrl;
  final String content;

  Topic({
    required this.id,
    required this.subjectId,
    required this.title,
    this.videoUrl,
    required this.content,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] is String ? int.tryParse(json['id']) ?? 0 : (json['id'] as num).toInt(),
      subjectId: json['subject_id'] is String ? int.tryParse(json['subject_id']) ?? 0 : (json['subject_id'] as num).toInt(),
      title: json['title'] ?? '',
      videoUrl: json['video_url'],
      content: json['content'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'title': title,
      'video_url': videoUrl,
      'content': content,
    };
  }
}
