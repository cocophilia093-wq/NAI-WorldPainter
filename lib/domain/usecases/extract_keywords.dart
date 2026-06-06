import 'dart:convert';

import 'package:nai_huishi/core/constants/app_constants.dart';
import 'package:nai_huishi/data/datasources/remote/llm_api_service.dart';

/// 关键词抽取结果。
///
/// 由便宜小模型从用户原文中切出的"用于 Danbooru 检索的种子词"。
/// - characters：每条对应一个角色（多角色时分开列出）
/// - scene：环境/动作/表情/互动
/// - style：画风/构图/镜头/光影
/// - nsfw：NSFW 关键词，无则空数组
class ExtractedKeywords {
  final List<String> characters;
  final List<String> scene;
  final List<String> style;
  final List<String> nsfw;

  const ExtractedKeywords({
    required this.characters,
    required this.scene,
    required this.style,
    required this.nsfw,
  });

  bool get isEmpty =>
      characters.isEmpty && scene.isEmpty && style.isEmpty && nsfw.isEmpty;
}

/// 关键词抽取 UseCase。
///
/// 调一次便宜的小模型，让它把用户原文拆成 JSON 形式的种子词。
/// 系统提示词使用 [AppConstants.builtinExtractSystemPrompt]（内置，用户不可改）。
class ExtractKeywordsUseCase {
  final LlmApiService _api;

  ExtractKeywordsUseCase(this._api);

  Future<ExtractedKeywords> call({
    required String userText,
    required String apiKey,
    required String baseUrl,
    required String model,
  }) async {
    final reply = await _api.chatCompletions(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      messages: [
        {'role': 'system', 'content': AppConstants.builtinExtractSystemPrompt},
        {'role': 'user', 'content': userText},
      ],
    );
    return _parse(reply, fallbackText: userText);
  }

  /// 解析 LLM 返回的 JSON。容错策略：
  ///   1. 直接尝试 jsonDecode；
  ///   2. 失败则从文本中提取首个 `{...}` 子串再解析；
  ///   3. 全部失败时退化为 `characters=[fallbackText]`，避免完全不可用。
  ExtractedKeywords _parse(String reply, {required String fallbackText}) {
    final cleaned = _stripCodeFence(reply.trim());
    Map<String, dynamic>? obj = _tryDecode(cleaned);
    if (obj == null) {
      final jsonSub = _extractJsonObject(cleaned);
      if (jsonSub != null) obj = _tryDecode(jsonSub);
    }
    if (obj == null) {
      return ExtractedKeywords(
        characters: [fallbackText.trim()],
        scene: const [],
        style: const [],
        nsfw: const [],
      );
    }
    return ExtractedKeywords(
      characters: _toStringList(obj['characters']),
      scene: _toStringList(obj['scene']),
      style: _toStringList(obj['style']),
      nsfw: _toStringList(obj['nsfw']),
    );
  }

  /// 去掉 ```json ... ``` 这种 markdown 包裹（若小模型不听话）。
  String _stripCodeFence(String s) {
    var t = s;
    if (t.startsWith('```')) {
      final firstNl = t.indexOf('\n');
      if (firstNl >= 0) t = t.substring(firstNl + 1);
      if (t.endsWith('```')) t = t.substring(0, t.length - 3);
    }
    return t.trim();
  }

  Map<String, dynamic>? _tryDecode(String s) {
    try {
      final v = jsonDecode(s);
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
    } catch (_) {}
    return null;
  }

  /// 从含杂质的文本中提取首个完整的 `{...}` 子串（按括号深度匹配）。
  String? _extractJsonObject(String s) {
    final start = s.indexOf('{');
    if (start < 0) return null;
    int depth = 0;
    for (int i = start; i < s.length; i++) {
      final ch = s[i];
      if (ch == '{') depth++;
      if (ch == '}') {
        depth--;
        if (depth == 0) return s.substring(start, i + 1);
      }
    }
    return null;
  }

  List<String> _toStringList(dynamic v) {
    if (v is! List) return const [];
    final out = <String>[];
    for (final e in v) {
      if (e == null) continue;
      final s = e.toString().trim();
      if (s.isNotEmpty) out.add(s);
    }
    return out;
  }
}
