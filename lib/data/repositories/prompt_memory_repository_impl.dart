import 'package:sqflite/sqflite.dart';
import 'package:nai_huishi/data/models/prompt_memory_model.dart';
import 'package:nai_huishi/domain/entities/prompt_memory.dart';
import 'package:nai_huishi/domain/repositories/prompt_memory_repository.dart';

class PromptMemoryRepositoryImpl implements PromptMemoryRepository {
  final Database _db;
  static const String _table = 'prompt_memories';

  PromptMemoryRepositoryImpl(this._db);

  @override
  Future<List<PromptMemory>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'updated_at DESC');
    return rows.map(PromptMemoryModel.fromDb).toList();
  }

  @override
  Future<List<PromptMemory>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return getAll();
    final rows = await _db.query(
      _table,
      where: 'trigger LIKE ? OR content LIKE ?',
      whereArgs: ['%$q%', '%$q%'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(PromptMemoryModel.fromDb).toList();
  }

  @override
  Future<List<PromptMemory>> matchText(String text) async {
    final source = text.toLowerCase();
    final all = await getAll();
    final matched = all.where((m) {
      final trigger = m.trigger.trim().toLowerCase();
      return trigger.isNotEmpty && source.contains(trigger);
    }).toList();
    matched.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return matched;
  }

  @override
  Future<PromptMemory> save(PromptMemory memory) async {
    final now = DateTime.now();
    final normalized = memory.copyWith(
      trigger: memory.trigger.trim(),
      content: memory.content.trim(),
      updatedAt: now,
    );

    if (normalized.id != null) {
      await _db.update(
        _table,
        PromptMemoryModel.toDb(normalized),
        where: 'id = ?',
        whereArgs: [normalized.id],
      );
      return normalized;
    }

    final existing = await _db.query(
      _table,
      where: 'trigger = ?',
      whereArgs: [normalized.trigger],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      final updated = normalized.copyWith(id: id);
      await _db.update(
        _table,
        PromptMemoryModel.toDb(updated),
        where: 'id = ?',
        whereArgs: [id],
      );
      return updated;
    }

    final created = normalized.copyWith(createdAt: now, updatedAt: now);
    final id = await _db.insert(_table, PromptMemoryModel.toDb(created));
    return created.copyWith(id: id);
  }

  @override
  Future<void> delete(int id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }
}
