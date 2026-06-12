import 'package:equatable/equatable.dart';

/// 超分引擎类型
enum SrEngine {
  /// Real-ESRGAN anime（realsr-ncnn，仅 x4，适合动漫/插画）
  realesrganAnime,

  /// RealCUGAN（realcugan-ncnn，支持 2x/4x，conservative 模型）
  realcugan,
}

/// 超分模型选项：引擎 + 倍率 + 模型子目录名。
/// 模型子目录对应 assets/sr_models/ 下释放到 filesDir 后的目录。
class SrModel extends Equatable {
  final SrEngine engine;
  final int scale;

  /// 展示名
  final String label;

  /// 简短说明
  final String description;

  const SrModel({
    required this.engine,
    required this.scale,
    required this.label,
    required this.description,
  });

  /// 传给原生层的引擎标识
  String get engineKey =>
      engine == SrEngine.realesrganAnime ? 'realsr' : 'realcugan';

  /// 模型所在子目录名（filesDir/sr_models/<dir>）
  String get modelSubDir {
    switch (engine) {
      case SrEngine.realesrganAnime:
        return 'realesrgan-anime';
      case SrEngine.realcugan:
        return 'realcugan/up${scale}x-conservative';
    }
  }

  /// 当前内置可选项
  static const List<SrModel> presets = [
    SrModel(
      engine: SrEngine.realesrganAnime,
      scale: 4,
      label: 'Real-ESRGAN 动漫 4x',
      description: '动漫/插画专用，线条锐利、去噪强',
    ),
    SrModel(
      engine: SrEngine.realcugan,
      scale: 2,
      label: 'RealCUGAN 2x',
      description: '保守模型，放大自然、细节保留好',
    ),
    SrModel(
      engine: SrEngine.realcugan,
      scale: 4,
      label: 'RealCUGAN 4x',
      description: '保守模型，4 倍放大',
    ),
  ];

  @override
  List<Object?> get props => [engine, scale];
}
