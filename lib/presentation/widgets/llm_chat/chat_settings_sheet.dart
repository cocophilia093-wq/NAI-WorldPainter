import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nai_huishi/core/constants/app_constants.dart';
import 'package:nai_huishi/data/nsfw_book.dart';
import 'package:nai_huishi/domain/usecases/manage_settings.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/presentation/viewmodels/llm_chat_viewmodel.dart';
import 'package:nai_huishi/presentation/widgets/floating_toast.dart';

Future<void> showChatSettingsSheet(
  BuildContext context,
  LlmChatViewModel vm,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ChatSettingsSheet(vm: vm),
  );
}

class _ChatSettingsSheet extends StatefulWidget {
  final LlmChatViewModel vm;
  const _ChatSettingsSheet({required this.vm});

  @override
  State<_ChatSettingsSheet> createState() => _ChatSettingsSheetState();
}

class _ChatSettingsSheetState extends State<_ChatSettingsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final TextEditingController _systemPromptController;
  late final TextEditingController _contextLimitController;
  late final TextEditingController _nsfwBookPathController;
  bool _nsfwBookLoaded = false;
  String _nsfwBookStatus = '';

  // 每个 profile 的 controllers
  late final List<TextEditingController> _nameControllers;
  late final List<TextEditingController> _apiKeyControllers;
  late final List<TextEditingController> _baseUrlControllers;
  late final List<TextEditingController> _modelControllers;

  // 测试连接状态（每个 profile 独立）
  late final List<bool> _isTesting;
  late final List<int?> _latencyMs;
  late final List<String?> _testError;

  @override
  void initState() {
    super.initState();
    final vm = widget.vm;
    _tabController = TabController(
      length: AppConstants.llmProfileCount + 1, // 4 profiles + 通用设置
      vsync: this,
      initialIndex: vm.activeProfileIndex,
    );
    _systemPromptController = TextEditingController(text: vm.systemPrompt);
    _contextLimitController =
        TextEditingController(text: vm.contextLimit.toString());
    _nsfwBookPathController = TextEditingController(text: '');

    _nameControllers = List.generate(
      AppConstants.llmProfileCount,
      (i) => TextEditingController(text: vm.profiles[i].name),
    );
    _apiKeyControllers = List.generate(
      AppConstants.llmProfileCount,
      (i) => TextEditingController(text: vm.profiles[i].apiKey),
    );
    _baseUrlControllers = List.generate(
      AppConstants.llmProfileCount,
      (i) => TextEditingController(text: vm.profiles[i].baseUrl),
    );
    _modelControllers = List.generate(
      AppConstants.llmProfileCount,
      (i) => TextEditingController(text: vm.profiles[i].model),
    );
    _isTesting = List.filled(AppConstants.llmProfileCount, false);
    _latencyMs = List.filled(AppConstants.llmProfileCount, null);
    _testError = List.filled(AppConstants.llmProfileCount, null);

    _loadNsfwBookPath();
  }

  Future<void> _loadNsfwBookPath() async {
    final settings = sl<ManageSettingsUseCase>();
    final path = await settings.getNsfwBookPath();
    if (path != null && path.isNotEmpty) {
      _nsfwBookPathController.text = path;
      final book = NsfwBook();
      final ok = await book.load(path);
      setState(() {
        _nsfwBookLoaded = ok;
        _nsfwBookStatus = ok
            ? '已加载，${book.entryCount} 条知识'
            : '文件不存在或格式错误';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _systemPromptController.dispose();
    _contextLimitController.dispose();
    for (final c in _nameControllers) {
      c.dispose();
    }
    for (final c in _apiKeyControllers) {
      c.dispose();
    }
    for (final c in _baseUrlControllers) {
      c.dispose();
    }
    for (final c in _modelControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final vm = widget.vm;
    // 保存所有 profile
    for (int i = 0; i < AppConstants.llmProfileCount; i++) {
      await vm.saveProfile(
        i,
        name: _nameControllers[i].text.trim().isEmpty
            ? '配置 ${i + 1}'
            : _nameControllers[i].text.trim(),
        apiKey: _apiKeyControllers[i].text.trim(),
        baseUrl: _baseUrlControllers[i].text.trim(),
        model: _modelControllers[i].text.trim(),
      );
    }
    // 保存通用设置
    await vm.setSystemPrompt(_systemPromptController.text.trim());
    final limitVal = int.tryParse(_contextLimitController.text.trim()) ??
        AppConstants.defaultLlmContextLimit;
    await vm.setContextLimit(limitVal);
    // 切换到当前 tab 对应的 profile（如果是 profile tab）
    final tabIdx = _tabController.index;
    if (tabIdx < AppConstants.llmProfileCount) {
      await vm.switchProfile(tabIdx);
    }
    // 保存知识库路径
    final settings = sl<ManageSettingsUseCase>();
    await settings.setNsfwBookPath(
      _nsfwBookPathController.text.trim().isEmpty
          ? null
          : _nsfwBookPathController.text.trim(),
    );
    // 通知 vm 重新加载知识库
    await vm.reloadNsfwBook();
    if (mounted) {
      showFloatingToast(context, '已保存配置', icon: CupertinoIcons.checkmark_circle_fill);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C21),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '提示词辅助配置',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.xmark_circle_fill),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                for (int i = 0; i < AppConstants.llmProfileCount; i++)
                  Tab(text: '配置 ${i + 1}'),
                const Tab(text: '通用'),
              ],
            ),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.55,
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (int i = 0; i < AppConstants.llmProfileCount; i++)
                    _buildProfileTab(i),
                  _buildGeneralTab(),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testProfileConnection(int i) async {
    final url = _baseUrlControllers[i].text.trim();
    final key = _apiKeyControllers[i].text.trim();
    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _testError[i] = 'Base URL 和 API Key 不能为空';
        _latencyMs[i] = null;
      });
      return;
    }
    setState(() {
      _isTesting[i] = true;
      _testError[i] = null;
      _latencyMs[i] = null;
    });
    try {
      final normalizedUrl = url.replaceAll(RegExp(r'/+$'), '').replaceAll(RegExp(r'/v1$'), '');
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 10);
      dio.options.receiveTimeout = const Duration(seconds: 10);
      final sw = Stopwatch()..start();
      await dio.get(
        '$normalizedUrl/v1/models',
        options: Options(headers: {'Authorization': 'Bearer $key'}),
      );
      sw.stop();
      setState(() {
        _latencyMs[i] = sw.elapsedMilliseconds;
        _testError[i] = null;
      });
    } catch (e) {
      if (e is DioException && e.response != null) {
        setState(() {
          _testError[i] = '服务器返回 ${e.response!.statusCode}，但连接成功';
          _latencyMs[i] = null;
        });
      } else {
        setState(() {
          _testError[i] = '连接失败: ${e is DioException ? (e.message ?? e.type.name) : e}';
          _latencyMs[i] = null;
        });
      }
    } finally {
      setState(() => _isTesting[i] = false);
    }
  }

  Widget _buildProfileTab(int i) {
    final isActive = widget.vm.activeProfileIndex == i;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isActive)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.checkmark_circle_fill,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    '当前使用中',
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _nameControllers[i],
            decoration: const InputDecoration(
              labelText: '配置名称',
              hintText: '例如：OpenAI / Gemini / 本地',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _apiKeyControllers[i],
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API Key',
              hintText: '请输入 OpenAI 兼容接口 Key',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _baseUrlControllers[i],
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: '例如 https://api.openai.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelControllers[i],
            decoration: const InputDecoration(
              labelText: '模型名',
              hintText: '例如 gpt-4.1-mini / gemini-2.5-pro',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isTesting[i] ? null : () => _testProfileConnection(i),
            icon: _isTesting[i]
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(CupertinoIcons.wifi, size: 14),
            label: Text(_isTesting[i] ? '测试中…' : '测试连接'),
          ),
          if (_latencyMs[i] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(CupertinoIcons.checkmark_circle_fill,
                    size: 14, color: Colors.greenAccent.shade400),
                const SizedBox(width: 6),
                Text(
                  '连接成功，延迟 ${_latencyMs[i]}ms',
                  style: TextStyle(fontSize: 12, color: Colors.greenAccent.shade400),
                ),
              ],
            ),
          ],
          if (_testError[i] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(CupertinoIcons.exclamationmark_circle_fill,
                    size: 14, color: Colors.orangeAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _testError[i]!,
                    style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
                  ),
                ),
              ],
            ),
          ],
          if (!isActive) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                await widget.vm.switchProfile(i);
                setState(() {});
              },
              icon: const Icon(CupertinoIcons.arrow_right_circle, size: 16),
              label: const Text('切换到此配置'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('上下文条数',
                    style: TextStyle(fontSize: 14, color: Colors.white70)),
              ),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _contextLimitController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '20',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text('条', style: TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '发送时携带的历史消息数量（不含系统提示词），越大消耗 token 越多',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _systemPromptController,
            minLines: 6,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: '系统提示词',
              hintText: '可自由编辑默认系统提示词',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _systemPromptController.text =
                  AppConstants.defaultLlmSystemPrompt;
            },
            child: const Text('恢复默认系统提示词'),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          const Text('知识库（世界书）',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            '知识库 JSON 文件路径，输入后保存自动加载。'
            '关键词匹配的知识会随每次提问注入给 LLM。',
            style: TextStyle(fontSize: 11, color: Colors.white38),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nsfwBookPathController,
            decoration: const InputDecoration(
              labelText: '知识库路径',
              hintText: '例如 /storage/emulated/0/nsfw_knowledge.json',
            ),
          ),
          const SizedBox(height: 8),
          if (_nsfwBookStatus.isNotEmpty)
            Row(
              children: [
                Icon(
                  _nsfwBookLoaded
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.exclamationmark_triangle_fill,
                  size: 14,
                  color: _nsfwBookLoaded ? Colors.greenAccent.shade400 : Colors.orangeAccent,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _nsfwBookStatus,
                    style: TextStyle(
                      fontSize: 12,
                      color: _nsfwBookLoaded ? Colors.greenAccent.shade400 : Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
