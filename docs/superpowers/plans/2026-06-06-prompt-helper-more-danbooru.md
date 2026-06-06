# 提示词助手结构化替换与更多页 Danbooru 查词 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复提示词助手一键替换的结构化识别，新增更多页 Danbooru 查词，并让 App 默认进入生成页。

**Architecture:** 将提示词聚合解析从 UI widget 中拆到独立 parser，优先解析 JSON，失败时复用现有代码块标签逻辑。Danbooru 查词页面直接依赖已注册的 `DanbooruApiService`，作为更多页入口打开，不经过 LLM。首页只调整初始 tab 与展示文案，不改变页面栈结构。

**Tech Stack:** Flutter / Dart, Material + Cupertino widgets, `flutter_test`, existing `get_it` DI, existing `DanbooruApiService`.

---

## File Structure

- Create: `lib/presentation/widgets/llm_chat/prompt_apply_parser.dart`
  - 负责 `_Segment`、`AppliedSegments`、JSON/代码块解析、标签判断工具函数。
  - 从 `chat_message_bubble.dart` 拆出可测试的纯 Dart 逻辑。
- Modify: `lib/presentation/widgets/llm_chat/chat_message_bubble.dart`
  - 删除内联 parser，导入 `prompt_apply_parser.dart`。
  - UI 按钮行为保持不变。
- Create: `test/prompt_apply_parser_test.dart`
  - 覆盖 JSON 代码块、裸 JSON、多角色、缺字段、旧格式兜底。
- Modify: `lib/core/constants/app_constants.dart`
  - 更新 `defaultLlmSystemPrompt` 输出格式部分，要求优先输出 JSON 代码块。
- Create: `lib/presentation/pages/danbooru_tag_search_page.dart`
  - 直接搜索 Danbooru tag 并展示结果。
- Modify: `lib/presentation/pages/settings_page.dart`
  - 页面标题“设置”改“更多”。
  - 更多功能组新增“Danbooru 查词”入口。
- Modify: `lib/presentation/pages/home_page.dart`
  - 默认 `_currentIndex = 1`。
  - 底部导航文案“设置”改“更多”，图标不变。

---

### Task 1: 拆出提示词解析器并补测试

**Files:**
- Create: `lib/presentation/widgets/llm_chat/prompt_apply_parser.dart`
- Modify: `lib/presentation/widgets/llm_chat/chat_message_bubble.dart`
- Test: `test/prompt_apply_parser_test.dart`

- [ ] **Step 1: 写失败测试**

Create `test/prompt_apply_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_huishi/presentation/widgets/llm_chat/prompt_apply_parser.dart';

void main() {
  group('parseAppliedSegments', () {
    test('parses json code block first', () {
      final result = parseAppliedSegments('''
说明文字
```json
{
  "positive": "masterpiece, 1girl",
  "negative": "low quality",
  "characters": [
    {"positive": "pink hair", "negative": "extra fingers"},
    {"positive": "blue eyes"}
  ]
}
```
''');

      expect(result.positive, 'masterpiece, 1girl');
      expect(result.negative, 'low quality');
      expect(result.characterPrompts, ['pink hair', 'blue eyes']);
      expect(result.characterNegatives, ['extra fingers', '']);
    });

    test('parses bare json', () {
      final result = parseAppliedSegments('''{
        "positive": "best quality",
        "characters": [{"positive": "1girl"}]
      }''');

      expect(result.positive, 'best quality');
      expect(result.negative, isNull);
      expect(result.characterPrompts, ['1girl']);
      expect(result.characterNegatives, ['']);
    });

    test('ignores missing json fields without failing', () {
      final result = parseAppliedSegments('''```json
{"negative":"bad anatomy","characters":[{"negative":"bad hands"}]}
```''');

      expect(result.positive, isNull);
      expect(result.negative, 'bad anatomy');
      expect(result.characterPrompts, ['']);
      expect(result.characterNegatives, ['bad hands']);
    });

    test('falls back to labelled code blocks', () {
      final result = parseAppliedSegments('''
正向：
```
masterpiece
```
角色1：
```
pink hair
```
角色1负向：
```
extra fingers
```
负向：
```
low quality
```
''');

      expect(result.positive, 'masterpiece');
      expect(result.negative, 'low quality');
      expect(result.characterPrompts, ['pink hair']);
      expect(result.characterNegatives, ['extra fingers']);
    });

    test('empty when neither json nor labelled code blocks are usable', () {
      final result = parseAppliedSegments('plain explanation only');

      expect(result.isEmpty, isTrue);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```bash
