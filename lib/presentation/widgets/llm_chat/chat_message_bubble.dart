import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_huishi/domain/entities/llm_message.dart';

/// AI 回复中匹配 fenced code block：```lang\n...\n```
final _codeBlockRegex = RegExp(r'```([a-zA-Z0-9_+\-]*)\s*\n([\s\S]*?)```');

class _Segment {
  final bool isCode;
  final String text;
  final String lang;
  /// 代码块前的标注文字（如"正向"、"负向"、"通用底模词"、"角色1"等）
  final String label;
  const _Segment.text(this.text)
      : isCode = false,
        lang = '',
        label = '';
  const _Segment.code(this.text, this.lang, this.label) : isCode = true;
}

/// 判断标注是否为角色标签
bool _isCharacterLabel(String label) {
  if (label.isEmpty) return false;
  // "角色1"、"角色2" 等
  if (label.contains('角色')) return true;
  return false;
}

/// 判断标注是否为负向标签
bool _isNegativeLabel(String label) {
  if (label.isEmpty) return false;
  return label.contains('负向') || label.contains('负面');
}

/// 判断标注是否为正向（"通用底模词" / "正向" / "通用正向" 等都视为全局正向）
bool _isPositiveLabel(String label) {
  if (label.isEmpty) return false;
  if (_isNegativeLabel(label)) return false;
  if (_isCharacterLabel(label)) return false;
  return label.contains('正向') ||
      label.contains('正面') ||
      label.contains('底模') ||
      label.contains('通用');
}

/// 提取该角色标注里的索引：「角色1」→ 0，「角色 2」→ 1
int? _characterIndex(String label) {
  final m = RegExp(r'角色\s*(\d+)').firstMatch(label);
  if (m == null) return null;
  final n = int.tryParse(m.group(1) ?? '');
  if (n == null || n <= 0) return null;
  return n - 1;
}

/// 把整条助手回复中所有带标签的代码块按类型聚合
class AppliedSegments {
  final String? positive;
  final String? negative;
  final List<String> characterPrompts; // 索引 0,1,2... 对应 角色1,角色2,角色3...
  final List<String> characterNegatives;

  const AppliedSegments({
    this.positive,
    this.negative,
    required this.characterPrompts,
    required this.characterNegatives,
  });

  bool get isEmpty =>
      (positive == null || positive!.isEmpty) &&
      (negative == null || negative!.isEmpty) &&
      characterPrompts.isEmpty;
}

AppliedSegments _aggregateSegments(List<_Segment> segments) {
  String? positive;
  String? negative;
  final charPrompts = <int, String>{};
  final charNegatives = <int, String>{};

  for (final seg in segments) {
    if (!seg.isCode || seg.text.trim().isEmpty) continue;
    final label = seg.label;
    final text = seg.text.trim();

    final charIdx = _characterIndex(label);
    if (charIdx != null) {
      // 角色块。再判断这个块是该角色的正向还是负向：
      // 默认按正向；如果 label 同时包含负向关键词则按负向
      if (_isNegativeLabel(label)) {
        charNegatives[charIdx] = text;
      } else {
        charPrompts[charIdx] = text;
      }
      continue;
    }
    if (_isNegativeLabel(label)) {
      negative = (negative == null) ? text : '$negative, $text';
      continue;
    }
    if (_isPositiveLabel(label)) {
      positive = (positive == null) ? text : '$positive, $text';
      continue;
    }
  }

  // 按索引顺序铺平
  final maxIdx = [...charPrompts.keys, ...charNegatives.keys]
      .fold<int>(-1, (a, b) => b > a ? b : a);
  final promptsList = <String>[];
  final negativesList = <String>[];
  for (int i = 0; i <= maxIdx; i++) {
    promptsList.add(charPrompts[i] ?? '');
    negativesList.add(charNegatives[i] ?? '');
  }

  return AppliedSegments(
    positive: positive,
    negative: negative,
    characterPrompts: promptsList,
    characterNegatives: negativesList,
  );
}

