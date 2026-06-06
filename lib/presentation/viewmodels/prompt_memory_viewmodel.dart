import 'package:flutter/foundation.dart';
import 'package:nai_huishi/domain/entities/prompt_memory.dart';
import 'package:nai_huishi/domain/usecases/manage_prompt_memories.dart';

class PromptMemoryViewModel extends ChangeNotifier {
  final ManagePromptMemoriesUseCase _useCase;

  PromptMemoryViewModel(this._useCase);

  List<PromptMemory> memories = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      memories = await _useCase.getAll();
      errorMessage = null;
    } catch (e) {
      errorMessage = '加载记忆失败: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    memories = await _useCase.search(query);
    notifyListeners();
  }

  Future<void> save({
    int? id,
    required String trigger,
    required String content,
    PromptMemoryType type = PromptMemoryType.other,
  }) async {
    final now = DateTime.now();
    await _useCase.save(PromptMemory(
      id: id,
      trigger: trigger,
      content: content,
      type: type,
      source: PromptMemorySource.manual,
      createdAt: now,
      updatedAt: now,
    ));
    await load();
  }

  Future<void> delete(int id) async {
    await _useCase.delete(id);
    await load();
  }
}
