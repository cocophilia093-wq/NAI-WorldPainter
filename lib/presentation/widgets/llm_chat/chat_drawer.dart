import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/domain/entities/llm_message.dart';
import 'package:nai_huishi/presentation/pages/prompt_memory_page.dart';
import 'package:nai_huishi/presentation/pages/style_preset_page.dart';
import 'package:nai_huishi/presentation/viewmodels/llm_chat_viewmodel.dart';
import 'package:nai_huishi/presentation/widgets/llm_chat/chat_input_bar.dart';
import 'package:nai_huishi/presentation/widgets/llm_chat/chat_message_bubble.dart';
import 'package:nai_huishi/presentation/widgets/llm_chat/prompt_apply_parser.dart';
import 'package:nai_huishi/presentation/widgets/llm_chat/chat_sessions_panel.dart';
import 'package:nai_huishi/presentation/widgets/llm_chat/chat_settings_sheet.dart';

class ChatDrawer extends StatefulWidget {
  final VoidCallback onClose;
  final void Function(String text, bool replace, String? label) onApplyPrompt;
  final void Function(String text, bool replace, String? label) onApplyNegative;
  final void Function(AppliedSegments aggregated)? onApplyAll;

  const ChatDrawer({
    super.key,
    required this.onClose,
    required this.onApplyPrompt,
    required this.onApplyNegative,
    this.onApplyAll,
  });

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  late final LlmChatViewModel _vm;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _vm = sl<LlmChatViewModel>();
    _vm.addListener(_onVmChanged);
    _init();
  }

  Future<void> _init() async {
    await _vm.ensureInitialized();
    if (!mounted) return;
    setState(() => _ready = true);
    _jumpToBottom();
  }

  void _onVmChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _jumpToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _openSessions() async {
    await showChatSessionsPanel(context, vm: _vm);
  }

  void _insertIntoInput(String text) {
    final current = _inputController.text.trim();
    _inputController.text = current.isEmpty ? text : '$current, $text';
    _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
  }

  Future<void> _openStylePresets() async {
    await Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => StylePresetPage(onApplyPrompt: _insertIntoInput),
      ),
    );
  }

  Future<void> _openMemories() async {
    await Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const PromptMemoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width * 0.85;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose,
            child: Container(color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.38)),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          bottom: 0,
          width: width,
          child: AnimatedSlide(
            offset: Offset.zero,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                bottomLeft: Radius.circular(28),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF14141A).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.94),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      bottomLeft: Radius.circular(28),
                    ),
                  ),
                  child: SafeArea(
                    left: false,
                    child: Column(
                      children: [
                        _buildTopBar(),
                        Expanded(
                          child: !_ready || _vm.isLoading
                              ? Center(child: CircularProgressIndicator())
                              : _buildMessageList(),
                        ),
                        if (_vm.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.withValues(alpha: 0.24)),
                              ),
                              child: Row(
                                children: [
                                  Icon(CupertinoIcons.exclamationmark_triangle, size: 16, color: Colors.redAccent),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _vm.errorMessage!,
                                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _vm.clearError,
                                    child: Icon(CupertinoIcons.xmark, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ChatInputBar(
                          controller: _inputController,
                          isSending: _vm.isSending,
                          danbooruSearchEnabled: _vm.danbooruSearchEnabled,
                          onToggleDanbooruSearch: _vm.toggleDanbooruSearch,
                          onSend: (text, {String? imageBase64}) =>
                              _vm.sendUserMessage(text, imageBase64: imageBase64),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _openSessions,
            tooltip: '会话列表',
            icon: Icon(CupertinoIcons.list_bullet, color: Theme.of(context).colorScheme.onSurface),
          ),
          IconButton(
            onPressed: _openStylePresets,
            tooltip: '画风收藏',
            icon: Icon(CupertinoIcons.square_grid_2x2, color: Theme.of(context).colorScheme.onSurface),
          ),
          IconButton(
            onPressed: _openMemories,
            tooltip: '学习记忆',
            icon: Icon(CupertinoIcons.book, color: Theme.of(context).colorScheme.onSurface),
          ),
          const Spacer(),
          IconButton(
            onPressed: _vm.createNewSession,
            tooltip: '新建会话',
            icon: Icon(CupertinoIcons.square_pencil, color: Theme.of(context).colorScheme.onSurface),
          ),
          IconButton(
            onPressed: () => showChatSettingsSheet(context, _vm),
            tooltip: '配置',
            icon: Icon(CupertinoIcons.gear_alt, color: Theme.of(context).colorScheme.onSurface),
          ),
          IconButton(
            onPressed: widget.onClose,
            tooltip: '关闭',
            icon: Icon(CupertinoIcons.xmark_circle_fill, color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_vm.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.wand_stars, size: 34, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              SizedBox(height: 12),
              Text(
                '描述你想生成的画面，我来帮你整理成提示词。\n建议让模型按正向/负向两个代码块输出。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.6, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      itemCount: _vm.messages.length,
      itemBuilder: (context, index) {
        final message = _vm.messages[index];
        return ChatMessageBubble(
          message: message,
          messageIndex: index,
          onApplyPrompt: widget.onApplyPrompt,
          onApplyNegative: widget.onApplyNegative,
          onApplyAll: widget.onApplyAll,
          onRetry: message.role == LlmMessageRole.user
              ? () => _vm.retryFromIndex(index)
              : null,
          onEditAndResend: message.role == LlmMessageRole.user
              ? (newText) => _vm.editAndResend(index, newText)
              : null,
        );
      },
    );
  }
}
