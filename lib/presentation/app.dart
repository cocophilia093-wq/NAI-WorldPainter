import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nai_huishi/presentation/pages/home_page.dart';

/// 中文字体回退链：Android 上系统会按顺序匹配。
/// 苹果设备：PingFang SC；鸿蒙：HarmonyOS Sans SC；
/// 第三方 Android：Source Han Sans / Noto Sans CJK SC / Microsoft YaHei。
const _zhFallback = <String>[
  'PingFang SC',
  'HarmonyOS Sans SC',
  'Source Han Sans CN',
  'Noto Sans CJK SC',
  'Microsoft YaHei',
  'sans-serif',
];

/// 把 textTheme 整体加粗一档 + 注入中文回退族，模仿苹果系统 UI 的「粗体」观感。
TextTheme _appleishBold(TextTheme base) {
  TextStyle? bump(TextStyle? s, FontWeight target) {
    if (s == null) return null;
    return s.copyWith(
      fontWeight: target,
      fontFamilyFallback: _zhFallback,
      letterSpacing: (s.letterSpacing ?? 0) - 0.1,
    );
  }

  return base.copyWith(
    displayLarge: bump(base.displayLarge, FontWeight.w700),
    displayMedium: bump(base.displayMedium, FontWeight.w700),
    displaySmall: bump(base.displaySmall, FontWeight.w700),
    headlineLarge: bump(base.headlineLarge, FontWeight.w700),
    headlineMedium: bump(base.headlineMedium, FontWeight.w700),
    headlineSmall: bump(base.headlineSmall, FontWeight.w700),
    titleLarge: bump(base.titleLarge, FontWeight.w700),
    titleMedium: bump(base.titleMedium, FontWeight.w600),
    titleSmall: bump(base.titleSmall, FontWeight.w600),
    bodyLarge: bump(base.bodyLarge, FontWeight.w600),
    bodyMedium: bump(base.bodyMedium, FontWeight.w600),
    bodySmall: bump(base.bodySmall, FontWeight.w600),
    labelLarge: bump(base.labelLarge, FontWeight.w700),
    labelMedium: bump(base.labelMedium, FontWeight.w600),
    labelSmall: bump(base.labelSmall, FontWeight.w600),
  );
}

class NaiHuishiApp extends StatelessWidget {
  const NaiHuishiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(brightness: Brightness.dark).textTheme;
    // Inter 是 SF Pro 最接近的开源替代；中文交给系统按 fallback 链匹配。
    final interTheme = GoogleFonts.interTextTheme(baseTheme);
    final textTheme = _appleishBold(interTheme).apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'nai 绘世',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0A0C), // 极暗高级感背景
        // 全局默认 family 走 Inter，配合 fontFamilyFallback 渲染中文。
        fontFamily: GoogleFonts.inter().fontFamily,
        fontFamilyFallback: _zhFallback,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFF5D57A), // 淡金色
          onPrimary: Colors.black,
          secondary: const Color(0xFF6C5CE7), // 高雅紫
          surface: const Color(0xFF1C1C21), // 卡片颜色
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white.withValues(alpha: 0.6), // 副标题透明度
        ),
        textTheme: textTheme,
        cardTheme: CardThemeData(
          color: const Color(0xFF1C1C21).withValues(alpha: 0.8), // 微透深灰卡片
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.05), // 微弱高光描边
              width: 1,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.03),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFF5D57A), width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
      home: const HomePage(),
    );
  }
}
