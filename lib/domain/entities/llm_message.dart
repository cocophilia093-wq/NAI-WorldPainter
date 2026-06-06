import 'package:equatable/equatable.dart';

enum LlmMessageRole { user, assistant }

class LlmMessage extends Equatable {
  final int? id;
  final String sessionId;
  final LlmMessageRole role;
  final String content;
  final DateTime createdAt;
  /// 图片 base64（仅内存，不持久化到 DB）
  final String? imageBase64;
  /// 三段式流程当前阶段（仅内存）：
  /// null → 普通消息；'extracting' → 抽取关键词；'searching' → 检索 Danbooru；
  /// 'composing' → 编排提示词；'done' → 流程完成（成功）；'fallback' → 降级到单次 LLM。
  final String? pipelineStage;
  /// 阶段对应的展示文案（仅内存）。例："📚 正在检索 Danbooru…"
  final String? pipelineStatus;

  const LlmMessage({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.imageBase64,
    this.pipelineStage,
    this.pipelineStatus,
  });

  String get roleString => role == LlmMessageRole.user ? 'user' : 'assistant';

  static LlmMessageRole roleFromString(String s) =>
      s == 'user' ? LlmMessageRole.user : LlmMessageRole.assistant;

  LlmMessage copyWith({
    int? id,
    String? sessionId,
    LlmMessageRole? role,
    String? content,
    DateTime? createdAt,
    String? imageBase64,
    String? pipelineStage,
    String? pipelineStatus,
  }) {
    return LlmMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      imageBase64: imageBase64 ?? this.imageBase64,
      pipelineStage: pipelineStage ?? this.pipelineStage,
      pipelineStatus: pipelineStatus ?? this.pipelineStatus,
    );
  }

  @override
  List<Object?> get props => [id, sessionId, role, content, createdAt];
}
