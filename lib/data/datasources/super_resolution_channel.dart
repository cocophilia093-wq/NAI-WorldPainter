import 'package:flutter/services.dart';

/// 超分原生通道封装。
/// MethodChannel 触发任务，EventChannel 流式接收原生程序的进度输出。
class SuperResolutionChannel {
  static const MethodChannel _method =
      MethodChannel('com.naihuishi.nai_huishi/super_resolution');
  static const EventChannel _event =
      EventChannel('com.naihuishi.nai_huishi/super_resolution_progress');

  /// 进度行流（原生程序 stdout/stderr 的每一行）
  Stream<String> get progressStream =>
      _event.receiveBroadcastStream().map((e) => e.toString());

  /// 把 assets 模型释放到可读目录，返回模型根目录绝对路径。
  Future<String> prepareAssets() async {
    final dir = await _method.invokeMethod<String>('prepareAssets');
    return dir ?? '';
  }

  /// 执行超分。返回输出路径，失败抛 PlatformException。
  Future<String> upscale({
    required String engine,
    required String inputPath,
    required String outputPath,
    required int scale,
    required String modelDir,
  }) async {
    final out = await _method.invokeMethod<String>('upscale', {
      'engine': engine,
      'inputPath': inputPath,
      'outputPath': outputPath,
      'scale': scale,
      'modelDir': modelDir,
    });
    return out ?? outputPath;
  }

  /// 取消当前任务
  Future<void> cancel() async {
    await _method.invokeMethod('cancel');
  }
}
