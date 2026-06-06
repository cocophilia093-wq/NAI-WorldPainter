import 'package:nai_huishi/domain/entities/llm_message.dart';
import 'package:nai_huishi/domain/entities/llm_session.dart';
import 'package:nai_huishi/domain/repositories/llm_chat_repository.dart';

class ManageLlmChatUseCase {
  final LlmChatRepository _repo;

  ManageLlmChatUseCase(this._repo);

  Future<List<LlmSession>> listSessions() => _repo.listSessions();
  Future<LlmSession> createSession({String? initialTitle}) =>
      _repo.createSession(initialTitle: initialTitle);
  Future<void> renameSession(String id, String title) => _repo.renameSession(id, title);
  Future<void> deleteSession(String id) => _repo.deleteSession(id);
  Future<List<LlmMessage>> listMessages(String sessionId) => _repo.listMessages(sessionId);

  Future<LlmMessage> sendUserMessage({
    required String sessionId,
    required String userText,
    String? imageBase64,
    required String systemPrompt,
    required String apiKey,
    required String baseUrl,
    required String model,
    int contextLimit = 20,
  }) =>
      _repo.sendUserMessage(
        sessionId: sessionId,
        userText: userText,
        imageBase64: imageBase64,
        systemPrompt: systemPrompt,
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
        contextLimit: contextLimit,
      );

  /// 删除指定消息及其之后的所有消息
  Future<void> deleteMessagesFrom(int messageId, String sessionId) =>
      _repo.deleteMessagesFrom(messageId, sessionId);

  /// 不落库的轻量调用（关键词抽取等中间步骤用）
  Future<String> chatCompletionsRaw({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String systemPrompt,
    required String userText,
  }) =>
      _repo.chatCompletionsRaw(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
        systemPrompt: systemPrompt,
        userText: userText,
      );
}
