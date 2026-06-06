import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/domain/entities/generation_task.dart';
import 'package:nai_huishi/presentation/pages/history_detail_page.dart';
import 'package:nai_huishi/presentation/viewmodels/history_viewmodel.dart';
import 'package:nai_huishi/presentation/widgets/fullscreen_image_preview.dart';

class HistoryPage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const HistoryPage({super.key, this.onNavigate});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late final HistoryViewModel _vm;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _vm = sl<HistoryViewModel>();
    _vm.addListener(_onVmChanged);
    _vm.loadHistory(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      if (_vm.hasMore && !_vm.isLoading) {
        _vm.loadHistory();
      }
    }
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vm.loadHistory(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.photo_on_rectangle, size: 18),
            SizedBox(width: 6),
            Text('历史画廊', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '清空历史',
            icon: const Icon(CupertinoIcons.trash, size: 20),
            onPressed: _vm.history.isEmpty
                ? null
                : () async {
                    final confirmed = await showCupertinoDialog<bool>(
                      context: context,
                      builder: (ctx) => CupertinoAlertDialog(
                        title: const Text('清空历史记录'),
                        content: const Text('只会清空历史列表，不会删除已保存到本地或系统相册的图片。是否继续？'),
                        actions: [
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('取消'),
                          ),
                          CupertinoDialogAction(
                            onPressed: () => Navigator.pop(ctx, true),
                            isDestructiveAction: true,
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _vm.clearHistory();
                    }
                  },
          ),
        ],
      ),
      body: _vm.isLoading && _vm.history.isEmpty
          ? const Center(child: CupertinoActivityIndicator())
          : !_vm.isLoading && _vm.history.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.sparkles,
                          size: 42,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '请去创造更多美好回忆吧！',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: widget.onNavigate == null ? null : () => widget.onNavigate!(1),
                          child: const Text('去创作'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _vm.loadHistory(refresh: true),
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 120 + MediaQuery.paddingOf(context).bottom,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _vm.history.length + (_vm.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _vm.history.length) {
                        return const Center(child: CupertinoActivityIndicator());
                      }
                      return _HistoryGridCard(
                        item: _vm.history[index],
                        onNavigate: widget.onNavigate,
                      );
                    },
                  ),
                ),
    );
  }
}

class _HistoryGridCard extends StatefulWidget {
  final GenerationTask item;
  final ValueChanged<int>? onNavigate;

  const _HistoryGridCard({required this.item, this.onNavigate});

  @override
  State<_HistoryGridCard> createState() => _HistoryGridCardState();
}

class _HistoryGridCardState extends State<_HistoryGridCard> {
  bool _pressed = false;

  void _openDetail() {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => HistoryDetailPage(
          task: widget.item,
          onNavigate: widget.onNavigate,
        ),
      ),
    );
  }

  void _openPreview() {
    showFullscreenImagePreview(
      context,
      imagePath: widget.item.imagePath,
      imageUrl: widget.item.imageUrl,
    );
  }

  Future<void> _showActions() async {
    final item = widget.item;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.94, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              alignment: Alignment.bottomCenter,
              child: child,
            );
          },
          child: DraggableScrollableSheet(
            initialChildSize: 0.78,
            minChildSize: 0.35,
            maxChildSize: 0.96,
            snap: true,
            snapSizes: const [0.78, 0.96],
            builder: (context, scrollController) {
              return SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C21) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 46,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.34),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: AspectRatio(
                            aspectRatio: 0.86,
                            child: item.imagePath != null && File(item.imagePath!).existsSync()
                                ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                                : item.imageUrl != null
                                    ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                                    : Container(
                                        color: theme.colorScheme.surface,
                                        child: Icon(CupertinoIcons.photo, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _HistoryActionTile(
                          icon: CupertinoIcons.fullscreen,
                          title: '放大查看',
                          onTap: () {
                            Navigator.pop(ctx);
                            _openPreview();
                          },
                        ),
                        _HistoryActionTile(
                          icon: CupertinoIcons.doc_on_doc,
                          title: '复制提示词',
                          onTap: () {
                            Navigator.pop(ctx);
                            Clipboard.setData(ClipboardData(text: widget.item.prompt));
                          },
                        ),
                        _HistoryActionTile(
                          icon: CupertinoIcons.info_circle,
                          title: '查看生成详情',
                          onTap: () {
                            Navigator.pop(ctx);
                            _openDetail();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasLocalImage = item.imagePath != null && File(item.imagePath!).existsSync();

    return GestureDetector(
      onTap: _openDetail,
      onDoubleTap: _openPreview,
      onLongPressStart: (_) => setState(() => _pressed = true),
      onLongPressEnd: (_) => setState(() => _pressed = false),
      onLongPress: _showActions,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 210),
        curve: _pressed ? Curves.easeOutCubic : Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(_pressed ? 22 : 16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: _pressed ? 0.35 : 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: _pressed ? 0.1 : 0.2)
                    : Theme.of(context).colorScheme.primary.withValues(alpha: _pressed ? 0.04 : 0.08),
                blurRadius: _pressed ? 4 : 8,
                offset: Offset(0, _pressed ? 2 : 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasLocalImage)
                Image.file(File(item.imagePath!), fit: BoxFit.cover)
              else if (item.imageUrl != null)
                Image.network(item.imageUrl!, fit: BoxFit.cover)
              else
                Center(
                  child: Icon(
                    CupertinoIcons.photo,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.25),
                    size: 32,
                  ),
                ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
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
                    item.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _HistoryActionTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onTap: onTap,
    );
  }
}
