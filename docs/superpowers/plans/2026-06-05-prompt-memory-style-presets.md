# Prompt Memory and Style Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为提示词辅助助手增加本地学习记忆、画风画师串收藏、紧凑工具栏、配置联动和历史空态。

**Architecture:** 使用现有 Clean Architecture 分层：domain entities/repositories/usecases、data repository + SQLite、presentation viewmodel + page/widget。学习记忆和画风收藏都进入 SQLite；聊天输入栏由 `ChatDrawer` 持有输入控制器，以便收藏详情一键插入文本。

**Tech Stack:** Flutter/Dart, sqflite, get_it, image_picker, image package, path_provider, existing ChangeNotifier viewmodels.

---

## File Structure

### Create

- `lib/domain/entities/prompt_memory.dart`：学习记忆实体。
- `lib/domain/entities/style_preset.dart`：画风收藏实体。
- `lib/domain/repositories/prompt_memory_repository.dart`：学习记忆仓库接口。
- `lib/domain/repositories/style_preset_repository.dart`：画风收藏仓库接口。
- `lib/data/models/prompt_memory_model.dart`：SQLite row 映射。
- `lib/data/models/style_preset_model.dart`：SQLite row 映射。
- `lib/data/repositories/prompt_memory_repository_impl.dart`：学习记忆 SQLite 实现。
- `lib/data/repositories/style_preset_repository_impl.dart`：画风收藏 SQLite + 图片压缩实现。
- `lib/domain/usecases/manage_prompt_memories.dart`：学习记忆用例。
- `lib/domain/usecases/manage_style_presets.dart`：画风收藏用例。
- `lib/presentation/viewmodels/prompt_memory_viewmodel.dart`：记忆管理页面状态。
- `lib/presentation/viewmodels/style_preset_viewmodel.dart`：收藏页面状态。
- `lib/presentation/pages/prompt_memory_page.dart`：记忆管理页。
- `lib/presentation/pages/style_preset_page.dart`：收藏列表页。
- `lib/presentation/pages/style_preset_detail_page.dart`：收藏详情页。

### Modify

- `lib/core/constants/app_constants.dart`：数据库版本从 4 升到 5；新增图片目录名。
- `lib/data/datasources/local/database_helper.dart`：创建 `prompt_memories`、`style_presets` 表及索引；升级逻辑。
- `lib/core/di/injection.dart`：注册仓库、用例、viewmodel。
- `lib/presentation/viewmodels/llm_chat_viewmodel.dart`：命中记忆并注入系统 prompt；解析显式记忆指令。
- `lib/presentation/widgets/llm_chat/chat_drawer.dart`：顶部改工具栏，新增收藏/记忆入口，持有输入 controller 并传给输入栏。
- `lib/presentation/widgets/llm_chat/chat_input_bar.dart`：允许外部传入 `TextEditingController`，提供插入收藏串能力。
- `lib/presentation/widgets/llm_chat/chat_settings_sheet.dart`：点击“切换到此配置”时同步 `_composeProfileIndex = i`。
- `lib/presentation/pages/history_page.dart`：新增空态文案和“去创作”按钮。

---

## Task 1: SQLite schema and entities

**Files:**
- Modify: `lib/core/constants/app_constants.dart`
- Modify: `lib/data/datasources/local/database_helper.dart`
- Create: `lib/domain/entities/prompt_memory.dart`
- Create: `lib/domain/entities/style_preset.dart`
- Create: `lib/data/models/prompt_memory_model.dart`
- Create: `lib/data/models/style_preset_model.dart`

- [ ] **Step 1: Update constants**

In `lib/core/constants/app_constants.dart`:

```dart
static const int dbVersion = 5;
static const String stylePresetsDirName = 'style_presets';
```

Keep `stylePresetsDirName` near `imagesDirName`.

- [ ] **Step 2: Add entities**

Create `lib/domain/entities/prompt_memory.dart`:

```dart
import 'package:equatable/equatable.dart';

enum PromptMemoryType { characterName, characterFeature, style, other }
enum PromptMemorySource { manual, userInstruction, llmCandidate }

class PromptMemory extends Equatable {
  final int? id;
  final String trigger;
  final String content;
  final PromptMemoryType type;
  final PromptMemorySource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PromptMemory({
    this.id,
    required this.trigger,
    required this.content,
    required this.type,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  PromptMemory copyWith({
    int? id,
    String? trigger,
    String? content,
    PromptMemoryType? type,
    PromptMemorySource? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromptMemory(
      id: id ?? this.id,
      trigger: trigger ?? this.trigger,
      content: content ?? this.content,
      type: type ?? this.type,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, trigger, content, type, source, createdAt, updatedAt];
}
```

