import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/domain/entities/prompt_memory.dart';
import 'package:nai_huishi/presentation/viewmodels/prompt_memory_viewmodel.dart';

class PromptMemoryPage extends StatefulWidget {
  const PromptMemoryPage({super.key});

  @override
  State<PromptMemoryPage> createState() => _PromptMemoryPageState();
}

class _PromptMemoryPageState extends State<PromptMemoryPage> {
  late final PromptMemoryViewModel _vm;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _vm = sl<PromptMemoryViewModel>();
    _searchController = TextEditingController();
    _vm.addListener(_onChanged);
    _vm.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showEditor([PromptMemory? memory]) async {
    final triggerController = TextEditingController(text: memory?.trigger ?? '');
    final contentController = TextEditingController(text: memory?.content ?? '');
    var type = memory?.type ?? PromptMemoryType.other;

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CupertinoAlertDialog(
          title: Text(memory == null ? '新增记忆' : '编辑记忆'),
          content: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                const SizedBox(height: 12),
                TextField(
                  controller: triggerController,
                  decoration: const InputDecoration(labelText: '触发词'),
                ),
                TextField(
                  controller: contentController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '正确内容'),
                ),
                const SizedBox(height: 8),
                DropdownButton<PromptMemoryType>(
                  value: type,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: PromptMemoryType.characterName, child: Text('人名')),
                    DropdownMenuItem(value: PromptMemoryType.characterFeature, child: Text('人物特征')),
                    DropdownMenuItem(value: PromptMemoryType.style, child: Text('画风')),
                    DropdownMenuItem(value: PromptMemoryType.other, child: Text('其他')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => type = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              onPressed: () async {
                final trigger = triggerController.text.trim();
                final content = contentController.text.trim();
                if (trigger.isEmpty || content.isEmpty) return;
                await _vm.save(
                  id: memory?.id,
                  trigger: trigger,
                  content: content,
                  type: type,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    triggerController.dispose();
    contentController.dispose();
  }

  String _typeLabel(PromptMemoryType type) {
    switch (type) {
      case PromptMemoryType.characterName:
        return '人名';
      case PromptMemoryType.characterFeature:
        return '人物特征';
      case PromptMemoryType.style:
        return '画风';
      case PromptMemoryType.other:
        return '其他';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('学习记忆'),
        actions: [
          IconButton(
            onPressed: () => _showEditor(),
            icon: const Icon(CupertinoIcons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: _vm.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(CupertinoIcons.search),
                hintText: '搜索触发词或内容',
              ),
            ),
          ),
          Expanded(
            child: _vm.isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : _vm.memories.isEmpty
                    ? const Center(
                        child: Text('暂无记忆', style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _vm.memories.length,
                        itemBuilder: (context, index) {
                          final memory = _vm.memories[index];
                          return Card(
                            child: ListTile(
                              title: Text(memory.trigger),
                              subtitle: Text('${_typeLabel(memory.type)} · ${memory.content}'),
                              onTap: () => _showEditor(memory),
                              trailing: IconButton(
                                icon: const Icon(CupertinoIcons.delete, color: Colors.redAccent),
                                onPressed: memory.id == null ? null : () => _vm.delete(memory.id!),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
