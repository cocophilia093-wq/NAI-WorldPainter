import 'package:nai_huishi/domain/entities/artist_prompt.dart';

abstract class ArtistPromptRepository {
  Future<List<ArtistPrompt>> getAll();
  Future<List<String>> getCategories();
  Future<ArtistPrompt> create({
    required String name,
    required String tag,
    required String imagePath,
    required List<String> categories,
    required int danbooruCount,
  });
  Future<ArtistPrompt> update(ArtistPrompt artist);
  Future<void> delete(int id);
  Future<void> addCategory(String category);
  Future<void> deleteCategory(String category);
  Future<Map<String, dynamic>> exportData();
  Future<int> importData(Map<String, dynamic> data);
}
