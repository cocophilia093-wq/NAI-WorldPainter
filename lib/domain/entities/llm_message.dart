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

  const LlmMessage({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.imageBase64,
  });

  String get roleString => role == LlmMessageRole.user ? 'user' : 'assistant';

  static LlmMessageRole roleFromString(String s) =>
      s == 'user' ? LlmMessageRole.user : LlmMessageRole.assistant;

  LlmMessage copyWith({int? id, String? sessionId, LlmMessageRole? role, String? content, DateTime? createdAt, String? imageBase64}) {
    return LlmMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      imageBase64: imageBase64 ?? this.imageBase64,
    );
  }

  @override
  List<Object?> get props => [id, sessionId, role, content, createdAt];
}
