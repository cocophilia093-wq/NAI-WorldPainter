import 'package:flutter/foundation.dart';
import 'package:nai_huishi/core/constants/app_constants.dart';
import 'package:nai_huishi/data/datasources/remote/bing_search_service.dart';
import 'package:nai_huishi/data/nsfw_book.dart';
import 'package:nai_huishi/domain/entities/llm_message.dart';
import 'package:nai_huishi/domain/entities/llm_session.dart';
import 'package:nai_huishi/domain/usecases/manage_llm_chat.dart';
import 'package:nai_huishi/domain/usecases/manage_settings.dart';
import 'package:nai_huishi/domain/usecases/calibrate_with_danbooru.dart';

class LlmProfile {
  final String name;
  final String apiKey;
  final String baseUrl;
  final String model;

  const LlmProfile({
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });

  bool get isConfigured =>
      apiKey.trim().isNotEmpty && baseUrl.trim().isNotEmpty && model.trim().isNotEmpty;

  LlmProfile copyWith({String? name, String? apiKey, String? baseUrl, String? model}) {
    return LlmProfile(
      name: name ?? this.name,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
    );
  }
}

class LlmChatViewModel extends ChangeNotifier {
  final ManageLlmChatUseCase _manageChat;
  final ManageSettingsUseCase _manageSettings;
  final BingSearchService _bingSearch;
  final CalibrateWithDanbooruUseCase _calibrate;

  LlmChatViewModel({
    required ManageLlmChatUseCase manageChat,
    required ManageSettingsUseCase manageSettings,
    required BingSearchService bingSearch,
    required CalibrateWithDanbooruUseCase calibrate,
  })  : _manageChat = manageChat,
        _manageSettings = manageSettings,
        _bingSearch = bingSearch,
        _calibrate = calibrate;

  // 配置（旧单配置，保留兼容）
  String _llmApiKey = '';
  String _llmBaseUrl = '';
  String _llmModel = '';
  String _systemPrompt = AppConstants.defaultLlmSystemPrompt;

  // 多配置位
  List<LlmProfile> _profiles = List.generate(
    AppConstants.llmProfileCount,
    (i) => LlmProfile(name: '配置 ${i + 1}', apiKey: '', baseUrl: '', model: ''),
  );
  int _activeProfileIndex = 0;
  int _contextLimit = AppConstants.defaultLlmContextLimit;

  // 会话
  List<LlmSession> _sessions = [];
  String? _activeSessionId;
  List<LlmMessage> _messages = [];

  // 状态
  bool _isSending = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialized = false;

  // 知识库
  final NsfwBook _nsfwBook = NsfwBook();

  // 联网搜索（手动开关）
  bool _webSearchEnabled = false;

  // Getters（旧接口，指向当前激活 profile）
  String get llmApiKey => _activeProfile.apiKey.isNotEmpty ? _activeProfile.apiKey : _llmApiKey;
  String get llmBaseUrl => _activeProfile.baseUrl.isNotEmpty ? _activeProfile.baseUrl : _llmBaseUrl;
  String get llmModel => _activeProfile.model.isNotEmpty ? _activeProfile.model : _llmModel;
  String get systemPrompt => _systemPrompt;

  LlmProfile get _activeProfile => _profiles[_activeProfileIndex];
  List<LlmProfile> get profiles => List.unmodifiable(_profiles);
  int get activeProfileIndex => _activeProfileIndex;
  int get contextLimit => _contextLimit;

  List<LlmSession> get sessions => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;
  LlmSession? get activeSession {
    for (final s in _sessions) {
      if (s.id == _activeSessionId) return s;
    }
    return null;
  }

  List<LlmMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => _activeProfile.isConfigured ||
      (_llmApiKey.trim().isNotEmpty && _llmBaseUrl.trim().isNotEmpty && _llmModel.trim().isNotEmpty);

  NsfwBook get nsfwBook => _nsfwBook;

  bool get webSearchEnabled => _webSearchEnabled;
  Future<void> toggleWebSearch() async {
    _webSearchEnabled = !_webSearchEnabled;
    notifyListeners();
    // 持久化：跨会话保留开关状态
    await _manageSettings.setWebSearchEnabled(_webSearchEnabled);
  }

  /// 初次进入面板时调用；幂等
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    _isLoading = true;
    notifyListeners();

