import 'dart:io';
import 'package:flutter/material.dart';
import 'package:nai_huishi/domain/entities/generation_task.dart';
import 'package:nai_huishi/domain/usecases/save_image.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/presentation/viewmodels/generation_viewmodel.dart';
import 'package:nai_huishi/presentation/widgets/fullscreen_image_preview.dart';

class HistoryDetailPage extends StatelessWidget {
  final GenerationTask task;
  final ValueChanged<int>? onNavigate;

  const HistoryDetailPage({super.key, required this.task, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('生成详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(context, theme),
            const SizedBox(height: 16),
            _buildActionButtons(context),
            const SizedBox(height: 16),
            _buildParamsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection(BuildContext context, ThemeData theme) {
    Widget imageWidget;
    if (task.imagePath != null && File(task.imagePath!).existsSync()) {
      imageWidget = GestureDetector(
        onTap: () => _openImagePreview(context),
        child: Image.file(
          File(task.imagePath!),
          fit: BoxFit.contain,
        ),
      );
    } else if (task.imageUrl != null) {
      imageWidget = GestureDetector(
        onTap: () => _openImagePreview(context),
        child: Image.network(
          task.imageUrl!,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64),
        ),
      );
    } else {
      imageWidget = const Center(child: Icon(Icons.image_not_supported_outlined, size: 64));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 400),
          child: Center(child: imageWidget),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _applyToGeneratePage(context),
          icon: const Icon(Icons.auto_fix_high),
          label: const Text('覆盖到创作页'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _saveToGallery(context),
          icon: const Icon(Icons.save_alt),
          label: const Text('保存到相册'),
        ),
      ],
    );
  }

  Widget _buildParamsSection(ThemeData theme) {
    final params = [
      ('模型', task.model),
      ('正面提示词', task.prompt),
      ('负面提示词', task.negativePrompt ?? '（无）'),
      ('分辨率', '${task.width} × ${task.height}'),
      ('Scale', task.scale.toStringAsFixed(1)),
      ('CFG Rescale', task.cfgRescale.toStringAsFixed(2)),
      ('采样器', task.sampler),
      ('噪声调度', task.noiseSchedule),
      ('Seed', task.seed?.toString() ?? '随机'),
      ('状态', task.status),
      ('创建时间', task.createdAt.toString()),
      if (task.completedAt != null) ('完成时间', task.completedAt!.toString()),
      if (task.errorMessage != null) ('错误信息', task.errorMessage!),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('生成参数', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...params.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(
                        p.$1,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: SelectableText(p.$2, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
            if (task.characters != null && task.characters!.isNotEmpty) ...[
              const Divider(),
              Text('多角色', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...task.characters!.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '角色${i + 1}: ${c.prompt} | 负面: ${c.uc ?? "（无）"} | 位置: ${c.centerX != null && c.centerY != null ? "(${c.centerX!.toStringAsFixed(2)}, ${c.centerY!.toStringAsFixed(2)})" : "AI决定位置"}',
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _applyToGeneratePage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await sl<GenerationViewModel>().loadFromHistory(task);
    if (!context.mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('已覆盖到创作页')));
    Navigator.of(context).pop();
    onNavigate?.call(1);
  }

  Future<void> _saveToGallery(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saveUseCase = sl<SaveImageUseCase>();
      if (task.imagePath != null && File(task.imagePath!).existsSync()) {
        final saved = await saveUseCase.saveToGallery(task.imagePath!);
        if (!context.mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(saved ? '已保存到相册' : '保存失败')));
      } else if (task.imageUrl != null) {
        final filePath = await saveUseCase.execute(task);
        final saved = await saveUseCase.saveToGallery(filePath);
        if (!context.mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(saved ? '已保存到相册' : '保存失败')));
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  void _openImagePreview(BuildContext context) {
    showFullscreenImagePreview(
      context,
      imagePath: task.imagePath,
      imageUrl: task.imageUrl,
    );
  }
}