flutter test test/prompt_apply_parser_test.dart
```

Expected: FAIL because `prompt_apply_parser.dart` does not exist.

- [ ] **Step 3: 创建 parser 最小实现**

Create `lib/presentation/widgets/llm_chat/prompt_apply_parser.dart`:

```dart
import 'dart:convert';

final _codeBlockRegex = RegExp(r'```([a-zA-Z0-9_+\-]*)\s*\n([\s\S]*?)```');

class PromptSegment {
  final bool isCode;
  final String text;
  final String lang;
  final String label;

  const PromptSegment.text(this.text)
      : isCode = false,
        lang = '',
        label = '';

  const PromptSegment.code(this.text, this.lang, this.label) : isCode = true;
}

class AppliedSegments {
  final String? positive;
  final String? negative;
  final List<String> characterPrompts;
  final List<String> characterNegatives;

  const AppliedSegments({
    this.positive,
    this.negative,
    required this.characterPrompts,
    required this.characterNegatives,
  });

  bool get isEmpty =>
      (positive == null || positive!.isEmpty) &&
      (negative == null || negative!.isEmpty) &&
      characterPrompts.every((e) => e.isEmpty) &&
      characterNegatives.every((e) => e.isEmpty);
}

bool isCharacterLabel(String label) {
  if (label.isEmpty) return false;
  return label.contains('角色');
}

bool isNegativeLabel(String label) {
  if (label.isEmpty) return false;
  return label.contains('负向') || label.contains('负面');
}

bool isPositiveLabel(String label) {
  if (label.isEmpty) return false;
  if (isNegativeLabel(label)) return false;
  if (isCharacterLabel(label)) return false;
  return label.contains('正向') ||
      label.contains('正面') ||
      label.contains('底模') ||
      label.contains('通用');
}

int? _characterIndex(String label) {
  final match = RegExp(r'角色\s*(\d+)').firstMatch(label);
  if (match == null) return null;
  final n = int.tryParse(match.group(1) ?? '');
  if (n == null || n <= 0) return null;
  return n - 1;
}

AppliedSegments parseAppliedSegments(String content) {
  final structured = _parseStructuredJson(content);
  if (structured != null && !structured.isEmpty) return structured;
  return _aggregateSegments(splitPromptContent(content));
}

List<PromptSegment> splitPromptContent(String content) {
  final segments = <PromptSegment>[];
  int cursor = 0;
  String pendingLabel = '';

  for (final match in _codeBlockRegex.allMatches(content)) {
    if (match.start > cursor) {
      final text = content.substring(cursor, match.start);
      if (text.trim().isNotEmpty) {
        pendingLabel = extractPromptLabel(text);
        segments.add(PromptSegment.text(text));
      }
    }
    segments.add(PromptSegment.code(
      (match.group(2) ?? '').trim(),
      match.group(1) ?? '',
      pendingLabel,
    ));
    pendingLabel = '';
    cursor = match.end;
  }
  if (cursor < content.length) {
    final tail = content.substring(cursor);
    if (tail.trim().isNotEmpty) segments.add(PromptSegment.text(tail));
  }
  if (segments.isEmpty && content.trim().isNotEmpty) {
    segments.add(PromptSegment.text(content));
  }
  return segments;
}

String extractPromptLabel(String textBefore) {
  final lines = textBefore.trimRight().split('\n');
  for (int i = lines.length - 1; i >= 0; i--) {
    var line = lines[i].trim();
    if (line.isEmpty) continue;
    line = line
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'_+'), '')
        .replaceAll(RegExp(r'`+'), '')
        .replaceAll(RegExp(r'^[#\-\>\s]+'), '')
        .trim();
    if (line.isEmpty) continue;
    final match = RegExp(r'^[\s]*([\u4e00-\u9fff\d\s]+?)[\s]*[：:]').firstMatch(line);
    if (match != null) return match.group(1)!.trim();
    if (RegExp(r'^[\s]*[\u4e00-\u9fff\d\s]+[\s]*$').hasMatch(line)) {
      return line.trim();
    }
    break;
  }
  return '';
}