Create `lib/domain/entities/style_preset.dart`:

```dart
import 'package:equatable/equatable.dart';

class StylePreset extends Equatable {
  final int? id;
  final String title;
  final String prompt;
  final String imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StylePreset({
    this.id,
    required this.title,
    required this.prompt,
    required this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  StylePreset copyWith({
    int? id,
    String? title,
    String? prompt,
    String? imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StylePreset(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, prompt, imagePath, createdAt, updatedAt];
}
```

- [ ] **Step 3: Add models**

Create `lib/data/models/prompt_memory_model.dart`:

```dart
import 'package:nai_huishi/domain/entities/prompt_memory.dart';

class PromptMemoryModel {
  static Map<String, dynamic> toDb(PromptMemory memory) => {
        'id': memory.id,
        'trigger': memory.trigger,
        'content': memory.content,
        'type': memory.type.name,
        'source': memory.source.name,
        'created_at': memory.createdAt.millisecondsSinceEpoch,
        'updated_at': memory.updatedAt.millisecondsSinceEpoch,
      };

  static PromptMemory fromDb(Map<String, dynamic> row) => PromptMemory(
        id: row['id'] as int?,
        trigger: row['trigger'] as String,
        content: row['content'] as String,
        type: PromptMemoryType.values.firstWhere(
          (e) => e.name == row['type'],
          orElse: () => PromptMemoryType.other,
        ),
        source: PromptMemorySource.values.firstWhere(
          (e) => e.name == row['source'],
          orElse: () => PromptMemorySource.manual,
        ),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      );
}
```

Create `lib/data/models/style_preset_model.dart`:

```dart
import 'package:nai_huishi/domain/entities/style_preset.dart';

class StylePresetModel {
  static Map<String, dynamic> toDb(StylePreset preset) => {
        'id': preset.id,
        'title': preset.title,
        'prompt': preset.prompt,
        'image_path': preset.imagePath,
        'created_at': preset.createdAt.millisecondsSinceEpoch,
        'updated_at': preset.updatedAt.millisecondsSinceEpoch,
      };

  static StylePreset fromDb(Map<String, dynamic> row) => StylePreset(
        id: row['id'] as int?,
        title: row['title'] as String,
        prompt: row['prompt'] as String,
        imagePath: row['image_path'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      );
}
```

- [ ] **Step 4: Add database tables**

In `lib/data/datasources/local/database_helper.dart`, add `_createPromptAssistantTables`:

```dart
Future<void> _createPromptAssistantTables(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS prompt_memories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trigger TEXT NOT NULL,
      content TEXT NOT NULL,
      type TEXT NOT NULL,
      source TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_prompt_memories_trigger ON prompt_memories(trigger)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_prompt_memories_updated ON prompt_memories(updated_at)');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS style_presets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      prompt TEXT NOT NULL,
      image_path TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_style_presets_updated ON style_presets(updated_at)');
}
```

Call it at the end of `_onCreate` after `_createLlmTables(db);`:

```dart
await _createPromptAssistantTables(db);
```

Add to `_onUpgrade`:

```dart
if (oldVersion < 5) {
  await _createPromptAssistantTables(db);
}
```

- [ ] **Step 5: Verify static analysis for this task**

Run:

```bash
cd "C:/Users/Elysia/Desktop/nai 绘世" && flutter analyze
```

Expected: no new errors from created files.

---

## Task 2: Repositories, usecases, and DI

**Files:**
- Create: `lib/domain/repositories/prompt_memory_repository.dart`
- Create: `lib/domain/repositories/style_preset_repository.dart`
- Create: `lib/data/repositories/prompt_memory_repository_impl.dart`
- Create: `lib/data/repositories/style_preset_repository_impl.dart`
- Create: `lib/domain/usecases/manage_prompt_memories.dart`
- Create: `lib/domain/usecases/manage_style_presets.dart`
- Modify: `lib/core/di/injection.dart`

- [ ] **Step 1: Add repository interfaces**

Create `lib/domain/repositories/prompt_memory_repository.dart`:

