import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/presentation/pages/generate_page.dart';
import 'package:nai_huishi/presentation/pages/history_page.dart';
import 'package:nai_huishi/presentation/pages/settings_page.dart';
import 'package:nai_huishi/presentation/viewmodels/generation_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/history_viewmodel.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  void _switchPage(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      // 切到生成页时刷新模型列表（用户可能刚在设置页保存了供应商配置）
      if (index == 1) {
        sl<GenerationViewModel>().loadModels();
      }
      // 切到历史页时主动刷新一次（IndexedStack 不会触发子页 didChangeDependencies）
      if (index == 0) {
        sl<HistoryViewModel>().loadHistory(refresh: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // 页面内容
          IndexedStack(
            index: _currentIndex,
            children: [
              HistoryPage(onNavigate: _switchPage), // 0
              GeneratePage(onNavigate: _switchPage), // 1
              const SettingsPage(), // 2
            ],
          ),

          // 在非生成页时，显示一个简化的底部导航
          if (_currentIndex != 1) // 只要不在生成页，就显示导航
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildSimpleBottomBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildSimpleBottomBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64 + MediaQuery.paddingOf(context).bottom,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withValues(alpha: 0.8), // 苹果标准半透深灰
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1), // 微弱高光描边
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, CupertinoIcons.clock, CupertinoIcons.clock_fill, '历史'),
              _buildNavItem(1, CupertinoIcons.paintbrush, CupertinoIcons.paintbrush_fill, '生成'),
              _buildNavItem(2, CupertinoIcons.settings, CupertinoIcons.settings_solid, '设置'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.white.withValues(alpha: 0.5);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _switchPage(index),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
