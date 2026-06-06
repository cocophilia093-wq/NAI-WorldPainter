import 'package:flutter/material.dart';
import 'package:nai_huishi/presentation/app_theme.dart';
import 'package:nai_huishi/presentation/pages/home_page.dart';

class NaiHuishiApp extends StatefulWidget {
  const NaiHuishiApp({super.key});

  @override
  State<NaiHuishiApp> createState() => _NaiHuishiAppState();
}

class _NaiHuishiAppState extends State<NaiHuishiApp> {
  Brightness _brightness = Brightness.dark;

  void _toggleTheme() {
    setState(() {
      _brightness = _brightness == Brightness.dark ? Brightness.light : Brightness.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'nai 绘世',
      theme: buildNaiHuishiTheme(_brightness),
      home: HomePage(
        brightness: _brightness,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
