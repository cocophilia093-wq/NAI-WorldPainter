import 'package:nai_huishi/domain/entities/prompt_memory.dart';
import 'package:nai_huishi/domain/repositories/prompt_memory_repository.dart';

class ManagePromptMemoriesUseCase {
  final PromptMemoryRepository _repo;

  ManagePromptMemoriesUseCase(this._repo);

  Future<List<PromptMemory>> getAll() => _repo.getAll();
  Future<List<PromptMemory>> search(String query) => _repo.search(query);
  Future<List<PromptMemory>> matchText(String text) => _repo.matchText(text);
  Future<PromptMemory> save(PromptMemory memory) => _repo.save(memory);
  Future<void> delete(int id) => _repo.delete(id);
}
