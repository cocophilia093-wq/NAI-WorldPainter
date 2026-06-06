import 'package:nai_huishi/domain/entities/prompt_memory.dart';

abstract class PromptMemoryRepository {
  Future<List<PromptMemory>> getAll();
  Future<List<PromptMemory>> search(String query);
  Future<List<PromptMemory>> matchText(String text);
  Future<PromptMemory> save(PromptMemory memory);
  Future<void> delete(int id);
}
