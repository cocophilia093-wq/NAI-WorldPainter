import 'package:equatable/equatable.dart';

class PromptTemplate extends Equatable {
  final int? id;
  final String name;
  final String category;
  final String content;
  final List<String> tags;
  final int useCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromptTemplate({
    this.id,
    required this.name,
    required this.category,
    required this.content,
    this.tags = const [],
    this.useCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  PromptTemplate copyWith({
    int? id,
    String? name,
    String? category,
    String? content,
    List<String>? tags,
    int? useCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromptTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      useCount: useCount ?? this.useCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
