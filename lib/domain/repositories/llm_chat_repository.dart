import 'package:nai_huishi/domain/entities/llm_message.dart';
import 'package:nai_huishi/domain/entities/llm_session.dart';

abstract class LlmChatRepository {
  Future<List<LlmSession>> listSessions();
  Future<LlmSession> createSession({String? initialTitle});
  Future<void> renameSession(String id, String title);
  Future<void> deleteSession(String id);
  Future<void> deleteAllSessions();
  Future<List<LlmMessage>> listMessages(String sessionId);

  /// 发送一条用户消息，自动落库 + 调 LLM + 落库 assistant 回复，返回 assistant 消息
  Future<LlmMessage> sendUserMessage({
    required String sessionId,
    required String userText,
    String? imageBase64,
    required String systemPrompt,
    required String apiKey,
    required String baseUrl,
    required String model,
    int contextLimit = 20,
  });

  /// 删除指定消息及其之后的所有消息
  Future<void> deleteMessagesFrom(int messageId, String sessionId);

  /// 不落库的轻量调用：直接调 LLM chat completions，返回 assistant 文本。
  /// 用于"关键词抽取"等不需要进入会话历史的中间步骤。
  Future<String> chatCompletionsRaw({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String systemPrompt,
    required String userText,
  });
}
