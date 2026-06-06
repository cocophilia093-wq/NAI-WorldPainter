import 'package:nai_huishi/domain/entities/style_preset.dart';

abstract class StylePresetRepository {
  Future<List<StylePreset>> getAll();
  Future<StylePreset> createFromImage({
    required String title,
    required String prompt,
    required String sourceImagePath,
  });
  Future<StylePreset> update(StylePreset preset);
  Future<void> delete(int id);
}
