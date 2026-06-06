import 'package:nai_huishi/domain/entities/style_preset.dart';
import 'package:nai_huishi/domain/repositories/style_preset_repository.dart';

class ManageStylePresetsUseCase {
  final StylePresetRepository _repo;

  ManageStylePresetsUseCase(this._repo);

  Future<List<StylePreset>> getAll() => _repo.getAll();
  Future<StylePreset> createFromImage({
    required String title,
    required String prompt,
    required String sourceImagePath,
  }) =>
      _repo.createFromImage(
        title: title,
        prompt: prompt,
        sourceImagePath: sourceImagePath,
      );
  Future<StylePreset> update(StylePreset preset) => _repo.update(preset);
  Future<void> delete(int id) => _repo.delete(id);
}
