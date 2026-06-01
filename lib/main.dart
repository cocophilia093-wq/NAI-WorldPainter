import 'package:flutter/material.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/core/services/background_keepalive_service.dart';
import 'package:nai_huishi/presentation/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await BackgroundKeepAliveService.instance.init();
  runApp(const NaiHuishiApp());
}
