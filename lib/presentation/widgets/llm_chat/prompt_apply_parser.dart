import 'dart:convert';

/// AI 回复中匹配 fenced code block：```lang\n...\n```
final _codeBlockRegex = RegExp(r'```([a-zA-Z0-9_+\-]*)\s*\n([\s\S]*?)```');

class PromptSegment {
  final bool isCode;
  final String text;
  final String lang;

  /// 代码块前的标注文字（如"正向"、"负向"、"通用底模词"、"角色1"等）
  final String label;

  const PromptSegment.text(this.text)
      : isCode = false,
        lang = '',
        label = '';

  const PromptSegment.code(this.text, this.lang, this.label) : isCode = true;
}

/// 把整条助手回复中所有带标签的代码块按类型聚合。
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

AppliedSegments parseAppliedSegments(String content) {
  final jsonResult = _parseStructuredJson(content);
  if (jsonResult != null && !jsonResult.isEmpty) return jsonResult;
  return _aggregateSegments(splitPromptContent(content));
}

List<PromptSegment> splitPromptContent(String content) {
  final segments = <PromptSegment>[];
  int cursor = 0;
  String pendingLabel = '';

  for (final m in _codeBlockRegex.allMatches(content)) {
    if (m.start > cursor) {
      final text = content.substring(cursor, m.start);
      if (text.trim().isNotEmpty) {
        pendingLabel = extractPromptLabel(text);
        segments.add(PromptSegment.text(text));
      }
    }
    segments.add(PromptSegment.code((m.group(2) ?? '').trim(), m.group(1) ?? '', pendingLabel));
    pendingLabel = '';
    cursor = m.end;
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

AppliedSegments? _parseStructuredJson(String content) {
  for (final m in _codeBlockRegex.allMatches(content)) {
    final lang = (m.group(1) ?? '').trim().toLowerCase();
    if (lang == 'json') {
      final decoded = _decodeAppliedJson(m.group(2) ?? '');
      if (decoded != null) return decoded;
    }
  }
  final objectText = _extractJsonObject(content.trim());
  if (objectText == null) return null;
  return _decodeAppliedJson(objectText);
}

AppliedSegments? _decodeAppliedJson(String raw) {
  try {
    final decoded = jsonDecode(raw.trim());
    if (decoded is! Map) return null;
    final obj = decoded.cast<String, dynamic>();
    final characterPrompts = <String>[];
    final characterNegatives = <String>[];
    final characters = obj['characters'];
    if (characters is List) {
      for (final item in characters) {
        if (item is Map) {
          final map = item.cast<String, dynamic>();
          characterPrompts.add(_stringOrEmpty(map['positive']));
          characterNegatives.add(_stringOrEmpty(map['negative']));
        }
      }
    }
    return AppliedSegments(
      positive: _stringOrNull(obj['positive']),
      negative: _stringOrNull(obj['negative']),
      characterPrompts: characterPrompts,
      characterNegatives: characterNegatives,
    );
  } catch (_) {
    return null;
  }
}

String? _extractJsonObject(String text) {
  final start = text.indexOf('{');
  if (start < 0) return null;
  int depth = 0;
  var inString = false;
  var escaping = false;
  for (var i = start; i < text.length; i++) {
    final ch = text[i];
    if (escaping) {
      escaping = false;
      continue;
    }
    if (ch == r'\') {
      escaping = true;
      continue;
    }
    if (ch == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  return null;
}

String? _stringOrNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

String _stringOrEmpty(dynamic value) => _stringOrNull(value) ?? '';

int? _characterIndex(String label) {
  final m = RegExp(r'角色\s*(\d+)').firstMatch(label);
  if (m == null) return null;
  final n = int.tryParse(m.group(1) ?? '');
  if (n == null || n <= 0) return null;
  return n - 1;
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