AppliedSegments _aggregateSegments(List<PromptSegment> segments) {
  String? positive;
  String? negative;
  final charPrompts = <int, String>{};
  final charNegatives = <int, String>{};

  for (final seg in segments) {
    if (!seg.isCode || seg.text.trim().isEmpty) continue;
    final label = seg.label;
    final text = seg.text.trim();
    final charIdx = _characterIndex(label);
    if (charIdx != null) {
      if (isNegativeLabel(label)) {
        charNegatives[charIdx] = text;
      } else {
        charPrompts[charIdx] = text;
      }
      continue;
    }
    if (isNegativeLabel(label)) {
      negative = negative == null ? text : '$negative, $text';
      continue;
    }
    if (isPositiveLabel(label)) {
      positive = positive == null ? text : '$positive, $text';
      continue;
    }
  }

  final maxIdx = [...charPrompts.keys, ...charNegatives.keys]
      .fold<int>(-1, (a, b) => b > a ? b : a);
  final promptsList = <String>[];
  final negativesList = <String>[];
  for (int i = 0; i <= maxIdx; i++) {
    promptsList.add(charPrompts[i] ?? '');
    negativesList.add(charNegatives[i] ?? '');
  }

  return AppliedSegments(
    positive: positive,
    negative: negative,
    characterPrompts: promptsList,
    characterNegatives: negativesList,
  );
}

AppliedSegments? _parseStructuredJson(String content) {
  for (final match in _codeBlockRegex.allMatches(content)) {
    final lang = (match.group(1) ?? '').toLowerCase();
    if (lang == 'json') {
      final parsed = _decodeAppliedJson(match.group(2) ?? '');
      if (parsed != null) return parsed;
    }
  }
  return _decodeAppliedJson(content.trim());
}

AppliedSegments? _decodeAppliedJson(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final obj = decoded.cast<String, dynamic>();
    final positive = _stringOrNull(obj['positive']);
    final negative = _stringOrNull(obj['negative']);
    final charPrompts = <String>[];
    final charNegatives = <String>[];
    final characters = obj['characters'];
    if (characters is List) {
      for (final item in characters) {
        if (item is Map) {
          final map = item.cast<String, dynamic>();
          charPrompts.add(_stringOrEmpty(map['positive']));
          charNegatives.add(_stringOrEmpty(map['negative']));
        }
      }
    }
    return AppliedSegments(
      positive: positive,
      negative: negative,
      characterPrompts: charPrompts,
      characterNegatives: charNegatives,
    );
  } catch (_) {
    return null;
  }
}

String? _stringOrNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _stringOrEmpty(dynamic value) => _stringOrNull(value) ?? '';
```

- [ ] **Step 4: 修改 chat bubble 使用 parser**

Modify `lib/presentation/widgets/llm_chat/chat_message_bubble.dart`:

1. Add import:

```dart
import 'package:nai_huishi/presentation/widgets/llm_chat/prompt_apply_parser.dart';
```

2. Remove local definitions for:

```dart
_codeBlockRegex
_Segment
_isCharacterLabel
_isNegativeLabel
_isPositiveLabel
_characterIndex
AppliedSegments
_aggregateSegments
_splitContent
_extractLabel
```

3. Replace usages:

```dart
final segments = splitPromptContent(message.content);
final aggregated = isUser ? null : parseAppliedSegments(message.content);
```

4. Update `_CodeBlock` loop field type references:

```dart
for (final seg in segments)
```

No other UI changes.

- [ ] **Step 5: 运行 parser 测试确认通过**

Run:

```bash
flutter test test/prompt_apply_parser_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/presentation/widgets/llm_chat/prompt_apply_parser.dart lib/presentation/widgets/llm_chat/chat_message_bubble.dart test/prompt_apply_parser_test.dart
git commit -m "fix: parse structured prompt assistant output"
```

---

### Task 2: 更新 LLM 默认输出格式提示词

**Files:**
- Modify: `lib/core/constants/app_constants.dart:176-207`

- [ ] **Step 1: 检查现有 smoke test**

Run:

```bash
flutter test test/widget_test.dart
```

Expected before change may FAIL because current smoke test expects title text in initial route; if it fails, continue and fix in Task 4.

- [ ] **Step 2: 修改输出格式规范文案**

In `lib/core/constants/app_constants.dart`, replace the string section starting at line 176 (`'**八、输出格式规范...`) through the current final `注意：...代码块外面。';` with:

```dart
      '**八、输出格式规范（必须严格遵守）**\n'
      '\n'
      '你必须优先输出一个 json 代码块，所有可一键应用到生图页的内容都必须放进这个 JSON。JSON 外可以有简短中文对照，但不要把可应用 tag 只写在 JSON 外。\n'
      '\n'
      '单角色格式：\n'
      '```json\n'
      '{\n'
      '  "positive": "正向英文 tags，用半角逗号分隔",\n'
      '  "negative": "负向英文 tags，用半角逗号分隔",\n'
      '  "characters": []\n'
      '}\n'
      '```\n'
      '\n'
      '多角色格式：\n'
      '```json\n'
      '{\n'
      '  "positive": "通用底模词、画质词、环境、光影、构图等全局正向 tags",\n'
      '  "negative": "全局负向 tags",\n'
      '  "characters": [\n'
      '    {\n'
      '      "positive": "角色1的外貌、服装、动作 tags，含互动标签",\n'
      '      "negative": "角色1专属负向 tags，没有则留空字符串"\n'
      '    },\n'
      '    {\n'
      '      "positive": "角色2的外貌、服装、动作 tags，含互动标签",\n'
      '      "negative": "角色2专属负向 tags，没有则留空字符串"\n'
      '    }\n'
      '  ]\n'
      '}\n'
      '```\n'
      '\n'
      '字段规则：positive、negative、characters、characters[].positive、characters[].negative 必须使用英文 tag 字符串；没有内容时使用空字符串或空数组。禁止使用中文字段名。';
