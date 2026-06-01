import 'package:uuid/uuid.dart';
import 'package:nai_huishi/data/datasources/local/llm_chat_local_datasource.dart';
import 'package:nai_huishi/data/datasources/remote/llm_api_service.dart';
import 'package:nai_huishi/domain/entities/llm_message.dart';
import 'package:nai_huishi/domain/entities/llm_session.dart';
import 'package:nai_huishi/domain/repositories/llm_chat_repository.dart';

class LlmChatRepositoryImpl implements LlmChatRepository {
  final LlmChatLocalDatasource _local;
  final LlmApiService _api;
  final _uuid = const Uuid();

  LlmChatRepositoryImpl({
    required LlmChatLocalDatasource local,
    required LlmApiService api,
  })  : _local = local,
        _api = api;

  @override
  Future<List<LlmSession>> listSessions() => _local.listSessions();

  @override
  Future<LlmSession> createSession({String? initialTitle}) async {
    final now = DateTime.now();
    final session = LlmSession(
      id: _uuid.v4(),
      title: initialTitle ?? '新对话',
      createdAt: now,
      updatedAt: now,
    );
    await _local.insertSession(session);
    return session;
  }

  @override
  Future<void> renameSession(String id, String title) async {
    final existing = await _local.getSession(id);
    if (existing == null) return;
    final updated = existing.copyWith(
      title: title.trim().isEmpty ? '新对话' : title.trim(),
      updatedAt: DateTime.now(),
    );
    await _local.updateSession(updated);
  }

  @override
  Future<void> deleteSession(String id) => _local.deleteSession(id);

  @override
  Future<List<LlmMessage>> listMessages(String sessionId) => _local.listMessages(sessionId);

  @override
  Future<LlmMessage> sendUserMessage({
    required String sessionId,
    required String userText,
    String? imageBase64,
    required String systemPrompt,
    required String apiKey,
    required String baseUrl,
    required String model,
    int contextLimit = 20,
  }) async {
    final now = DateTime.now();

    // 1. 先落库 user 消息（存储文本；图片不持久化到 DB）
    final storeContent = userText.trim().isNotEmpty ? userText : '[图片]';
    final userMessage = LlmMessage(
      sessionId: sessionId,
      role: LlmMessageRole.user,
      content: storeContent,
      createdAt: now,
    );
    final userId = await _local.insertMessage(userMessage);

    // 2. 如果是会话第一条用户消息，用前 20 字更新 session.title
    final allMessages = await _local.listMessages(sessionId);
    final existingSession = await _local.getSession(sessionId);
    if (existingSession != null && allMessages.length == 1) {
      final preview = storeContent.replaceAll(RegExp(r'\s+'), ' ').trim();
      final title = preview.length > 20 ? preview.substring(0, 20) : preview;
      await _local.updateSession(existingSession.copyWith(
        title: title.isEmpty ? '新对话' : title,
        updatedAt: now,
      ));
    } else if (existingSession != null) {
      await _local.touchSession(sessionId, now);
    }

    // 3. 组装上下文（system + 最近 contextLimit 条历史消息）
    final historyMessages = allMessages.length > contextLimit
        ? allMessages.sublist(allMessages.length - contextLimit)
        : allMessages;

    // 构建 payload，支持图片（vision 格式）
    final payload = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
    ];

    for (final m in historyMessages) {
      // 最后一条 user 消息可能带图片
      if (m.id == userId && imageBase64 != null) {
        final contentParts = <Map<String, dynamic>>[];
        if (userText.trim().isNotEmpty) {
          contentParts.add({'type': 'text', 'text': userText});
        }
        contentParts.add({
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$imageBase64'},
        });
        payload.add({'role': 'user', 'content': contentParts});
      } else {
        payload.add({'role': m.roleString, 'content': m.content});
      }
    }

    try {
      final assistantText = await _api.chatCompletions(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
        messages: payload,
      );

      // 4. 落库 assistant 回复
      final replyTime = DateTime.now();
      final assistantMessage = LlmMessage(
        sessionId: sessionId,
        role: LlmMessageRole.assistant,
        content: assistantText,
        createdAt: replyTime,
      );
      final assistantId = await _local.insertMessage(assistantMessage);
      await _local.touchSession(sessionId, replyTime);
      return LlmMessage(
        id: assistantId,
        sessionId: sessionId,
        role: LlmMessageRole.assistant,
        content: assistantText,
        createdAt: replyTime,
      );
    } catch (e) {
      // ignore: unused_local_variable
      final _ = userId;
      rethrow;
    }
  }

  @override
  Future<void> deleteMessagesFrom(int messageId, String sessionId) =>
      _local.deleteMessagesFrom(messageId, sessionId);
}
