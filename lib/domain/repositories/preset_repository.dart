import 'package:nai_huishi/domain/entities/preset.dart';

abstract class PresetRepository {
  Future<List<Preset>> getAllPresets();
  Future<Preset?> getPreset(int id);
  Future<Preset> createPreset(Preset preset);
  Future<Preset> updatePreset(Preset preset);
  Future<void> deletePreset(int id);
  Future<List<Preset>> getPresetsByCategory(String category);
  Future<void> initBuiltinPresets();
}
