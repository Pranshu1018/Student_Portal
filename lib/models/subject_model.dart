class Subject {
  final int id;
  final String name;
  final String? description;
  final String? icon;

  Subject({
    required this.id,
    required this.name,
    this.description,
    this.icon,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
    };
  }
}
