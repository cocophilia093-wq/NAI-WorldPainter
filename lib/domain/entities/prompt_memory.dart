import 'package:equatable/equatable.dart';

enum PromptMemoryType { characterName, characterFeature, style, other }
enum PromptMemorySource { manual, userInstruction, llmCandidate }

class PromptMemory extends Equatable {
  final int? id;
  final String trigger;
  final String content;
  final PromptMemoryType type;
  final PromptMemorySource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromptMemory({
    this.id,
    required this.trigger,
    required this.content,
    required this.type,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  PromptMemory copyWith({
    int? id,
    String? trigger,
    String? content,
    PromptMemoryType? type,
    PromptMemorySource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromptMemory(
      id: id ?? this.id,
      trigger: trigger ?? this.trigger,
      content: content ?? this.content,
      type: type ?? this.type,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, trigger, content, type, source, createdAt, updatedAt];
}
