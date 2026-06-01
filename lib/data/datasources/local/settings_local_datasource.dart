import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:nai_huishi/core/constants/app_constants.dart';
import 'package:nai_huishi/core/constants/api_constants.dart';
import 'package:nai_huishi/domain/entities/api_endpoint.dart';
import 'package:nai_huishi/domain/entities/generation_task.dart';

class SettingsLocalDatasource {
  final SharedPreferences _prefs;

  SettingsLocalDatasource(this._prefs);

  // API Key
  Future<String?> getApiKey() async => _prefs.getString(AppConstants.keyApiKey);
  Future<void> setApiKey(String key) async => _prefs.setString(AppConstants.keyApiKey, key);
  Future<void> deleteApiKey() async => _prefs.remove(AppConstants.keyApiKey);

  // Base URL
  String getBaseUrl() => _prefs.getString(AppConstants.keyBaseUrl) ?? ApiConstants.defaultBaseUrl;
  Future<void> setBaseUrl(String url) async => _prefs.setString(AppConstants.keyBaseUrl, url);

  // Default Model
  Future<String?> getDefaultModel() async => _prefs.getString(AppConstants.keyDefaultModel);
  Future<void> setDefaultModel(String model) async => _prefs.setString(AppConstants.keyDefaultModel, model);

  // Default Resolution
  String getDefaultResolution() => _prefs.getString(AppConstants.keyDefaultResolution) ?? ApiConstants.defaultResolution;
  Future<void> setDefaultResolution(String r) async => _prefs.setString(AppConstants.keyDefaultResolution, r);

  // Default Sampler
  String getDefaultSampler() => _prefs.getString(AppConstants.keyDefaultSampler) ?? ApiConstants.defaultSampler;
  Future<void> setDefaultSampler(String s) async => _prefs.setString(AppConstants.keyDefaultSampler, s);

  // Default Scale
  double getDefaultScale() => _prefs.getDouble(AppConstants.keyDefaultScale) ?? ApiConstants.defaultScale;
  Future<void> setDefaultScale(double s) async => _prefs.setDouble(AppConstants.keyDefaultScale, s);

  // Default CFG Rescale
  double getDefaultCfgRescale() => _prefs.getDouble(AppConstants.keyDefaultCfgRescale) ?? ApiConstants.defaultCfgRescale;
  Future<void> setDefaultCfgRescale(double v) async => _prefs.setDouble(AppConstants.keyDefaultCfgRescale, v);

  // Default Noise Schedule
  String getDefaultNoiseSchedule() => _prefs.getString(AppConstants.keyDefaultNoiseSchedule) ?? ApiConstants.defaultNoiseSchedule;
  Future<void> setDefaultNoiseSchedule(String s) async => _prefs.setString(AppConstants.keyDefaultNoiseSchedule, s);

  // Prompt Draft
  String getPromptDraft() => _prefs.getString(AppConstants.keyPromptDraft) ?? '';
  Future<void> setPromptDraft(String value) async => _prefs.setString(AppConstants.keyPromptDraft, value);

  // Negative Prompt Draft
  String getNegativePromptDraft() => _prefs.getString(AppConstants.keyNegativePromptDraft) ?? '';
  Future<void> setNegativePromptDraft(String value) async => _prefs.setString(AppConstants.keyNegativePromptDraft, value);

  String? getSelectedModelDraft() => _prefs.getString(AppConstants.keySelectedModelDraft);
  Future<void> setSelectedModelDraft(String value) async => _prefs.setString(AppConstants.keySelectedModelDraft, value);

  String getSelectedResolutionDraft() => _prefs.getString(AppConstants.keySelectedResolutionDraft) ?? ApiConstants.defaultResolution;
  Future<void> setSelectedResolutionDraft(String value) async => _prefs.setString(AppConstants.keySelectedResolutionDraft, value);

  String getSelectedSamplerDraft() => _prefs.getString(AppConstants.keySelectedSamplerDraft) ?? ApiConstants.defaultSampler;
  Future<void> setSelectedSamplerDraft(String value) async => _prefs.setString(AppConstants.keySelectedSamplerDraft, value);

