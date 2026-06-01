import 'package:flutter/foundation.dart';
import 'package:nai_huishi/domain/entities/preset.dart';
import 'package:nai_huishi/domain/usecases/manage_presets.dart';

/// 预设模板 ViewModel
class PresetViewModel extends ChangeNotifier {
  final ManagePresetsUseCase _managePresets;

  PresetViewModel(this._managePresets);

  List<Preset> _presets = [];
  String? _selectedCategory;
  bool _isLoading = false;
  String? errorMessage;

  List<Preset> get presets => _selectedCategory != null
      ? _presets.where((p) => p.category == _selectedCategory).toList()
      : _presets;
  String? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;

  /// 加载所有预设
  Future<void> loadPresets() async {
    _isLoading = true;
    notifyListeners();

    try {
      _presets = await _managePresets.getAll();
    } catch (e) {
      errorMessage = '加载预设失败: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 初始化内置预设
  Future<void> initBuiltinPresets() async {
    try {
      await _managePresets.initBuiltin();
      await loadPresets();
    } catch (e) {
      errorMessage = '初始化预设失败: $e';
      notifyListeners();
    }
  }

  /// 筛选分类
  void filterByCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// 创建预设
  Future<Preset?> createPreset(Preset preset) async {
    try {
      final created = await _managePresets.create(preset);
      await loadPresets();
      return created;
    } catch (e) {
      errorMessage = '创建预设失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 更新预设
  Future<Preset?> updatePreset(Preset preset) async {
    try {
      final updated = await _managePresets.update(preset);
      await loadPresets();
      return updated;
    } catch (e) {
      errorMessage = '更新预设失败: $e';
      notifyListeners();
      return null;
    }
  }

  /// 删除预设
  Future<void> deletePreset(int id) async {
    try {
      await _managePresets.delete(id);
      _presets.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (e) {
      errorMessage = '删除预设失败: $e';
      notifyListeners();
    }
  }
}
