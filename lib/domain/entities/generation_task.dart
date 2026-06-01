import 'package:equatable/equatable.dart';

enum GenerationMode {
  textToImage,
  inpainting,
}

enum ImageProviderType {
  novelAi,
  gpt,
  nanoBanana,
}

class GenerationTask extends Equatable {
  final int? id;
  final String taskId;
  final String model;
  final String prompt;
  final String? negativePrompt;
  final int width;
  final int height;
  final String? size;
  final double scale;
  final double cfgRescale;
  final String sampler;
  final String noiseSchedule;
  final int? seed;
  final List<CharacterSpec>? characters;
  final String status;
  final String? imagePath;
  final String? imageUrl;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final GenerationMode mode;
  final String? sourceImagePath;
  final String? maskImagePath;
  final double? inpaintStrength;
  final String? responseFormat;
  final ImageProviderType providerType;
  final List<String>? gptImagePaths;
  final String? nanoImageSize;

  const GenerationTask({
    this.id,
    required this.taskId,
    required this.model,
    required this.prompt,
    this.negativePrompt,
    required this.width,
    required this.height,
    this.size,
    required this.scale,
    required this.cfgRescale,
    required this.sampler,
    required this.noiseSchedule,
    this.seed,
    this.characters,
    required this.status,
    this.imagePath,
    this.imageUrl,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.mode = GenerationMode.textToImage,
    this.sourceImagePath,
    this.maskImagePath,
    this.inpaintStrength,
    this.responseFormat,
    this.providerType = ImageProviderType.novelAi,
    this.gptImagePaths,
    this.nanoImageSize,
  });

  GenerationTask copyWith({
    int? id,
    String? taskId,
    String? model,
    String? prompt,
    String? negativePrompt,
    int? width,
    int? height,
    String? size,
    double? scale,
    double? cfgRescale,
    String? sampler,
    String? noiseSchedule,
    int? seed,
    List<CharacterSpec>? characters,
    String? status,
    String? imagePath,
    String? imageUrl,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
    GenerationMode? mode,
    String? sourceImagePath,
    String? maskImagePath,
    double? inpaintStrength,
    String? responseFormat,
    ImageProviderType? providerType,
    List<String>? gptImagePaths,
    String? nanoImageSize,
  }) {
    return GenerationTask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      model: model ?? this.model,
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      width: width ?? this.width,
      height: height ?? this.height,
      size: size ?? this.size,
      scale: scale ?? this.scale,
      cfgRescale: cfgRescale ?? this.cfgRescale,
      sampler: sampler ?? this.sampler,
      noiseSchedule: noiseSchedule ?? this.noiseSchedule,
      seed: seed ?? this.seed,
      characters: characters ?? this.characters,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      mode: mode ?? this.mode,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      maskImagePath: maskImagePath ?? this.maskImagePath,
      inpaintStrength: inpaintStrength ?? this.inpaintStrength,
      responseFormat: responseFormat ?? this.responseFormat,
      providerType: providerType ?? this.providerType,
      gptImagePaths: gptImagePaths ?? this.gptImagePaths,
      nanoImageSize: nanoImageSize ?? this.nanoImageSize,
    );
  }

  @override
  List<Object?> get props => [taskId];
}

/// 多人物坐标规格
class CharacterSpec extends Equatable {
  final String prompt;
  final String? uc;
  final double? centerX;
  final double? centerY;
  final bool enabled;

  const CharacterSpec({
    required this.prompt,
    this.uc,
    this.centerX,
    this.centerY,
    this.enabled = true,
  });

  CharacterSpec copyWith({
    String? prompt,
    String? uc,
    double? centerX,
    double? centerY,
    bool clearUc = false,
    bool clearCenter = false,
    bool? enabled,
  }) {
    return CharacterSpec(
      prompt: prompt ?? this.prompt,
      uc: clearUc ? null : (uc ?? this.uc),
      centerX: clearCenter ? null : (centerX ?? this.centerX),
      centerY: clearCenter ? null : (centerY ?? this.centerY),
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    if (uc != null) 'uc': uc,
    if (centerX != null) 'center_x': centerX,
    if (centerY != null) 'center_y': centerY,
    'enabled': enabled,
  };

  factory CharacterSpec.fromJson(Map<String, dynamic> json) => CharacterSpec(
    prompt: json['prompt'] as String,
    uc: json['uc'] as String?,
    centerX: json['center_x'] != null ? (json['center_x'] as num).toDouble() : null,
    centerY: json['center_y'] != null ? (json['center_y'] as num).toDouble() : null,
    enabled: json['enabled'] as bool? ?? true,
  );

  @override
  List<Object?> get props => [prompt, uc, centerX, centerY, enabled];
}
