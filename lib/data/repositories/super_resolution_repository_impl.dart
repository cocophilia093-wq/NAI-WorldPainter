import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:nai_huishi/data/datasources/super_resolution_channel.dart';
import 'package:nai_huishi/domain/entities/sr_model.dart';
import 'package:nai_huishi/domain/repositories/super_resolution_repository.dart';

class SuperResolutionRepositoryImpl implements SuperResolutionRepository {
  final SuperResolutionChannel _channel;

  /// 模型根目录（filesDir/sr_models），prepareModels 后缓存。
  String? _modelRoot;

  SuperResolutionRepositoryImpl(this._channel);

  @override
  Future<String> prepareModels() async {
    final root = await _channel.prepareAssets();
    _modelRoot = root;
    return root;
  }

  @override
  Future<String> upscale({
    required String inputPath,
    required String outputPath,
    required SrModel model,
    void Function(String line)? onProgress,
  }) async {
    final root = _modelRoot ??= await _channel.prepareAssets();
    final modelDir = p.join(root, model.modelSubDir);

    StreamSubscription<String>? sub;
    if (onProgress != null) {
      sub = _channel.progressStream.listen(onProgress);
    }
    try {
      return await _channel.upscale(
        engine: model.engineKey,
        inputPath: inputPath,
        outputPath: outputPath,
        scale: model.scale,
        modelDir: modelDir,
      );
    } finally {
      await sub?.cancel();
    }
  }

  @override
  Future<void> cancel() => _channel.cancel();
}