```

- [ ] **Step 3: 运行 parser 测试确认提示词修改未影响解析**

Run:

```bash
flutter test test/prompt_apply_parser_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/core/constants/app_constants.dart
git commit -m "chore: require structured prompt assistant output"
```

---

### Task 3: 新增 Danbooru 查词页面和更多页入口

**Files:**
- Create: `lib/presentation/pages/danbooru_tag_search_page.dart`
- Modify: `lib/presentation/pages/settings_page.dart`

- [ ] **Step 1: 创建页面 widget**

Create `lib/presentation/pages/danbooru_tag_search_page.dart`:

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_huishi/core/di/injection.dart';
import 'package:nai_huishi/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_huishi/domain/entities/danbooru_tag.dart';

class DanbooruTagSearchPage extends StatefulWidget {
  const DanbooruTagSearchPage({super.key});

  @override
  State<DanbooruTagSearchPage> createState() => _DanbooruTagSearchPageState();
}

class _DanbooruTagSearchPageState extends State<DanbooruTagSearchPage> {
  late final DanbooruApiService _api;
  late final TextEditingController _controller;
  List<DanbooruTag> _results = const [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void initState() {
    super.initState();
    _api = sl<DanbooruApiService>();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty || _loading) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await _api.search(
        query: query,
        topK: 5,
        limit: 30,
        showNsfw: true,
      );
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _error = 'Danbooru 查词失败：$e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _toNovelAiTag(String tag) => tag.replaceAll('_', ' ').trim();

  Future<void> _copyTag(DanbooruTag tag) async {
    await Clipboard.setData(ClipboardData(text: _toNovelAiTag(tag.tag)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制 tag')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danbooru 查词')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(CupertinoIcons.search),
                        hintText: '输入中文或英文关键词',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _loading ? null : _search,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('搜索'),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, height: 1.5),
          ),
        ),
      );
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (!_searched) {
      return const Center(
        child: Text('输入关键词后搜索 Danbooru 标签', style: TextStyle(color: Colors.white54)),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('没有找到相关 tag', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _results.length,
      itemBuilder: (context, index) => _TagCard(
        tag: _results[index],
        novelAiTag: _toNovelAiTag(_results[index].tag),
        onCopy: () => _copyTag(_results[index]),
      ),
    );
  }
}

class _TagCard extends StatelessWidget {
  final DanbooruTag tag;
  final String novelAiTag;
  final VoidCallback onCopy;

  const _TagCard({
    required this.tag,
    required this.novelAiTag,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (tag.cnName.isNotEmpty) tag.cnName,
      if (tag.category.isNotEmpty) tag.category,
      if (tag.nsfw.isNotEmpty) tag.nsfw,
      if (tag.count > 0) '热度 ${tag.count}',
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        novelAiTag,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        tag.tag,
                        style: const TextStyle(fontSize: 12, color: Colors.white54, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '复制 NovelAI tag',
                  onPressed: onCopy,
                  icon: const Icon(CupertinoIcons.doc_on_doc, size: 18),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
            if (tag.wiki.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                tag.wiki.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 添加更多页入口并改标题**

Modify `lib/presentation/pages/settings_page.dart`:

1. Add import:

```dart
import 'package:nai_huishi/presentation/pages/danbooru_tag_search_page.dart';
```

2. Change title text:

```dart
'更多',
```

3. Replace the current `const _SettingsGroup(title: '更多功能', ...)` with non-const group:

```dart
            _SettingsGroup(
              title: '更多功能',
              children: [
                _SettingsTile(
                  icon: CupertinoIcons.search,
                  title: 'Danbooru 查词',
                  subtitle: '直接搜索真实 Danbooru 标签',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute(builder: (_) => const DanbooruTagSearchPage()),
                  ),
                ),
              ],
            ),