List<_Segment> _splitContent(String content) {
  final segments = <_Segment>[];
  int cursor = 0;
  String pendingLabel = '';

  for (final m in _codeBlockRegex.allMatches(content)) {
    if (m.start > cursor) {
      final text = content.substring(cursor, m.start);
      if (text.trim().isNotEmpty) {
        // 提取代码块前的标注（取最后一行非空文本的冒号前部分）
        pendingLabel = _extractLabel(text);
        segments.add(_Segment.text(text));
      }
    }
    segments.add(_Segment.code((m.group(2) ?? '').trim(), m.group(1) ?? '', pendingLabel));
    pendingLabel = '';
    cursor = m.end;
  }
  if (cursor < content.length) {
    final tail = content.substring(cursor);
    if (tail.trim().isNotEmpty) segments.add(_Segment.text(tail));
  }
  if (segments.isEmpty && content.trim().isNotEmpty) {
    segments.add(_Segment.text(content));
  }
  return segments;
}

/// 从代码块前的文本中提取标注，如 "正向：" → "正向"，"角色1：" → "角色1"
String _extractLabel(String textBefore) {
  final lines = textBefore.trimRight().split('\n');
  for (int i = lines.length - 1; i >= 0; i--) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;
    // 去掉常见 markdown 装饰：**bold**、__bold__、*italic*、行首 #/-/>/  ` 等
    line = line
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'_+'), '')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'^[#\-\>\s]+'), '')
        .trim();
    if (line.isEmpty) continue;
    // 匹配 "正向：" "负向：" "通用底模词：" "角色1：" "角色1正向：" 等格式
    final match = RegExp(r'^[\s]*([\u4e00-\u9fff\d\s]+?)[\s]*[：:]').firstMatch(line);
    if (match != null) return match.group(1)!.trim();
    // 也匹配纯中文标注无冒号（如独立一行的"正向"或"角色1正向"）
    if (RegExp(r'^[\s]*[\u4e00-\u9fff\d\s]+[\s]*$').hasMatch(line)) {
      return line.trim();
    }
    break;
  }
  return '';
}

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
    final segments = _splitContent(message.content);
    final aggregated = isUser ? null : _aggregateSegments(segments);
    final showApplyAll = !isUser && onApplyAll != null && aggregated != null && !aggregated.isEmpty;

    Widget bubble = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                      : const Color(0xFF1C1C21).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Colors.white,
                                  ),
                                )
                              : SelectableText(
                                  seg.text.trim(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                    if (showApplyAll)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ApplyAllButton(
                          aggregated: aggregated,
                          onApplyAll: onApplyAll!,
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
      if (value == 'retry' && onRetry != null) {
        onRetry!();
      } else if (value == 'edit' && onEditAndResend != null) {
        _showEditDialog(context);
      } else if (value == 'copy') {
        Clipboard.setData(ClipboardData(text: message.content.replaceAll(RegExp(r'\n\[图片\]$'), '')));
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
        title: const Text('编辑消息'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 1,
          autofocus: true,
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '修改消息内容…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onEditAndResend?.call(controller.text.trim());
            },
            child: const Text('发送'),
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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lang.isNotEmpty || label.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Text(
                label.isNotEmpty
                    ? (lang.isNotEmpty ? '$label · ${lang.toLowerCase()}' : label)
                    : lang.toLowerCase(),
                style: const TextStyle(fontSize: 11, color: Colors.white54, fontFamily: 'monospace'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SelectableText(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.white,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (showApplyButtons)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
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

    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: offset.dx,
        top: offset.dy - 28,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.feedback,
              style: const TextStyle(fontSize: 11, color: Colors.white),
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
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, size: 13, color: Colors.white70),
            const SizedBox(width: 4),
            Text(widget.label, style: const TextStyle(fontSize: 12, color: Colors.white)),
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
    final charCount = aggregated.characterPrompts
        .where((p) => p.trim().isNotEmpty)
        .length;
    if (charCount > 0) parts.add('$charCount 个角色');
    return parts.isEmpty ? '' : '（${parts.join(' · ')}）';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        HapticFeedback.mediumImpact();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('一键替换全部'),
            content: Text(
              '此操作会先清空当前所有提示词（正向、负向、所有角色），'
              '然后写入本条消息中的内容$summary。无法撤销，是否继续？',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('确认替换'),
              ),
            ],
          ),
        );
        if (confirmed == true) onApplyAll(aggregated);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.32),
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.18),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.wand_stars, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '一键替换全部$summary',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
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
}
