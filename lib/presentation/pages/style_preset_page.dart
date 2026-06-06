import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/presentation/pages/style_preset_detail_page.dart';
import 'package:nai_huishi/presentation/viewmodels/style_preset_viewmodel.dart';

class StylePresetPage extends StatefulWidget {
  final void Function(String prompt) onApplyPrompt;

  const StylePresetPage({super.key, required this.onApplyPrompt});

  @override
  State<StylePresetPage> createState() => _StylePresetPageState();
}

class _StylePresetPageState extends State<StylePresetPage> {
  late final StylePresetViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = sl<StylePresetViewModel>();
    _vm.addListener(_onChanged);
    _vm.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _addPreset() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!mounted) return;

    final titleController = TextEditingController();
    final promptController = TextEditingController();

    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('新增画风收藏'),
        content: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              TextField(
                controller: promptController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: '画风/画师串'),
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
              final title = titleController.text.trim();
              final prompt = promptController.text.trim();
              if (title.isEmpty || prompt.isEmpty) return;
              await _vm.create(
                title: title,
                prompt: prompt,
                sourceImagePath: picked.path,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    titleController.dispose();
    promptController.dispose();
  }

  void _applyAndClose(String prompt) {
    widget.onApplyPrompt(prompt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('画风收藏'),
        actions: [
          IconButton(
            onPressed: _addPreset,
            icon: const Icon(CupertinoIcons.add),
          ),
        ],
      ),
      body: _vm.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _vm.presets.isEmpty
              ? const Center(
                  child: Text('暂无画风收藏', style: TextStyle(color: Colors.white54)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _vm.presets.length,
                  itemBuilder: (context, index) {
                    final preset = _vm.presets[index];
                    final file = File(preset.imagePath);
                    final exists = file.existsSync();
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          CupertinoPageRoute(
                            builder: (_) => StylePresetDetailPage(
                              preset: preset,
                              vm: _vm,
                              onApplyPrompt: _applyAndClose,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C21),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (exists)
                              Image.file(file, fit: BoxFit.cover)
                            else
                              const Center(child: Icon(CupertinoIcons.photo, color: Colors.white24, size: 32)),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black.withValues(alpha: 0.8), Colors.transparent],
                                  ),
                                ),
                                child: Text(
                                  preset.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
