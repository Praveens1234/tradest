class EAModel {
  final int id;
  final String name;
  final String path;
  final String type;
  final String updatedAt;
  final String? content;

  const EAModel({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    required this.updatedAt,
    this.content,
  });

  factory EAModel.fromJson(Map<String, dynamic> json) {
    return EAModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      type: json['type'] as String? ?? 'EA',
      updatedAt: json['updated_at'] as String? ?? json['updatedAt'] as String? ?? '',
      content: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'updated_at': updatedAt,
      if (content != null) 'content': content,
    };
  }

  EAModel copyWith({
    int? id,
    String? name,
    String? path,
    String? type,
    String? updatedAt,
    String? content,
  }) {
    return EAModel(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      updatedAt: updatedAt ?? this.updatedAt,
      content: content ?? this.content,
    );
  }
}
