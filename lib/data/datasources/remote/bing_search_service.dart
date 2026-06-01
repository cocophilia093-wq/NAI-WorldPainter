import 'package:dio/dio.dart';

/// Bing 搜索服务：用于查询特定动漫角色的 Danbooru tag。
///
/// 使用独立 Dio 实例，不复用全局 LLM Dio，避免污染 baseUrl/Authorization。
/// 解析 Bing 网页 HTML，提取前几条搜索结果的标题与摘要。
class BingSearchService {
  final Dio _dio;

  BingSearchService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            // 模拟桌面浏览器，防止 Bing 返回简化版或 403
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          },
        ));

  /// 查询角色名，返回结构化文本，便于注入 LLM system prompt。
  ///
  /// 拼接 danbooru / 外貌特征关键词，提高 wiki 词条与外貌信息的命中率。
  /// 失败时返回空字符串。
  Future<String> searchCharacter(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return '';

    // 多组查询：第一组偏向 danbooru wiki（拿到准确 tag 名），
    // 第二组偏向角色外貌（发色 / 瞳色 / 服装 / 发饰）。
    // 合并去重，限制总条数。
    final queries = <String>[
      '$trimmed danbooru tag character',
      '$trimmed hair color eye color outfit appearance',
    ];

    final allItems = <_SearchItem>[];
    final seenUrls = <String>{};

    for (final q in queries) {
      try {
        final response = await _dio.get<String>(
          'https://www.bing.com/search',
          queryParameters: {'q': q, 'ensearch': '0'},
        );
        final html = response.data;
        if (html == null || html.isEmpty) continue;
        final items = _extractItems(html, maxResults: 4);
        for (final it in items) {
          if (it.url.isNotEmpty && seenUrls.contains(it.url)) continue;
          if (it.url.isNotEmpty) seenUrls.add(it.url);
          allItems.add(it);
          if (allItems.length >= 6) break;
        }
        if (allItems.length >= 6) break;
      } catch (_) {
        // 单组失败不影响其他组
      }
    }

    if (allItems.isEmpty) return '';
    return _formatItems(allItems);
  }

  /// 从 HTML 中提取搜索条目列表（不做最终格式化）。
  List<_SearchItem> _extractItems(String html, {int maxResults = 5}) {
    final items = <_SearchItem>[];

    final algoPattern = RegExp(
      r'<li[^>]*class="[^"]*b_algo[^"]*"[^>]*>([\s\S]*?)</li>',
      multiLine: true,
    );

    for (final match in algoPattern.allMatches(html)) {
      if (items.length >= maxResults) break;
      final block = match.group(1) ?? '';

      final titleMatch = RegExp(
        r'<h2[^>]*>\s*<a[^>]*href="([^"]*)"[^>]*>([\s\S]*?)</a>',
      ).firstMatch(block);
      if (titleMatch == null) continue;

      final url = titleMatch.group(1) ?? '';
      final rawTitle = titleMatch.group(2) ?? '';
      final title = _stripTags(rawTitle).trim();
      if (title.isEmpty) continue;

      String? snippet;
      final sn1 = RegExp(
        r'<p[^>]*class="[^"]*b_lineclamp[^"]*"[^>]*>([\s\S]*?)</p>',
      ).firstMatch(block);
      if (sn1 != null) {
        snippet = sn1.group(1);
      } else {
        final sn2 = RegExp(
          r'<div[^>]*class="[^"]*b_caption[^"]*"[^>]*>[\s\S]*?<p[^>]*>([\s\S]*?)</p>',
        ).firstMatch(block);
        if (sn2 != null) snippet = sn2.group(1);
      }
      final cleanSnippet = (snippet == null) ? '' : _stripTags(snippet).trim();

      items.add(_SearchItem(title: title, url: url, snippet: cleanSnippet));
    }
    return items;
  }

  /// 把搜索条目格式化为注入文本。
  String _formatItems(List<_SearchItem> items) {
    final buf = StringBuffer();
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      buf.writeln('${i + 1}. ${item.title}');
      if (item.url.isNotEmpty) buf.writeln('   链接: ${item.url}');
      if (item.snippet.isNotEmpty) buf.writeln('   摘要: ${item.snippet}');
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  /// 去除 HTML 标签，反转义常见实体。
  String _stripTags(String html) {
    var s = html.replaceAll(RegExp(r'<[^>]+>'), '');
    s = s.replaceAll('&nbsp;', ' ');
    s = s.replaceAll('&amp;', '&');
    s = s.replaceAll('&lt;', '<');
    s = s.replaceAll('&gt;', '>');
    s = s.replaceAll('&quot;', '"');
    s = s.replaceAll('&#39;', "'");
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }
}

class _SearchItem {
  final String title;
  final String url;
  final String snippet;

  _SearchItem({required this.title, required this.url, required this.snippet});
}