```

- [ ] **Step 3: 运行静态分析**

Run:

```bash
flutter analyze
```

Expected: no new errors from `danbooru_tag_search_page.dart` or `settings_page.dart`.

- [ ] **Step 4: Commit**

```bash
git add lib/presentation/pages/danbooru_tag_search_page.dart lib/presentation/pages/settings_page.dart
git commit -m "feat: add Danbooru tag search page"
```

---

### Task 4: 改名为更多并默认进入生成页

**Files:**
- Modify: `lib/presentation/pages/home_page.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: 写/更新失败测试**

Modify `test/widget_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_huishi/presentation/app.dart';

void main() {
  testWidgets('app defaults to generate page and labels settings as more', (WidgetTester tester) async {
    await tester.pumpWidget(const NaiHuishiApp());
    await tester.pump();

    expect(find.text('生成'), findsWidgets);
    expect(find.text('更多'), findsWidgets);
    expect(find.text('设置'), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: FAIL because `HomePage` still starts at index 0 and bottom label still says “设置”.

- [ ] **Step 3: 修改 HomePage 默认页与底部文案**

Modify `lib/presentation/pages/home_page.dart`:

1. Change initial index:

```dart
  int _currentIndex = 1;
```

2. Change bottom nav label only:

```dart
              _buildNavItem(2, CupertinoIcons.settings, CupertinoIcons.settings_solid, '更多'),
```

- [ ] **Step 4: 运行测试确认通过**

Run:

```bash
flutter test test/widget_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/pages/home_page.dart test/widget_test.dart
git commit -m "fix: open generate page by default"
```

---

### Task 5: 全量验证、构建 APK、复制产物

**Files:**
- No source changes expected.
- Output copy target: `C:\Users\Elysia\Desktop\绘世`

- [ ] **Step 1: 运行全部测试**

Run:

```bash
flutter test
```

Expected: all tests PASS.

- [ ] **Step 2: 运行静态分析**

Run:

```bash
flutter analyze
```

Expected: no errors. Existing warnings should be reviewed; do not ignore new errors.

- [ ] **Step 3: 按用户既有工作流同步并 clean/build**

Use the repository’s existing build workflow from memory: 编辑后执行 rm+cp 同步到 Android 源目录，然后 clean + build，不新增构建目录。If this repository has a known script, use it; otherwise inspect the existing Android/Flutter build commands before running destructive sync commands.

Minimum build commands after confirming sync requirements:

```bash
flutter clean
flutter pub get
flutter build apk --release
```

Expected APK path:

```text
build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 4: 复制 APK 到桌面输出目录**

Run:

```bash
cp build/app/outputs/flutter-apk/app-release.apk "C:/Users/Elysia/Desktop/绘世/app-release.apk"
```

Expected: `C:\Users\Elysia\Desktop\绘世\app-release.apk` exists and has a fresh modified time.

- [ ] **Step 5: 最终状态检查**

Run:

```bash
git status --short
```

Expected: clean if commits were made as above; otherwise only intentional uncommitted files remain.

---

## Self-Review

- Spec coverage:
  - JSON 优先解析：Task 1。
  - 手动按钮保留：Task 1 only moves parser; `_CodeBlock` buttons stay unchanged。
  - 提示词约束：Task 2。
  - 设置改更多：Task 3 + Task 4。
  - Danbooru 查词：Task 3。
  - 默认首页生成页：Task 4。
  - 测试/分析/构建/复制 APK：Task 5。
- Placeholder scan: no TBD/TODO/“similar to”。
- Type consistency:
  - `AppliedSegments` fields match existing `GeneratePage.onApplyAll` usage.
  - `PromptSegment` replaces private `_Segment`; all parser APIs are public for tests.
  - `DanbooruApiService.search` arguments match existing service signature.
