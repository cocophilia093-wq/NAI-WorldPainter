import 'dart:convert';
import 'package:nai_huishi/domain/entities/prompt_template.dart';

class PromptTemplateModel {
  final int? id;
  final String name;
  final String category;
  final String content;
  final List<String> tags;
  final int useCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromptTemplateModel({
    this.id,
    required this.name,
    required this.category,
    required this.content,
    this.tags = const [],
    this.useCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromptTemplateModel.fromDb(Map<String, dynamic> row) {
    List<String> tagList = [];
    if (row['tags'] != null && (row['tags'] as String).isNotEmpty) {
      tagList = List<String>.from(jsonDecode(row['tags'] as String) as List);
    }

    return PromptTemplateModel(
      id: row['id'] as int?,
      name: row['name'] as String,
      category: row['category'] as String,
      content: row['content'] as String,
      tags: tagList,
      useCount: row['use_count'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
    );
  }

  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'content': content,
      'tags': jsonEncode(tags),
      'use_count': useCount,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory PromptTemplateModel.fromEntity(PromptTemplate entity) {
    return PromptTemplateModel(
      id: entity.id,
      name: entity.name,
      category: entity.category,
      content: entity.content,
      tags: entity.tags,
      useCount: entity.useCount,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  PromptTemplate toEntity() {
    return PromptTemplate(
      id: id,
      name: name,
      category: category,
      content: content,
      tags: tags,
      useCount: useCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