```dart
import 'package:nai_huishi/domain/entities/prompt_memory.dart';

abstract class PromptMemoryRepository {
  Future<List<PromptMemory>> getAll();
  Future<List<PromptMemory>> search(String query);
  Future<List<PromptMemory>> matchText(String text);
  Future<PromptMemory> save(PromptMemory memory);
  Future<void> delete(int id);
}
```

Create `lib/domain/repositories/style_preset_repository.dart`:

```dart
import 'package:nai_huishi/domain/entities/style_preset.dart';

abstract class StylePresetRepository {
  Future<List<StylePreset>> getAll();
  Future<StylePreset> createFromImage({required String title, required String prompt, required String sourceImagePath});
  Future<StylePreset> update(StylePreset preset);
  Future<void> delete(int id);
}
```

- [ ] **Step 2: Add repository implementations**

Create `lib/data/repositories/prompt_memory_repository_impl.dart`:

```dart
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
      createdAt: memory.createdAt,
    );

    final existing = await _db.query(
      _table,
      where: 'trigger = ?',
      whereArgs: [normalized.trigger],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final id = existing.first['id'] as int;
      final updated = normalized.copyWith(id: id);
      await _db.update(_table, PromptMemoryModel.toDb(updated), where: 'id = ?', whereArgs: [id]);
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
```

Create `lib/data/repositories/style_preset_repository_impl.dart`:

```dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:nai_huishi/core/constants/app_constants.dart';
import 'package:nai_huishi/data/models/style_preset_model.dart';
import 'package:nai_huishi/domain/entities/style_preset.dart';
import 'package:nai_huishi/domain/repositories/style_preset_repository.dart';

class StylePresetRepositoryImpl implements StylePresetRepository {
  final Database _db;
  static const String _table = 'style_presets';
  static const _uuid = Uuid();

  StylePresetRepositoryImpl(this._db);

  @override
  Future<List<StylePreset>> getAll() async {
    final rows = await _db.query(_table, orderBy: 'updated_at DESC');
    return rows.map(StylePresetModel.fromDb).toList();
  }

  @override
  Future<StylePreset> createFromImage({required String title, required String prompt, required String sourceImagePath}) async {
    final savedPath = await _compressAndSave(sourceImagePath);
    final now = DateTime.now();
    final preset = StylePreset(
      title: title.trim(),
      prompt: prompt.trim(),
      imagePath: savedPath,
      createdAt: now,
      updatedAt: now,
    );
    final id = await _db.insert(_table, StylePresetModel.toDb(preset));
    return preset.copyWith(id: id);
  }

  @override
  Future<StylePreset> update(StylePreset preset) async {
    final updated = preset.copyWith(
      title: preset.title.trim(),
      prompt: preset.prompt.trim(),
      updatedAt: DateTime.now(),
    );
    await _db.update(_table, StylePresetModel.toDb(updated), where: 'id = ?', whereArgs: [updated.id]);
    return updated;
  }

  @override
  Future<void> delete(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) {
      final imagePath = rows.first['image_path'] as String;
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _db.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<String> _compressAndSave(String sourceImagePath) async {
    final bytes = await File(sourceImagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('图片格式无法读取');

    final resized = decoded.width > 1080 ? img.copyResize(decoded, width: 1080) : decoded;
    final jpg = img.encodeJpg(resized, quality: 82);

    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, AppConstants.stylePresetsDirName));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final targetPath = p.join(targetDir.path, '${_uuid.v4()}.jpg');
    await File(targetPath).writeAsBytes(jpg);
    return targetPath;
  }
}
```

- [ ] **Step 3: Add usecases**

Create `lib/domain/usecases/manage_prompt_memories.dart`:

```dart
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
```

Create `lib/domain/usecases/manage_style_presets.dart`:

```dart
import 'package:nai_huishi/domain/entities/style_preset.dart';
import 'package:nai_huishi/domain/repositories/style_preset_repository.dart';

class ManageStylePresetsUseCase {
  final StylePresetRepository _repo;

  ManageStylePresetsUseCase(this._repo);

  Future<List<StylePreset>> getAll() => _repo.getAll();
  Future<StylePreset> createFromImage({required String title, required String prompt, required String sourceImagePath}) =>
      _repo.createFromImage(title: title, prompt: prompt, sourceImagePath: sourceImagePath);
  Future<StylePreset> update(StylePreset preset) => _repo.update(preset);
  Future<void> delete(int id) => _repo.delete(id);
}
```