    _llmApiKey = await _manageSettings.getLlmApiKey() ?? '';
    _llmBaseUrl = await _manageSettings.getLlmBaseUrl();
    _llmModel = await _manageSettings.getLlmModel();
    _systemPrompt = await _manageSettings.getLlmSystemPrompt();
    _activeProfileIndex = await _manageSettings.getLlmActiveProfile();
    _contextLimit = await _manageSettings.getLlmContextLimit();
    _webSearchEnabled = await _manageSettings.getWebSearchEnabled();

    // 加载知识库：先用打包进 APK 的默认 asset，再让用户外部路径覆盖
    await _nsfwBook.loadFromAsset();
    final bookPath = await _manageSettings.getNsfwBookPath();
    if (bookPath != null && bookPath.isNotEmpty) {
      await _nsfwBook.load(bookPath);
    }

    final profiles = <LlmProfile>[];
    for (int i = 0; i < AppConstants.llmProfileCount; i++) {
      profiles.add(LlmProfile(
        name: await _manageSettings.getLlmProfileName(i),
        apiKey: await _manageSettings.getLlmProfileApiKey(i) ?? '',
        baseUrl: await _manageSettings.getLlmProfileBaseUrl(i),
        model: await _manageSettings.getLlmProfileModel(i),
      ));
    }
    _profiles = profiles;

    _sessions = await _manageChat.listSessions();
    final lastActive = await _manageSettings.getLlmActiveSessionId();
    if (lastActive != null && _sessions.any((s) => s.id == lastActive)) {
      _activeSessionId = lastActive;
    } else if (_sessions.isNotEmpty) {
      _activeSessionId = _sessions.first.id;
      await _manageSettings.setLlmActiveSessionId(_activeSessionId);
    } else {
      final created = await _manageChat.createSession();
      _sessions = [created];
      _activeSessionId = created.id;
      await _manageSettings.setLlmActiveSessionId(_activeSessionId);
    }

