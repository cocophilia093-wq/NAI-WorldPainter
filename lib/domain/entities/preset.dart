import 'package:equatable/equatable.dart';
import 'package:nai_huishi/domain/entities/generation_task.dart';

class Preset extends Equatable {
  final int? id;
  final String name;
  final String? description;
  final String category;
  final String model;
  final String prompt;
  final String? negativePrompt;
  final int width;
  final int height;
  final double scale;
  final double cfgRescale;
  final String sampler;
  final String noiseSchedule;
  final List<CharacterSpec>? characters;
  final bool isBuiltin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Preset({
    this.id,
    required this.name,
    this.description,
    required this.category,
    required this.model,
    required this.prompt,
    this.negativePrompt,
    required this.width,
    required this.height,
    required this.scale,
    required this.cfgRescale,
    required this.sampler,
    required this.noiseSchedule,
    this.characters,
    this.isBuiltin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Preset copyWith({
    int? id,
    String? name,
    String? description,
    String? category,
    String? model,
    String? prompt,
    String? negativePrompt,
    int? width,
    int? height,
    double? scale,
    double? cfgRescale,
    String? sampler,
    String? noiseSchedule,
    List<CharacterSpec>? characters,
    bool? isBuiltin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Preset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      model: model ?? this.model,
      prompt: prompt ?? this.prompt,
      negativePrompt: negativePrompt ?? this.negativePrompt,
      width: width ?? this.width,
      height: height ?? this.height,
      scale: scale ?? this.scale,
      cfgRescale: cfgRescale ?? this.cfgRescale,
      sampler: sampler ?? this.sampler,
      noiseSchedule: noiseSchedule ?? this.noiseSchedule,
      characters: characters ?? this.characters,
      isBuiltin: isBuiltin ?? this.isBuiltin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name];
}