- [ ] **Step 4: Register DI**

In `lib/core/di/injection.dart`, import the new files and register:

```dart
sl.registerSingleton<PromptMemoryRepository>(PromptMemoryRepositoryImpl(sl<Database>()));
sl.registerSingleton<StylePresetRepository>(StylePresetRepositoryImpl(sl<Database>()));
sl.registerSingleton<ManagePromptMemoriesUseCase>(ManagePromptMemoriesUseCase(sl<PromptMemoryRepository>()));
sl.registerSingleton<ManageStylePresetsUseCase>(ManageStylePresetsUseCase(sl<StylePresetRepository>()));
sl.registerFactory<PromptMemoryViewModel>(() => PromptMemoryViewModel(sl<ManagePromptMemoriesUseCase>()));
sl.registerFactory<StylePresetViewModel>(() => StylePresetViewModel(sl<ManageStylePresetsUseCase>()));
```

ViewModel classes are created in Task 4; add imports after those files exist.

- [ ] **Step 5: Verify analysis**

Run:

```bash
cd "C:/Users/Elysia/Desktop/nai 绘世" && flutter analyze
```

Expected: no undefined repository/usecase symbols after Task 4 viewmodels are added; before Task 4, temporary viewmodel import errors are expected if imports were added early.

---

## Task 3: Inject prompt memories into LLM chat

**Files:**
- Modify: `lib/presentation/viewmodels/llm_chat_viewmodel.dart`
- Modify: `lib/core/di/injection.dart`

- [ ] **Step 1: Extend constructor dependency**

Add import:

```dart
import 'package:nai_huishi/domain/entities/prompt_memory.dart';
import 'package:nai_huishi/domain/usecases/manage_prompt_memories.dart';
```

Add field:

```dart
final ManagePromptMemoriesUseCase _memories;
```

Constructor adds:

```dart
required ManagePromptMemoriesUseCase memories,
```

and assigns:

```dart
_memories = memories;
```

Update DI factory:

```dart
memories: sl<ManagePromptMemoriesUseCase>(),
```

- [ ] **Step 2: Add explicit instruction parser**

Add method to `LlmChatViewModel`:

```dart
Future<void> _captureExplicitMemoryInstruction(String text) async {
  final trimmed = text.trim();
  final patterns = [
    RegExp(r'^记住[:：](.+)$'),
    RegExp(r'^纠正[:：](.+)$'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(trimmed);
    if (match == null) continue;
    final body = match.group(1)?.trim() ?? '';
    final parts = body.split(RegExp(r'应该是|应为|=|：|:'));
    if (parts.length < 2) return;
    final trigger = parts.first.trim();
    final content = parts.sublist(1).join('应该是').trim();
    if (trigger.isEmpty || content.isEmpty) return;
    final now = DateTime.now();
    await _memories.save(PromptMemory(
      trigger: trigger,
      content: content,
      type: PromptMemoryType.other,
      source: PromptMemorySource.userInstruction,
      createdAt: now,
      updatedAt: now,
    ));
    return;
  }
}
```

- [ ] **Step 3: Add memory prompt builder**

Add method:

```dart
Future<String> _buildMemoryContext(String userText) async {
  final matched = await _memories.matchText(userText);
  if (matched.isEmpty) return '';
  final lines = matched.take(12).map((m) => '- ${m.trigger}：${m.content}').join('\n');
  return '\n\n## 本地学习记忆（最高优先级）\n'
      '以下内容来自用户纠正或手动记录。若它与 Danbooru、模型常识或检索结果冲突，必须以这里为准：\n'
      '$lines';
}
```

- [ ] **Step 4: Call parser and inject context**

Near the start of `sendUserMessage`, after trimmed text is available, call:

```dart
await _captureExplicitMemoryInstruction(trimmed);
final memoryContext = await _buildMemoryContext(trimmed);
```

Where the single-shot or compose system prompt is passed, append `memoryContext` to the existing system prompt. Do not inject if `memoryContext.isEmpty`.

Implementation pattern:

```dart
final effectiveSystemPrompt = memoryContext.isEmpty
    ? _systemPrompt
    : '$_systemPrompt$memoryContext';
```

Use `effectiveSystemPrompt` for the LLM call in legacy and Danbooru compose paths.

- [ ] **Step 5: Verify manual scenario**

Run app, send:

```text
记住：测试角色 应该是 银发蓝眼
```