  String getSelectedNoiseScheduleDraft() => _prefs.getString(AppConstants.keySelectedNoiseScheduleDraft) ?? ApiConstants.defaultNoiseSchedule;
  Future<void> setSelectedNoiseScheduleDraft(String value) async => _prefs.setString(AppConstants.keySelectedNoiseScheduleDraft, value);

  double getScaleDraft() => _prefs.getDouble(AppConstants.keyScaleDraft) ?? ApiConstants.defaultScale;
  Future<void> setScaleDraft(double value) async => _prefs.setDouble(AppConstants.keyScaleDraft, value);

  double getCfgRescaleDraft() => _prefs.getDouble(AppConstants.keyCfgRescaleDraft) ?? ApiConstants.defaultCfgRescale;
  Future<void> setCfgRescaleDraft(double value) async => _prefs.setDouble(AppConstants.keyCfgRescaleDraft, value);

  List<CharacterSpec> getCharactersDraft() {
    final raw = _prefs.getString(AppConstants.keyCharactersDraft);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => CharacterSpec.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setCharactersDraft(List<CharacterSpec> value) async {
    await _prefs.setString(
      AppConstants.keyCharactersDraft,
      jsonEncode(value.map((c) => c.toJson()).toList()),
    );
  }

  // Inpaint Prompt Draft
  String getInpaintPromptDraft() => _prefs.getString(AppConstants.keyInpaintPromptDraft) ?? '';
  Future<void> setInpaintPromptDraft(String value) async => _prefs.setString(AppConstants.keyInpaintPromptDraft, value);

  // Inpaint Negative Prompt Draft
  String getInpaintNegativePromptDraft() => _prefs.getString(AppConstants.keyInpaintNegativePromptDraft) ?? '';
  Future<void> setInpaintNegativePromptDraft(String value) async => _prefs.setString(AppConstants.keyInpaintNegativePromptDraft, value);

  // LLM 配置
  String? getLlmApiKey() => _prefs.getString(AppConstants.keyLlmApiKey);
  Future<void> setLlmApiKey(String value) async => _prefs.setString(AppConstants.keyLlmApiKey, value);

  String getLlmBaseUrl() => _prefs.getString(AppConstants.keyLlmBaseUrl) ?? '';
  Future<void> setLlmBaseUrl(String value) async => _prefs.setString(AppConstants.keyLlmBaseUrl, value);

  String getLlmModel() => _prefs.getString(AppConstants.keyLlmModel) ?? '';
  Future<void> setLlmModel(String value) async => _prefs.setString(AppConstants.keyLlmModel, value);

  String getLlmSystemPrompt() =>
      _prefs.getString(AppConstants.keyLlmSystemPrompt) ?? AppConstants.defaultLlmSystemPrompt;
  Future<void> setLlmSystemPrompt(String value) async => _prefs.setString(AppConstants.keyLlmSystemPrompt, value);

  String? getLlmActiveSessionId() => _prefs.getString(AppConstants.keyLlmActiveSessionId);
  Future<void> setLlmActiveSessionId(String? value) async {
    if (value == null) {
      await _prefs.remove(AppConstants.keyLlmActiveSessionId);
    } else {
      await _prefs.setString(AppConstants.keyLlmActiveSessionId, value);
    }
  }

  // LLM 多配置位
  int getLlmActiveProfile() => _prefs.getInt(AppConstants.keyLlmActiveProfile) ?? 0;
  Future<void> setLlmActiveProfile(int index) async => _prefs.setInt(AppConstants.keyLlmActiveProfile, index);

  int getLlmContextLimit() => _prefs.getInt(AppConstants.keyLlmContextLimit) ?? AppConstants.defaultLlmContextLimit;
  Future<void> setLlmContextLimit(int value) async => _prefs.setInt(AppConstants.keyLlmContextLimit, value);

  String? getLlmProfileApiKey(int i) => _prefs.getString(AppConstants.keyLlmProfileApiKey(i));
  Future<void> setLlmProfileApiKey(int i, String value) async =>
      _prefs.setString(AppConstants.keyLlmProfileApiKey(i), value);

  String getLlmProfileBaseUrl(int i) => _prefs.getString(AppConstants.keyLlmProfileBaseUrl(i)) ?? '';
  Future<void> setLlmProfileBaseUrl(int i, String value) async =>
      _prefs.setString(AppConstants.keyLlmProfileBaseUrl(i), value);

  String getLlmProfileModel(int i) => _prefs.getString(AppConstants.keyLlmProfileModel(i)) ?? '';
  Future<void> setLlmProfileModel(int i, String value) async =>
      _prefs.setString(AppConstants.keyLlmProfileModel(i), value);

  String getLlmProfileName(int i) =>
      _prefs.getString(AppConstants.keyLlmProfileName(i)) ?? '配置 ${i + 1}';
  Future<void> setLlmProfileName(int i, String value) async =>
      _prefs.setString(AppConstants.keyLlmProfileName(i), value);

  // 知识库
  String? getNsfwBookPath() => _prefs.getString(AppConstants.keyNsfwBookPath);
  Future<void> setNsfwBookPath(String? value) async {
    if (value == null || value.isEmpty) {
      await _prefs.remove(AppConstants.keyNsfwBookPath);
    } else {
      await _prefs.setString(AppConstants.keyNsfwBookPath, value);
    }
  }

  // 联网搜索开关（持久化，避免每次离开聊天关闭）
  bool getWebSearchEnabled() =>
      _prefs.getBool(AppConstants.keyWebSearchEnabled) ?? false;
  Future<void> setWebSearchEnabled(bool value) async =>
      _prefs.setBool(AppConstants.keyWebSearchEnabled, value);

  // 图像 API 供应商配置 — NovelAI
  String getImageProviderNovelAiBaseUrl() =>
      _prefs.getString(AppConstants.keyImageProviderNovelAiBaseUrl) ?? '';
  Future<void> setImageProviderNovelAiBaseUrl(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderNovelAiBaseUrl, value);

  String? getImageProviderNovelAiApiKey() =>
      _prefs.getString(AppConstants.keyImageProviderNovelAiApiKey);
  Future<void> setImageProviderNovelAiApiKey(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderNovelAiApiKey, value);

  String getImageProviderNovelAiModel() =>
      _prefs.getString(AppConstants.keyImageProviderNovelAiModel) ?? '';
  Future<void> setImageProviderNovelAiModel(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderNovelAiModel, value);

  // 图像 API 供应商配置 — GPT
  String getImageProviderGptBaseUrl() =>
      _prefs.getString(AppConstants.keyImageProviderGptBaseUrl) ?? '';
  Future<void> setImageProviderGptBaseUrl(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderGptBaseUrl, value);

  String? getImageProviderGptApiKey() =>
      _prefs.getString(AppConstants.keyImageProviderGptApiKey);
  Future<void> setImageProviderGptApiKey(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderGptApiKey, value);

  String getImageProviderGptModel() =>
      _prefs.getString(AppConstants.keyImageProviderGptModel) ?? '';
  Future<void> setImageProviderGptModel(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderGptModel, value);

  // 图像 API 供应商配置 — Nano Banana
  String getImageProviderNanoBaseUrl() =>
      _prefs.getString(AppConstants.keyImageProviderNanoBaseUrl) ?? '';
  Future<void> setImageProviderNanoBaseUrl(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderNanoBaseUrl, value);

  String? getImageProviderNanoApiKey() =>
      _prefs.getString(AppConstants.keyImageProviderNanoApiKey);
  Future<void> setImageProviderNanoApiKey(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderNanoApiKey, value);

  String getImageProviderNanoModel() =>
      _prefs.getString(AppConstants.keyImageProviderNanoModel) ?? '';
  Future<void> setImageProviderNanoModel(String value) async =>
      _prefs.setString(AppConstants.keyImageProviderNanoModel, value);

  // ===== 图像 API 供应商 v2 多中转站结构 =====
  ({String endpoints, String activeId, String activeModel}) _keysFor(ImageProviderType p) {
    switch (p) {
      case ImageProviderType.novelAi:
        return (
          endpoints: AppConstants.keyImageProviderNovelAiEndpoints,
          activeId: AppConstants.keyImageProviderNovelAiActiveEndpointId,
          activeModel: AppConstants.keyImageProviderNovelAiActiveModel,
        );
      case ImageProviderType.gpt:
        return (
          endpoints: AppConstants.keyImageProviderGptEndpoints,
          activeId: AppConstants.keyImageProviderGptActiveEndpointId,
          activeModel: AppConstants.keyImageProviderGptActiveModel,
        );
      case ImageProviderType.nanoBanana:
        return (
          endpoints: AppConstants.keyImageProviderNanoEndpoints,
          activeId: AppConstants.keyImageProviderNanoActiveEndpointId,
          activeModel: AppConstants.keyImageProviderNanoActiveModel,
        );
    }
  }

  /// 读取某个 provider 的中转站列表。
  /// 若新结构为空且旧 v1 单值有内容，则自动迁移：构造一条「默认」中转站并写回。
  List<ApiEndpoint> getEndpoints(ImageProviderType p) {
    final keys = _keysFor(p);
    final raw = _prefs.getString(keys.endpoints);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) => ApiEndpoint.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return [];
      }
    }
    // 自动迁移
    final migrated = _migrateLegacy(p);
    if (migrated != null) {
      _prefs.setString(keys.endpoints, jsonEncode([migrated.toJson()]));
      _prefs.setString(keys.activeId, migrated.id);
      if (migrated.models.isNotEmpty) {
        _prefs.setString(keys.activeModel, migrated.models.first);
      }
      return [migrated];
    }
    return [];
  }

  ApiEndpoint? _migrateLegacy(ImageProviderType p) {
    String oldUrl;
    String? oldKey;
    String oldModel;
    switch (p) {
      case ImageProviderType.novelAi:
        oldUrl = getImageProviderNovelAiBaseUrl();
        oldKey = getImageProviderNovelAiApiKey();
        oldModel = getImageProviderNovelAiModel();
        break;
      case ImageProviderType.gpt:
        oldUrl = getImageProviderGptBaseUrl();
        oldKey = getImageProviderGptApiKey();
        oldModel = getImageProviderGptModel();
        break;
      case ImageProviderType.nanoBanana:
        oldUrl = getImageProviderNanoBaseUrl();
        oldKey = getImageProviderNanoApiKey();
        oldModel = getImageProviderNanoModel();
        break;
    }
    if (oldUrl.isEmpty && (oldKey == null || oldKey.isEmpty) && oldModel.isEmpty) {
      return null;
    }
    return ApiEndpoint(
      id: 'legacy_${p.name}_${DateTime.now().millisecondsSinceEpoch}',
      name: '默认',
      baseUrl: oldUrl,
      apiKey: oldKey ?? '',
      models: oldModel.isEmpty ? const [] : [oldModel],
    );
  }

  Future<void> setEndpoints(ImageProviderType p, List<ApiEndpoint> list) async {
    final keys = _keysFor(p);
    await _prefs.setString(
      keys.endpoints,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  String? getActiveEndpointId(ImageProviderType p) =>
      _prefs.getString(_keysFor(p).activeId);
  Future<void> setActiveEndpointId(ImageProviderType p, String? id) async {
    final key = _keysFor(p).activeId;
    if (id == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, id);
    }
  }

  String? getActiveModel(ImageProviderType p) =>
      _prefs.getString(_keysFor(p).activeModel);
  Future<void> setActiveModel(ImageProviderType p, String? model) async {
    final key = _keysFor(p).activeModel;
    if (model == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, model);
    }
  }

  /// 取当前 active 中转站；若没有 active，回退到列表第一个；都没有返回 null
  ApiEndpoint? getActiveEndpoint(ImageProviderType p) {
    final list = getEndpoints(p);
    if (list.isEmpty) return null;
    final activeId = getActiveEndpointId(p);
    if (activeId != null) {
      try {
        return list.firstWhere((e) => e.id == activeId);
      } catch (_) {/* fall through */}
    }
    return list.first;
  }

  // 批量生成数量
  int getBatchCount() => _prefs.getInt(AppConstants.keyBatchCount) ?? 1;
  Future<void> setBatchCount(int value) async {
    final clamped = value.clamp(1, 15);
    await _prefs.setInt(AppConstants.keyBatchCount, clamped);
  }
}
