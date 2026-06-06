import 'package:flutter/foundation.dart';
import 'package:nai_huishi/core/constants/app_constants.dart';
import 'package:nai_huishi/data/nsfw_book.dart';
import 'package:nai_huishi/domain/entities/danbooru_tag.dart';
import 'package:nai_huishi/domain/entities/llm_message.dart';
import 'package:nai_huishi/domain/entities/llm_session.dart';
import 'package:nai_huishi/domain/entities/prompt_memory.dart';
import 'package:nai_huishi/domain/usecases/extract_keywords.dart';
import 'package:nai_huishi/domain/usecases/manage_llm_chat.dart';
import 'package:nai_huishi/domain/usecases/manage_prompt_memories.dart';
import 'package:nai_huishi/domain/usecases/manage_settings.dart';
import 'package:nai_huishi/domain/usecases/search_danbooru_tags.dart';

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
  final ExtractKeywordsUseCase _extract;
  final SearchDanbooruTagsUseCase _searchTags;
  final ManagePromptMemoriesUseCase _memories;

  LlmChatViewModel({
    required ManageLlmChatUseCase manageChat,
    required ManageSettingsUseCase manageSettings,
    required ExtractKeywordsUseCase extract,
    required SearchDanbooruTagsUseCase searchTags,
    required ManagePromptMemoriesUseCase memories,
  })  : _manageChat = manageChat,
        _manageSettings = manageSettings,
        _extract = extract,
        _searchTags = searchTags,
        _memories = memories;

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

  // 双模型分配（抽取 / 编排）
  int _extractProfileIndex = 0;
  int _composeProfileIndex = 0;

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

  // Danbooru 三段式流程开关（复用旧的 keyDanbooruCalibrationEnabled）
  bool _danbooruSearchEnabled = true;

  // Getters（旧接口，指向当前激活 profile）
  String get llmApiKey => _activeProfile.apiKey.isNotEmpty ? _activeProfile.apiKey : _llmApiKey;
  String get llmBaseUrl => _activeProfile.baseUrl.isNotEmpty ? _activeProfile.baseUrl : _llmBaseUrl;
  String get llmModel => _activeProfile.model.isNotEmpty ? _activeProfile.model : _llmModel;
  String get systemPrompt => _systemPrompt;

  LlmProfile get _activeProfile => _profiles[_activeProfileIndex];
  List<LlmProfile> get profiles => List.unmodifiable(_profiles);
  int get activeProfileIndex => _activeProfileIndex;
  int get extractProfileIndex => _extractProfileIndex;
  int get composeProfileIndex => _composeProfileIndex;
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

  bool get danbooruSearchEnabled => _danbooruSearchEnabled;
  Future<void> toggleDanbooruSearch() async {
    _danbooruSearchEnabled = !_danbooruSearchEnabled;
    notifyListeners();
    await _manageSettings.setDanbooruCalibrationEnabled(_danbooruSearchEnabled);
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
    _extractProfileIndex = await _manageSettings.getLlmExtractProfile();
    _composeProfileIndex = await _manageSettings.getLlmComposeProfile();
    _contextLimit = await _manageSettings.getLlmContextLimit();
    _danbooruSearchEnabled = await _manageSettings.getDanbooruCalibrationEnabled();

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

  Future<void> setExtractProfile(int index) async {
    if (index < 0 || index >= AppConstants.llmProfileCount) return;
    _extractProfileIndex = index;
    await _manageSettings.setLlmExtractProfile(index);
    notifyListeners();
  }

  Future<void> setComposeProfile(int index) async {
    if (index < 0 || index >= AppConstants.llmProfileCount) return;
    _composeProfileIndex = index;
    await _manageSettings.setLlmComposeProfile(index);
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

  Future<void> _captureExplicitMemoryInstruction(String text) async {
    final trimmed = text.trim();
    final patterns = [
      RegExp(r'^记住[:：](.+)$'),
      RegExp(r'^纠正[:：](.+)$'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(trimmed);
      if (match == null) continue;
      final body = match.group(1)?.trim() ?? '';
      final parts = body.split(RegExp(r'应该是|应为|=|：|:'));
      if (parts.length < 2) return;
      final trigger = parts.first.trim();
      final content = parts.sublist(1).join('应该是').trim();
      if (trigger.isEmpty || content.isEmpty) return;
      final now = DateTime.now();
      await _memories.save(PromptMemory(
        trigger: trigger,
        content: content,
        type: PromptMemoryType.other,
        source: PromptMemorySource.userInstruction,
        createdAt: now,
        updatedAt: now,
      ));
      return;
    }
  }

  Future<String> _buildMemoryContext(String userText) async {
    final matched = await _memories.matchText(userText);
    if (matched.isEmpty) return '';
    final lines = matched.take(12).map((m) => '- ${m.trigger}：${m.content}').join('\n');
    return '\n\n## 本地学习记忆（最高优先级）\n'
        '以下内容来自用户纠正或手动记录。若它与 Danbooru、模型常识或检索结果冲突，必须以这里为准：\n'
        '$lines';
  }

  String _learningInstruction() {
    return '\n\n## 学习判断规则\n'
        '如果用户本轮明显纠正了人名、角色特征或画风知识，请在正常回答末尾附加一行：\n'
        '【记忆候选】触发词 => 正确内容\n'
        '如果没有明确纠正，不要输出这行。';
  }

  Future<void> _captureLlmMemoryCandidate(String content) async {
    final match = RegExp(r'【记忆候选】(.+?)\s*=>\s*(.+)').firstMatch(content);
    if (match == null) return;
    final trigger = match.group(1)?.trim() ?? '';
    final value = match.group(2)?.trim() ?? '';
    if (trigger.isEmpty || value.isEmpty) return;
    final now = DateTime.now();
    await _memories.save(PromptMemory(
      trigger: trigger,
      content: value,
      type: PromptMemoryType.other,
      source: PromptMemorySource.llmCandidate,
      createdAt: now,
      updatedAt: now,
    ));
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
    await _captureExplicitMemoryInstruction(trimmed);
    final memoryContext = await _buildMemoryContext(trimmed);
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

    // 决定走哪条流程：含图 / 关闭 Danbooru / 抽取或编排 profile 未配置 → 旧单次流程
    final extractProfile = _profiles[_extractProfileIndex];
    final composeProfile = _profiles[_composeProfileIndex];
    final useDanbooruPipeline = imageBase64 == null &&
        _danbooruSearchEnabled &&
        trimmed.isNotEmpty &&
        extractProfile.isConfigured &&
        composeProfile.isConfigured;

    if (!useDanbooruPipeline) {
      await _runLegacySingleShot(
        sessionId: sessionId,
        trimmed: trimmed,
        imageBase64: imageBase64,
        memoryContext: memoryContext,
      );
      _isSending = false;
      notifyListeners();
      return;
    }

    // === Danbooru 三段式流程 ===
    final placeholderCreatedAt = DateTime.now().add(const Duration(milliseconds: 1));
    var placeholder = LlmMessage(
      sessionId: sessionId,
      role: LlmMessageRole.assistant,
      content: '',
      createdAt: placeholderCreatedAt,
      pipelineStage: 'extracting',
      pipelineStatus: '正在抽取关键词…',
    );
    _messages = [..._messages, placeholder];
    notifyListeners();

    void updatePlaceholder(LlmMessage next) {
      placeholder = next;
      final list = List<LlmMessage>.from(_messages);
      for (int i = list.length - 1; i >= 0; i--) {
        if (list[i].createdAt == placeholderCreatedAt &&
            list[i].role == LlmMessageRole.assistant) {
          list[i] = next;
          break;
        }
      }
      _messages = list;
      notifyListeners();
    }

    void removePlaceholder() {
      _messages = _messages
          .where((m) => !(m.createdAt == placeholderCreatedAt &&
              m.role == LlmMessageRole.assistant))
          .toList();
    }

    try {
      // 阶段 1：抽取关键词（用便宜的小模型）
      final keywords = await _extract.call(
        userText: trimmed,
        apiKey: extractProfile.apiKey,
        baseUrl: extractProfile.baseUrl,
        model: extractProfile.model,
      );

      // 阶段 2：调 Danbooru 检索
      updatePlaceholder(placeholder.copyWith(
        pipelineStage: 'searching',
        pipelineStatus: '正在检索 Danbooru…',
      ));

      final customBase = (await _manageSettings.getDanbooruBaseUrl()).trim();
      final pool = await _searchTags.call(
        keywords: keywords,
        showNsfw: true,
        customBaseUrl: customBase.isEmpty ? null : customBase,
      );

      // 阶段 3：编排（增强 systemPrompt 后调主力 LLM）
      final tagCount = pool.globalTags.length +
          pool.perCharacterTags.fold<int>(0, (a, b) => a + b.length);
      updatePlaceholder(placeholder.copyWith(
        pipelineStage: 'composing',
        pipelineStatus: '正在编排提示词…（已检索 $tagCount 个 tag）',
      ));

      final knowledgeEntries = _nsfwBook.match(trimmed);
      String augmented = _systemPrompt + _learningInstruction();
      if (memoryContext.isNotEmpty) {
        augmented = '$augmented$memoryContext';
      }
      if (knowledgeEntries.isNotEmpty) {
        final knowledgeText = knowledgeEntries
            .map((e) => '[来源: ${e.source} - ${e.title}]\n${e.content}')
            .join('\n\n---\n\n');
        augmented = '$augmented\n\n'
            '## 参考知识库（命中关键词）\n'
            '以下内容是从知识库中匹配到的相关提示词参考：\n\n'
            '$knowledgeText\n';
      }
      augmented = '$augmented\n\n${_buildTagPoolPrompt(pool, keywords)}';

      // 移除占位再调 sendUserMessage（它会把真消息落库）
      removePlaceholder();
      notifyListeners();

      final assistantMessage = await _manageChat.sendUserMessage(
        sessionId: sessionId,
        userText: trimmed,
        imageBase64: imageBase64,
        systemPrompt: augmented,
        apiKey: composeProfile.apiKey,
        baseUrl: composeProfile.baseUrl,
        model: composeProfile.model,
        contextLimit: _contextLimit,
      );
      await _captureLlmMemoryCandidate(assistantMessage.content);
      _messages = await _manageChat.listMessages(sessionId);
      // 给真消息打上 done 标记，气泡底部显示"已检索 N 个 tag"
      _messages = _messages
          .map((m) => m.id == assistantMessage.id
              ? m.copyWith(
                  pipelineStage: 'done',
                  pipelineStatus: 'Danbooru 检索 $tagCount 个 tag',
                )
              : m)
          .toList();
      _sessions = await _manageChat.listSessions();
    } catch (e) {
      // Danbooru 流程失败 → 降级到旧单次流程
      removePlaceholder();
      _errorMessage = 'Danbooru 搜索失败，已降级为单次 LLM 生成';
      notifyListeners();
      try {
        await _runLegacySingleShot(
          sessionId: sessionId,
          trimmed: trimmed,
          imageBase64: imageBase64,
          memoryContext: memoryContext,
          markFallback: true,
        );
      } catch (e2) {
        _errorMessage = e2.toString().replaceFirst('AppException(null): ', '');
      }
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// 旧的单次 LLM 流程（含图 / 用户关掉 Danbooru / 抽取或编排 profile 未配置 / 降级时使用）
  Future<void> _runLegacySingleShot({
    required String sessionId,
    required String trimmed,
    required String? imageBase64,
    required String memoryContext,
    bool markFallback = false,
  }) async {
    try {
      final knowledgeEntries = _nsfwBook.match(trimmed);
      String augmented = _systemPrompt + _learningInstruction();
      if (memoryContext.isNotEmpty) {
        augmented = '$augmented$memoryContext';
      }
      if (knowledgeEntries.isNotEmpty) {
        final knowledgeText = knowledgeEntries
            .map((e) => '[来源: ${e.source} - ${e.title}]\n${e.content}')
            .join('\n\n---\n\n');
        augmented = '$augmented\n\n'
            '## 参考知识库（命中关键词）\n'
            '以下内容是从知识库中匹配到的相关提示词参考：\n\n'
            '$knowledgeText\n'
            '## 根据以上参考知识，请帮我更好地完善提示词\n';
      }
      // 编排 profile 未配置时退到 active profile（兼容旧用户）
      final useProfile = _profiles[_composeProfileIndex].isConfigured
          ? _profiles[_composeProfileIndex]
          : _activeProfile;
      final assistantMessage = await _manageChat.sendUserMessage(
        sessionId: sessionId,
        userText: trimmed,
        imageBase64: imageBase64,
        systemPrompt: augmented,
        apiKey: useProfile.apiKey.isNotEmpty ? useProfile.apiKey : llmApiKey,
        baseUrl: useProfile.baseUrl.isNotEmpty ? useProfile.baseUrl : llmBaseUrl,
        model: useProfile.model.isNotEmpty ? useProfile.model : llmModel,
        contextLimit: _contextLimit,
      );
      await _captureLlmMemoryCandidate(assistantMessage.content);
      _messages = await _manageChat.listMessages(sessionId);
      if (markFallback) {
        _messages = _messages
            .map((m) => m.id == assistantMessage.id
                ? m.copyWith(
                    pipelineStage: 'fallback',
                    pipelineStatus: 'Danbooru 搜索失败，已降级',
                  )
                : m)
            .toList();
      }
      _sessions = await _manageChat.listSessions();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('AppException(null): ', '');
      _messages = await _manageChat.listMessages(sessionId);
      rethrow;
    }
  }

  /// 把 Danbooru 检索结果格式化进 system prompt，让主力 LLM 优先从中挑选。
  String _buildTagPoolPrompt(DanbooruTagPool pool, ExtractedKeywords kw) {
    final buf = StringBuffer();
    buf.writeln('## Danbooru 真实 tag 池');
    buf.writeln('以下 tag 全部来自 Danbooru 实时检索结果，是真实存在且热度可观的 tag。');
    buf.writeln('请优先从中挑选/组合，**不要凭空创造**新的 tag；确实需要补充时，要遵循 Danbooru 命名习惯。');
    buf.writeln();

    if (pool.globalTags.isNotEmpty) {
      buf.writeln('### 全局候选（场景/风格/通用底模）');
      buf.writeln(_formatTagList(pool.globalTags));
      buf.writeln();
    }

    if (kw.characters.isNotEmpty) {
      for (int i = 0; i < kw.characters.length; i++) {
        final tags = i < pool.perCharacterTags.length
            ? pool.perCharacterTags[i]
            : const <DanbooruTag>[];
        if (tags.isEmpty) continue;
        buf.writeln('### 角色 ${i + 1}：${kw.characters[i]}');
        buf.writeln(_formatTagList(tags));
        buf.writeln();
      }
    }

    return buf.toString();
  }

  String _formatTagList(List<DanbooruTag> tags) {
    final lines = <String>[];
    for (final t in tags) {
      final name = t.tag.replaceAll('_', ' '); // 转 NovelAI 风格
      final cn = t.cnName.isNotEmpty ? '（${t.cnName}）' : '';
      final cat = t.category.isNotEmpty ? ' [${t.category}]' : '';
      lines.add('- $name$cn$cat');
    }
    return lines.join('\n');
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
}