Then send:

```text
测试角色站着
```

Expected: generated prompt context includes “测试角色：银发蓝眼”; no crash.

---

## Task 4: Prompt memory management page

**Files:**
- Create: `lib/presentation/viewmodels/prompt_memory_viewmodel.dart`
- Create: `lib/presentation/pages/prompt_memory_page.dart`

- [ ] **Step 1: Add viewmodel**

Create `lib/presentation/viewmodels/prompt_memory_viewmodel.dart`:

```dart
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

  Future<void> save({int? id, required String trigger, required String content, PromptMemoryType type = PromptMemoryType.other}) async {
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
```

- [ ] **Step 2: Add page**

Create a `PromptMemoryPage` with:

- AppBar title `学习记忆`
- Search TextField
- List cards showing `trigger` and `content`
- Add button opens dialog with trigger/content fields
- Existing card edit opens same dialog
- Delete button removes row

Use `sl<PromptMemoryViewModel>()`, call `load()` in `initState`, and listen via `addListener`.

- [ ] **Step 3: Verify page**

Run app, open page from ChatDrawer after Task 7 wiring. Add one memory, edit it, delete it.

Expected: list updates immediately.

---

## Task 5: Style preset pages and viewmodel

**Files:**
- Create: `lib/presentation/viewmodels/style_preset_viewmodel.dart`
- Create: `lib/presentation/pages/style_preset_page.dart`
- Create: `lib/presentation/pages/style_preset_detail_page.dart`

- [ ] **Step 1: Add viewmodel**

Create `lib/presentation/viewmodels/style_preset_viewmodel.dart`:

```dart
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

  Future<void> create({required String title, required String prompt, required String sourceImagePath}) async {
    await _useCase.createFromImage(title: title, prompt: prompt, sourceImagePath: sourceImagePath);
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
```

- [ ] **Step 2: Add list page**

Create `StylePresetPage` with constructor:

```dart
final void Function(String prompt) onApplyPrompt;
```

UI requirements:

- AppBar title `画风收藏`
- Add button uses `ImagePicker().pickImage(source: ImageSource.gallery)`
- After picking, show dialog for title and prompt
- GridView two columns like `HistoryPage`
- Card image uses `Image.file(File(preset.imagePath), fit: BoxFit.cover)` if exists, otherwise placeholder icon
- Tap card opens `StylePresetDetailPage`

- [ ] **Step 3: Add detail page**

Create `StylePresetDetailPage` with:

```dart
final StylePreset preset;
final StylePresetViewModel vm;
final void Function(String prompt) onApplyPrompt;
```

UI requirements:

- Large image at top, tap can use `InteractiveViewer`
- Shows full prompt in selectable text
- Buttons: `添加到对话栏`, `编辑`, `删除`
- `添加到对话栏` calls `onApplyPrompt(preset.prompt)` then pops back to ChatDrawer using `Navigator.popUntil` enough to leave collection page. Simpler: call callback and `Navigator.of(context).pop()` twice from list/detail flow.

- [ ] **Step 4: Verify add/apply/delete**

Expected:

- Chosen image is compressed and copied.
- Card appears.
- Detail can add prompt into chat input.
- Delete removes card and local image file.

---

## Task 6: Chat input controller and compact toolbar

**Files:**
- Modify: `lib/presentation/widgets/llm_chat/chat_input_bar.dart`
- Modify: `lib/presentation/widgets/llm_chat/chat_drawer.dart`

- [ ] **Step 1: Allow external controller**

In `ChatInputBar`, add optional parameter:

```dart
final TextEditingController? controller;
```

Change state field:

```dart
late final TextEditingController _controller;
bool _ownsController = false;
```

In `initState`:

```dart
_controller = widget.controller ?? TextEditingController();
_ownsController = widget.controller == null;
_controller.addListener(_onTextChanged);
```

Add method:

```dart
void _onTextChanged() {
  final has = _controller.text.trim().isNotEmpty;
  if (has != _hasText) setState(() => _hasText = has);
}
```

In `dispose`:

```dart
_controller.removeListener(_onTextChanged);
if (_ownsController) _controller.dispose();
```

- [ ] **Step 2: Move controller to ChatDrawer**

In `ChatDrawer` state add:

```dart
final TextEditingController _inputController = TextEditingController();
```

Dispose it.

Pass to `ChatInputBar(controller: _inputController, ...)`.

Add method:

```dart
void _insertIntoInput(String text) {
  final current = _inputController.text.trim();
  _inputController.text = current.isEmpty ? text : '$current, $text';
  _inputController.selection = TextSelection.collapsed(offset: _inputController.text.length);
}
```

- [ ] **Step 3: Replace top bar**

In `_buildTopBar`, remove the `Expanded(Column(...提示词辅助写手...))` and build icon-only row:

- list button
- style preset button `CupertinoIcons.square_grid_2x2`
- memory button `CupertinoIcons.book`
- spacer
- new session
- settings
- close

Style preset button opens `StylePresetPage(onApplyPrompt: _insertIntoInput)`.
Memory button opens `PromptMemoryPage()`.

- [ ] **Step 4: Verify toolbar height**

Expected: no title text, one compact row, all buttons still clickable.

---

## Task 7: Settings profile switch follows compose profile

**Files:**
- Modify: `lib/presentation/widgets/llm_chat/chat_settings_sheet.dart`

- [ ] **Step 1: Update button handler**

In `_buildProfileTab`, change “切换到此配置” handler to:

```dart
onPressed: () async {
  await widget.vm.switchProfile(i);
  setState(() {
    _composeProfileIndex = i;
  });
},
```

- [ ] **Step 2: Verify persistence**

Open settings, click profile 2 “切换到此配置”, click 保存, reopen settings.

Expected: 提示词编排模型 dropdown shows profile 2; 关键词抽取模型 unchanged.

---

## Task 8: History empty state

**Files:**
- Modify: `lib/presentation/pages/history_page.dart`

- [ ] **Step 1: Add empty state branch**

In `body`, before `RefreshIndicator`, if `!_vm.isLoading && _vm.history.isEmpty`, render:

```dart
Center(
  child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(CupertinoIcons.sparkles, size: 42, color: Colors.white38),
        const SizedBox(height: 14),
        const Text(
          '请去创造更多美好回忆吧！',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: widget.onNavigate == null ? null : () => widget.onNavigate!(1),
          child: const Text('去创作'),
        ),
      ],
    ),
  ),
)
```

- [ ] **Step 2: Verify empty DB scenario**

Clear history, open history page.

Expected: text and “去创作” button appear; button navigates to Generate page.

---

## Task 9: End-to-end verification and APK build

**Files:**
- No code changes unless fixing issues found during verification.

- [ ] **Step 1: Analyze**

Run:

```bash
cd "C:/Users/Elysia/Desktop/nai 绘世" && flutter analyze
```

Expected: no errors. Existing warnings may remain if unrelated.

- [ ] **Step 2: Sync to non-Chinese build path**

Run:

```bash
rm -rf "C:/Users/Elysia/nai_huishi_build/lib" && cp -r "C:/Users/Elysia/Desktop/nai 绘世/lib" "C:/Users/Elysia/nai_huishi_build/lib"
```

- [ ] **Step 3: Clean and build APK**

Run:

```bash
cd "C:/Users/Elysia/nai_huishi_build" && flutter clean && flutter build apk --release
```

Expected: `Built build\app\outputs\flutter-apk\app-release.apk`.

- [ ] **Step 4: Copy APK to required output directory**

Run:

```bash
cp "C:/Users/Elysia/nai_huishi_build/build/app/outputs/flutter-apk/app-release.apk" "C:/Users/Elysia/Desktop/绘世/app-release.apk"
```

- [ ] **Step 5: Manual smoke tests**

Verify:

1. 配置切换同步提示词编排模型。
2. 手动学习记忆新增/编辑/删除可用。
3. “记住/纠正”指令能写入记忆。
4. 命中记忆后提示词辅助以本地记忆为准。
5. 画风收藏可从相册新增，图片被压缩保存。
6. 收藏详情一键添加到对话栏。
7. 聊天抽屉顶部工具栏紧凑且无标题。
8. 历史空态显示“请去创造更多美好回忆吧！”和“去创作”。

---

## Self-Review

- Spec coverage: 已覆盖配置联动、学习记忆、聊天顶部删除标题、画风收藏、历史空态、APK 构建复制。
- Placeholder scan: 无 TBD/TODO；Task 4/5 的 UI 细节允许实现者按现有 Flutter 样式完成，但必须满足列出的具体控件和行为。
- Type consistency: `PromptMemory`、`StylePreset`、repository/usecase/viewmodel 命名在各任务中一致。
