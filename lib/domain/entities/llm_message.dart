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
  /// Danbooru 校准后的正向 prompt（仅内存，不持久化到 DB）。
  /// 校准成功后由 ViewModel 写入；UI 渲染时若非空则替换 LLM 原始正向代码块内容。
  final String? calibratedPositive;
  /// Danbooru 校准状态文案（仅内存）：成功显示统计，失败显示灰色提示。
  /// 例："✓ 校准 3 个 tag · ➕ 补 5 个共现" 或 "Danbooru 校准失败，使用 LLM 原始结果"
  final String? calibrationStatus;
  /// 校准是否成功（仅内存）：决定状态条样式
  final bool calibrationSuccess;

  const LlmMessage({
    this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.imageBase64,
    this.calibratedPositive,
    this.calibrationStatus,
    this.calibrationSuccess = false,
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
    String? calibratedPositive,
    String? calibrationStatus,
    bool? calibrationSuccess,
  }) {
    return LlmMessage(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      imageBase64: imageBase64 ?? this.imageBase64,
      calibratedPositive: calibratedPositive ?? this.calibratedPositive,
      calibrationStatus: calibrationStatus ?? this.calibrationStatus,
      calibrationSuccess: calibrationSuccess ?? this.calibrationSuccess,
    );
  }

  @override
  List<Object?> get props => [id, sessionId, role, content, createdAt];
}
