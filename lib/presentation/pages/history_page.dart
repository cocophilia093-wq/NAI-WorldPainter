import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/presentation/viewmodels/history_viewmodel.dart';
import 'package:nai_huishi/presentation/pages/history_detail_page.dart';

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
    // 每次进入页面时自动刷新
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
          : RefreshIndicator(
              onRefresh: () => _vm.loadHistory(refresh: true),
              child: GridView.builder(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 120 + MediaQuery.paddingOf(context).bottom, // 为底部导航栏留白
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
                  final item = _vm.history[index];
                  final hasLocalImage = item.imagePath != null && File(item.imagePath!).existsSync();

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(context, CupertinoPageRoute(
                        builder: (_) => HistoryDetailPage(
                          task: item,
                          onNavigate: widget.onNavigate,
                        ),
                      ));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C21),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
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
                            const Center(child: Icon(CupertinoIcons.photo, color: Colors.white24, size: 32)),
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
                                style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
