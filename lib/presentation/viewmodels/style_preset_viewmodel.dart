import 'package:flutter/foundation.dart';
import 'package:nai_huishi/domain/entities/style_preset.dart';
import 'package:nai_huishi/domain/usecases/manage_style_presets.dart';

class StylePresetViewModel extends ChangeNotifier {
  final ManageStylePresetsUseCase _useCase;

  StylePresetViewModel(this._useCase);

  List<StylePreset> presets = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      presets = await _useCase.getAll();
      errorMessage = null;
    } catch (e) {
      errorMessage = '加载收藏失败: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> create({
    required String title,
    required String prompt,
    required String sourceImagePath,
  }) async {
    await _useCase.createFromImage(
      title: title,
      prompt: prompt,
      sourceImagePath: sourceImagePath,
    );
    await load();
  }

  Future<void> update(StylePreset preset) async {
    await _useCase.update(preset);
    await load();
  }

  Future<void> delete(int id) async {
    await _useCase.delete(id);
    await load();
  }
}
