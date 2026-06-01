import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nai_huishi/domain/entities/llm_session.dart';
import 'package:nai_huishi/presentation/viewmodels/llm_chat_viewmodel.dart';

Future<void> showChatSessionsPanel(
  BuildContext context, {
  required LlmChatViewModel vm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _SessionsPanel(vm: vm),
  );
}

class _SessionsPanel extends StatefulWidget {
  final LlmChatViewModel vm;
  const _SessionsPanel({required this.vm});

  @override
  State<_SessionsPanel> createState() => _SessionsPanelState();
}

class _SessionsPanelState extends State<_SessionsPanel> {
  @override
  void initState() {
    super.initState();
    widget.vm.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    widget.vm.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _rename(LlmSession session) async {
    // 先关菜单，再弹 dialog，避免 context 层级混乱
    final title = await _showRenameDialog(context, session.title);
    if (title != null && title.trim().isNotEmpty) {
      await widget.vm.renameSession(session.id, title.trim());
      // vm 通知后 setState 会自动刷新列表
    }
  }

  Future<void> _delete(LlmSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除会话'),
        content: Text('确定删除「${session.title}」？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.vm.deleteSession(session.id);
      // 列表通过 vm listener 刷新，不 pop sheet
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = widget.vm.sessions;
    final activeSessionId = widget.vm.activeSessionId;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C21),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '会话历史',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await widget.vm.createNewSession();
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    icon: const Icon(CupertinoIcons.add, size: 16),
                    label: const Text('新对话'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: sessions.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text('还没有会话', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final session = sessions[index];
                          final active = session.id == activeSessionId;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () async {
                                await widget.vm.selectSession(session.id);
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: active
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withValues(alpha: 0.12)
                                      : Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: active
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                            .withValues(alpha: 0.5)
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            session.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatDate(session.updatedAt),
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white54),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 用普通 IconButton + showMenu 替代 PopupMenuButton
                                    // 避免 PopupMenuButton 的 context 层级问题
                                    Builder(
                                      builder: (btnCtx) => IconButton(
                                        icon: const Icon(
                                            CupertinoIcons.ellipsis,
                                            color: Colors.white70),
                                        onPressed: () async {
                                          final RenderBox button =
                                              btnCtx.findRenderObject()
                                                  as RenderBox;
                                          final RenderBox overlay =
                                              Navigator.of(btnCtx)
                                                      .overlay!
                                                      .context
                                                      .findRenderObject()
                                                  as RenderBox;
                                          final RelativeRect position =
                                              RelativeRect.fromRect(
                                            button.localToGlobal(Offset.zero,
                                                    ancestor: overlay) &
                                                button.size,
                                            Offset.zero & overlay.size,
                                          );
                                          final value =
                                              await showMenu<String>(
                                            context: btnCtx,
                                            position: position,
                                            items: const [
                                              PopupMenuItem(
                                                  value: 'rename',
                                                  child: Text('重命名')),
                                              PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('删除',
                                                      style: TextStyle(
                                                          color: Colors.red))),
                                            ],
                                          );
                                          if (value == 'rename') {
                                            await _rename(session);
                                          } else if (value == 'delete') {
                                            await _delete(session);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _showRenameDialog(
    BuildContext context, String initialTitle) async {
  final controller = TextEditingController(text: initialTitle);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('重命名会话'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '输入新的会话标题'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      );
    },
  );
}

String _formatDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