    if (_activeSessionId != null) {
      _messages = await _manageChat.listMessages(_activeSessionId!);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setLlmApiKey(String value) async {
    await _manageSettings.setLlmApiKey(value);
    _llmApiKey = value;
    notifyListeners();
  }

  Future<void> setLlmBaseUrl(String value) async {
    await _manageSettings.setLlmBaseUrl(value);
    _llmBaseUrl = value;
    notifyListeners();
  }

  Future<void> setLlmModel(String value) async {
    await _manageSettings.setLlmModel(value);
    _llmModel = value;
    notifyListeners();
  }

  Future<void> setSystemPrompt(String value) async {
    final v = value.trim().isEmpty ? AppConstants.defaultLlmSystemPrompt : value;
    await _manageSettings.setLlmSystemPrompt(v);
    _systemPrompt = v;
    notifyListeners();
  }

  Future<void> resetSystemPrompt() async {
    await setSystemPrompt(AppConstants.defaultLlmSystemPrompt);
  }

  /// 从设置读取路径并重新加载知识库。保存设置后调用。
  /// 始终先加载 asset 默认库，再让外部路径覆盖（路径为空则保留 asset 内容）。
  Future<void> reloadNsfwBook() async {
    await _nsfwBook.loadFromAsset();
    final path = await _manageSettings.getNsfwBookPath();
    if (path != null && path.isNotEmpty) {
      await _nsfwBook.load(path);
    }
  }

  Future<void> switchProfile(int index) async {
    if (index < 0 || index >= AppConstants.llmProfileCount) return;
    _activeProfileIndex = index;
    await _manageSettings.setLlmActiveProfile(index);
    notifyListeners();
  }

  Future<void> saveProfile(int index, {
    required String name,
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    await _manageSettings.setLlmProfileName(index, name);
    await _manageSettings.setLlmProfileApiKey(index, apiKey);
    await _manageSettings.setLlmProfileBaseUrl(index, baseUrl);
    await _manageSettings.setLlmProfileModel(index, model);
    final updated = List<LlmProfile>.from(_profiles);
    updated[index] = LlmProfile(name: name, apiKey: apiKey, baseUrl: baseUrl, model: model);
    _profiles = updated;
    notifyListeners();
  }

  Future<void> setContextLimit(int value) async {
    final v = value.clamp(1, 200);
    await _manageSettings.setLlmContextLimit(v);
    _contextLimit = v;
    notifyListeners();
  }

  Future<void> createNewSession() async {
    final created = await _manageChat.createSession();
    _sessions = [created, ..._sessions];
    _activeSessionId = created.id;
    _messages = [];
    await _manageSettings.setLlmActiveSessionId(_activeSessionId);
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> selectSession(String id) async {
    if (id == _activeSessionId) return;
    _activeSessionId = id;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _messages = await _manageChat.listMessages(id);
    await _manageSettings.setLlmActiveSessionId(id);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> renameSession(String id, String title) async {
    await _manageChat.renameSession(id, title);
    _sessions = await _manageChat.listSessions();
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    await _manageChat.deleteSession(id);
    _sessions = await _manageChat.listSessions();
    if (_activeSessionId == id) {
      if (_sessions.isNotEmpty) {
        _activeSessionId = _sessions.first.id;
        _messages = await _manageChat.listMessages(_activeSessionId!);
      } else {
        final created = await _manageChat.createSession();
        _sessions = [created];
        _activeSessionId = created.id;
        _messages = [];
      }
      await _manageSettings.setLlmActiveSessionId(_activeSessionId);
    }
    notifyListeners();
  }

  Future<void> sendUserMessage(String text, {String? imageBase64}) async {
    final trimmed = text.trim();
    if ((trimmed.isEmpty && imageBase64 == null) || _isSending) return;
    if (_activeSessionId == null) {
      await createNewSession();
    }
    if (!isConfigured) {
      _errorMessage = '请先点击右上角齿轮，配置 API Key / Base URL / 模型名';
      notifyListeners();
      return;
    }

    final sessionId = _activeSessionId!;
    _isSending = true;
    _errorMessage = null;

    final displayContent = imageBase64 != null
        ? (trimmed.isNotEmpty ? '$trimmed\n[图片]' : '[图片]')
        : trimmed;
    final tentativeUserMessage = LlmMessage(
      sessionId: sessionId,
      role: LlmMessageRole.user,
      content: displayContent,
      createdAt: DateTime.now(),
      imageBase64: imageBase64,
    );
    _messages = [..._messages, tentativeUserMessage];
    notifyListeners();

    try {
      // 知识库匹配
      final knowledgeEntries = _nsfwBook.match(trimmed);
      String augmentedSystemPrompt = _systemPrompt;
      if (knowledgeEntries.isNotEmpty) {
        final knowledgeText = knowledgeEntries
            .map((e) => '[来源: ${e.source} - ${e.title}]\n${e.content}')
            .join('\n\n---\n\n');
        augmentedSystemPrompt = '$_systemPrompt\n\n'
            '## 参考知识库（命中关键词）\n'
            '以下内容是从知识库中匹配到的相关提示词参考：\n\n'
            '$knowledgeText\n'
            '## 根据以上参考知识，请帮我更好地完善提示词\n';
      }

      // 联网搜索（手动开关启用时执行）
      if (_webSearchEnabled && trimmed.isNotEmpty) {
        try {
          final searchResult = await _bingSearch.searchCharacter(trimmed);
          if (searchResult.isNotEmpty) {
            augmentedSystemPrompt = '$augmentedSystemPrompt\n\n'
                '## 联网搜索结果（角色查询）\n'
                '以下是从 Bing 搜索到的角色相关信息，请据此推断出：\n'
                '1. 准确的 Danbooru 标签格式（角色名 (作品名)）；\n'
                '2. 角色的标志性外貌特征（发色、瞳色、发型、发饰、典型服装、配饰等），'
                '在生成"特定角色"提示词且用户未明确指定外貌或换装时，'
                '应将这些特征作为补充 tag 加入正向提示词，确保画面与角色形象一致；\n'
                '3. 如果用户已经指定了不同的外貌/服装/发型，或要求"原创角色"、"换装"、"AU"等特殊设定，'
                '则以用户输入为准，不要把搜索到的默认外貌强行覆盖上去。\n\n'
                '$searchResult\n';
          }
        } catch (_) {
          // 搜索失败静默忽略，不影响正常对话
        }
      }

      final assistantMessage = await _manageChat.sendUserMessage(
        sessionId: sessionId,
        userText: trimmed,
        imageBase64: imageBase64,
        systemPrompt: augmentedSystemPrompt,
        apiKey: llmApiKey,
        baseUrl: llmBaseUrl,
        model: llmModel,
        contextLimit: _contextLimit,
      );
      _messages = await _manageChat.listMessages(sessionId);
      if (!_messages.any((m) => m.id == assistantMessage.id)) {
        _messages = [..._messages, assistantMessage];
      }
      _sessions = await _manageChat.listSessions();
      // 异步触发 Danbooru 校准（不阻塞 UI）
      if (assistantMessage.id != null) {
        _triggerDanbooruCalibration(
          messageId: assistantMessage.id!,
          assistantContent: assistantMessage.content,
          userQuery: trimmed,
        );
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('AppException(null): ', '');
      _messages = await _manageChat.listMessages(sessionId);
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// 重试：从指定用户消息处重新发送（删除该消息及之后的，重新发送原文）
  Future<void> retryFromIndex(int messageIndex) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];
    if (msg.role != LlmMessageRole.user || msg.id == null) return;
    final text = msg.content.replaceAll(RegExp(r'\n\[图片\]$'), '').trim();
    if (text.isEmpty || _isSending) return;

    // 删除该消息及之后的所有消息
    await _manageChat.deleteMessagesFrom(msg.id!, _activeSessionId!);
    _messages = await _manageChat.listMessages(_activeSessionId!);
    notifyListeners();

    // 重新发送
    await sendUserMessage(text);
  }

  /// 编辑并重发：修改用户消息内容后重新发送
  Future<void> editAndResend(int messageIndex, String newText) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) return;
    final msg = _messages[messageIndex];
    if (msg.role != LlmMessageRole.user || msg.id == null) return;
    final trimmed = newText.trim();
    if (trimmed.isEmpty || _isSending) return;

    // 删除该消息及之后的所有消息
    await _manageChat.deleteMessagesFrom(msg.id!, _activeSessionId!);
    _messages = await _manageChat.listMessages(_activeSessionId!);
    notifyListeners();

    // 用新文本重新发送
    await sendUserMessage(trimmed);
  }

  // ===== Danbooru 校准 =====

  /// 匹配 LLM 回复中的"正向"代码块（含「正向」「正面」「通用底模词」「通用」等关键词的标注）
  static final RegExp _positiveBlockRegex = RegExp(
    r'((?:[^\n]*(?:正向|正面|底模|通用)[^\n]*[:：])\s*\n)```([a-zA-Z0-9_+\-]*)\s*\n([\s\S]*?)```',
  );

  /// 从 LLM 回复中抽取首个正向代码块。返回 null 表示没有找到。
  String? _extractPositive(String content) {
    final m = _positiveBlockRegex.firstMatch(content);
    if (m == null) return null;
    final text = (m.group(3) ?? '').trim();
    if (text.isEmpty) return null;
    // 排除「负向」误命中（标签同时含负向关键词时跳过）
    final label = m.group(1) ?? '';
    if (label.contains('负向') || label.contains('负面')) return null;
    return text;
  }

  /// 异步执行校准并把结果回写到内存中的对应消息。
  Future<void> _triggerDanbooruCalibration({
    required int messageId,
    required String assistantContent,
    required String userQuery,
  }) async {
    // 检查开关
    final enabled = await _manageSettings.getDanbooruCalibrationEnabled();
    if (!enabled) return;
    final positive = _extractPositive(assistantContent);
    if (positive == null) return;

    final customBase = (await _manageSettings.getDanbooruBaseUrl()).trim();
    try {
      final result = await _calibrate.call(
        llmPositive: positive,
        userQuery: userQuery,
        showNsfw: true, // 与应用默认（允许）一致
        customBaseUrl: customBase.isEmpty ? null : customBase,
      );
      _applyCalibrationResult(
        messageId: messageId,
        calibratedPositive: result.calibratedPositive,
        status:
            '✓ 校准 ${result.normalizedCount} 个 tag · ➕ 补 ${result.relatedCount} 个共现',
        success: true,
      );
    } catch (_) {
      _applyCalibrationResult(
        messageId: messageId,
        calibratedPositive: null,
        status: 'Danbooru 校准失败，使用 LLM 原始结果',
        success: false,
      );
    }
  }

  void _applyCalibrationResult({
    required int messageId,
    required String? calibratedPositive,
    required String status,
    required bool success,
  }) {
    var changed = false;
    final updated = <LlmMessage>[];
    for (final m in _messages) {
      if (m.id == messageId) {
        updated.add(m.copyWith(
          calibratedPositive: calibratedPositive,
          calibrationStatus: status,
          calibrationSuccess: success,
        ));
        changed = true;
      } else {
        updated.add(m);
      }
    }
    if (changed) {
      _messages = updated;
      notifyListeners();
    }
  }
}

