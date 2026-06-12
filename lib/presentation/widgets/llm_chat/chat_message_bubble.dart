import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_huishi/domain/entities/llm_message.dart';
import 'package:nai_huishi/presentation/widgets/llm_chat/prompt_apply_parser.dart';

class ChatMessageBubble extends StatelessWidget {
  final LlmMessage message;
  final int messageIndex;
  final void Function(String text, bool replace, String? label) onApplyPrompt;
  final void Function(String text, bool replace, String? label) onApplyNegative;
  final void Function(AppliedSegments aggregated)? onApplyAll;
  final VoidCallback? onRetry;
  final void Function(String newText)? onEditAndResend;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.messageIndex,
    required this.onApplyPrompt,
    required this.onApplyNegative,
    this.onApplyAll,
    this.onRetry,
    this.onEditAndResend,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == LlmMessageRole.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final segments = splitPromptContent(message.content);
    final aggregated = isUser ? null : parseAppliedSegments(message.content);
    final showApplyAll = !isUser &&
        onApplyAll != null &&
        aggregated != null &&
        !aggregated.isEmpty;
    // 占位消息：纯 pipeline 状态，无正文
    final isPlaceholder = !isUser &&
        message.content.trim().isEmpty &&
        message.pipelineStage != null;

    Widget bubble = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? theme.colorScheme.primary
                          .withValues(alpha: isDark ? 0.18 : 0.14)
                      : isDark
                          ? const Color(0xFF1C1C21).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (message.imageBase64 != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            base64Decode(message.imageBase64!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    if (!isPlaceholder)
                      for (final seg in segments)
                        if (seg.isCode)
                          _CodeBlock(
                            text: seg.text,
                            lang: seg.lang,
                            label: seg.label,
                            showApplyButtons: !isUser,
                            onApplyPrompt: onApplyPrompt,
                            onApplyNegative: onApplyNegative,
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: isUser
                                ? Text(
                                    seg.text.trim(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  )
                                : SelectableText(
                                    seg.text.trim(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                          ),
                    if (showApplyAll && !isPlaceholder)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ApplyAllButton(
                          aggregated: aggregated,
                          onApplyAll: onApplyAll!,
                        ),
                      ),
                    if (!isUser &&
                        message.pipelineStatus != null &&
                        message.pipelineStatus!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: isPlaceholder ? 0 : 6),
                        child: _PipelineStatusLine(
                          text: message.pipelineStatus!,
                          stage: message.pipelineStage,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isUser && (onRetry != null || onEditAndResend != null)) {
      bubble = GestureDetector(
        onLongPress: () => _showUserMessageMenu(context),
        child: bubble,
      );
    }

    return bubble;
  }

  void _showUserMessageMenu(BuildContext context) {
    final menuItems = <PopupMenuEntry<String>>[
      if (onRetry != null)
        const PopupMenuItem(value: 'retry', child: Text('重试')),
      if (onEditAndResend != null)
        const PopupMenuItem(value: 'edit', child: Text('编辑')),
      const PopupMenuItem(value: 'copy', child: Text('复制')),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fill,
      items: menuItems,
    ).then((value) {
      if (!context.mounted) return;
      if (value == 'retry' && onRetry != null) {
        onRetry!();
      } else if (value == 'edit' && onEditAndResend != null) {
        _showEditDialog(context);
      } else if (value == 'copy') {
        Clipboard.setData(ClipboardData(
            text: message.content.replaceAll(RegExp(r'\n\[图片\]$'), '')));
      }
    });
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(
      text: message.content.replaceAll(RegExp(r'\n\[图片\]$'), ''),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑消息'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 1,
          autofocus: true,
          style: TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '修改消息内容…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onEditAndResend?.call(controller.text.trim());
            },
            child: Text('发送'),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String text;
  final String lang;
  final String label;
  final bool showApplyButtons;
  final void Function(String text, bool replace, String? label) onApplyPrompt;
  final void Function(String text, bool replace, String? label) onApplyNegative;

  const _CodeBlock({
    required this.text,
    required this.lang,
    required this.label,
    required this.showApplyButtons,
    required this.onApplyPrompt,
    required this.onApplyNegative,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.45)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lang.isNotEmpty || label.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.04),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Text(
                label.isNotEmpty
                    ? (lang.isNotEmpty
                        ? '$label · ${lang.toLowerCase()}'
                        : label)
                    : lang.toLowerCase(),
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SelectableText(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Theme.of(context).colorScheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (showApplyButtons)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.03),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MiniBtn(
                    icon: CupertinoIcons.plus_circle,
                    label: '追加正向',
                    onTap: () => onApplyPrompt(text, false, label),
                    feedback: '已追加正向',
                  ),
                  _MiniBtn(
                    icon: CupertinoIcons.plus_circle,
                    label: '追加负向',
                    onTap: () => onApplyNegative(text, false, label),
                    feedback: '已追加负向',
                  ),
                  _MiniBtn(
                    icon: CupertinoIcons.arrow_2_squarepath,
                    label: '替换正向',
                    onTap: () => onApplyPrompt(text, true, label),
                    feedback: '已替换正向',
                  ),
                  _MiniBtn(
                    icon: CupertinoIcons.arrow_2_squarepath,
                    label: '替换负向',
                    onTap: () => onApplyNegative(text, true, label),
                    feedback: '已替换负向',
                  ),
                  _MiniBtn(
                    icon: CupertinoIcons.doc_on_doc,
                    label: '复制',
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                    },
                    feedback: '已复制',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String feedback;

  const _MiniBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.feedback,
  });

  @override
  State<_MiniBtn> createState() => _MiniBtnState();
}

class _MiniBtnState extends State<_MiniBtn> {
  OverlayEntry? _overlayEntry;

  void _showFeedback() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.96);
    final borderColor =
        theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.10 : 0.12);
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx,
        top: offset.dy - 28,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Text(
              widget.feedback,
              style: TextStyle(fontSize: 11, color: textColor),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_overlayEntry!);
    Future.delayed(const Duration(milliseconds: 800), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
        _showFeedback();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon,
                size: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(width: 4),
            Text(widget.label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _ApplyAllButton extends StatelessWidget {
  final AppliedSegments aggregated;
  final void Function(AppliedSegments aggregated) onApplyAll;

  const _ApplyAllButton({required this.aggregated, required this.onApplyAll});

  String _summary() {
    final parts = <String>[];
    if (aggregated.positive != null && aggregated.positive!.isNotEmpty) {
      parts.add('正向');
    }
    if (aggregated.negative != null && aggregated.negative!.isNotEmpty) {
      parts.add('负向');
    }
    final charCount =
        aggregated.characterPrompts.where((p) => p.trim().isNotEmpty).length;
    if (charCount > 0) parts.add('$charCount 个角色');
    return parts.isEmpty ? '' : '（${parts.join(' · ')}）';
  }

  /// 检查解析结果是否看起来不完整（可能模型输出格式不对）
  bool get _looksIncomplete {
    // 正向和负向都为空，但有角色块 → 可能缺少通用底模词
    if ((aggregated.positive == null || aggregated.positive!.isEmpty) &&
        (aggregated.negative == null || aggregated.negative!.isEmpty) &&
        aggregated.characterPrompts.isNotEmpty) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary();
    final disabled = _looksIncomplete;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: disabled ? null : () async {
        HapticFeedback.mediumImpact();
        final confirmed = await _showPreviewDialog(context);
        if (confirmed == true) onApplyAll(aggregated);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: disabled ? null : LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.32),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            ],
          ),
          color: disabled ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.wand_stars,
                size: 16,
                color: disabled
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.onSurface),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                disabled ? '解析不完整，请手动应用' : '一键替换全部$summary',
                style: TextStyle(
                  fontSize: 13,
                  color: disabled
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showPreviewDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1C1C21) : Colors.white;

    Widget section(String title, String content) {
      if (content.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary)),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(content,
                style: TextStyle(fontSize: 12, height: 1.4, fontFamily: 'monospace',
                    color: theme.colorScheme.onSurface)),
          ),
          SizedBox(height: 10),
        ],
      );
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('确认替换'),
        backgroundColor: bgColor,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '以下内容将替换当前所有提示词，无法撤销：',
                style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
              SizedBox(height: 12),
              section('正向', aggregated.positive ?? ''),
              for (int i = 0; i < aggregated.characterPrompts.length; i++) ...[
                if (aggregated.characterPrompts[i].isNotEmpty)
                  section('角色${i + 1}', aggregated.characterPrompts[i]),
                if (aggregated.characterNegatives.isNotEmpty &&
                    i < aggregated.characterNegatives.length &&
                    aggregated.characterNegatives[i].isNotEmpty)
                  section('角色${i + 1} 负向', aggregated.characterNegatives[i]),
              ],
              section('负向', aggregated.negative ?? ''),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认替换'),
          ),
        ],
      ),
    );
  }
}

/// Danbooru 三段式流程状态条：根据 pipelineStage 显示不同图标 + 颜色。
///   extracting / searching / composing → 蓝色 spinner
///   done → 绿色 ✓
///   fallback → 灰色感叹号
class _PipelineStatusLine extends StatelessWidget {
  final String text;
  final String? stage;
  const _PipelineStatusLine({required this.text, required this.stage});

  bool get _isPending =>
      stage == 'extracting' || stage == 'searching' || stage == 'composing';
  bool get _isDone => stage == 'done';

  @override
  Widget build(BuildContext context) {
    final Color color;
    final Widget leading;
    if (_isPending) {
      color = const Color(0xFF7AB8F5);
      leading = SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    } else if (_isDone) {
      color = Colors.greenAccent.shade400;
      leading =
          Icon(CupertinoIcons.checkmark_seal_fill, size: 12, color: color);
    } else {
      // fallback / unknown
      color = Theme.of(context)
          .colorScheme
          .onSurfaceVariant
          .withValues(alpha: 0.55);
      leading =
          Icon(CupertinoIcons.exclamationmark_circle, size: 12, color: color);
    }
    return Row(
      children: [
        leading,
        SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ),
      ],
    );
  }
}
