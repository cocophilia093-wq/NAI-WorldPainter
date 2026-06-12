import 'package:nai_huishi/domain/entities/sr_model.dart';

/// 图片超分仓库接口
abstract class SuperResolutionRepository {
  /// 首次使用前把模型从 assets 释放到可读目录，返回模型根目录。
  Future<String> prepareModels();

  /// 对 [inputPath] 图片执行超分，结果写入 [outputPath]。
  /// [onProgress] 流式回调原生程序输出的进度行。
  /// 返回输出文件路径。
  Future<String> upscale({
    required String inputPath,
    required String outputPath,
    required SrModel model,
    void Function(String line)? onProgress,
  });

  /// 取消当前任务
  Future<void> cancel();
}
