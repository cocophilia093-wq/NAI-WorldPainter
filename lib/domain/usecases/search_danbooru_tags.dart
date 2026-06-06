import 'package:nai_huishi/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_huishi/domain/entities/danbooru_tag.dart';
import 'package:nai_huishi/domain/usecases/extract_keywords.dart';

/// 一次完整的"Danbooru 真实标签池"。
///
/// - [globalTags]：场景/风格类的全局候选 tag（不分角色）
/// - [perCharacterTags]：每个角色独立的候选 tag 列表，下标与
///   [ExtractedKeywords.characters] 对齐
class DanbooruTagPool {
  final List<DanbooruTag> globalTags;
  final List<List<DanbooruTag>> perCharacterTags;

  const DanbooruTagPool({
    required this.globalTags,
    required this.perCharacterTags,
  });

  bool get isEmpty =>
      globalTags.isEmpty && perCharacterTags.every((l) => l.isEmpty);
}

/// 拿抽取出的关键词去 Danbooru 跑 search + related，得到真实 tag 池。
///
/// 流程：
///   1. 全局：把 scene/style/nsfw 中每个短语并发 search()，合并去重后取 top
///   2. 每个角色：search(角色描述) + related(用 search top 5 转 SD 风格做种子)
///   3. 全部失败抛 Exception，由调用方决定是否降级
class SearchDanbooruTagsUseCase {
  final DanbooruApiService _api;

  SearchDanbooruTagsUseCase(this._api);

  Future<DanbooruTagPool> call({
    required ExtractedKeywords keywords,
    bool showNsfw = true,
    String? customBaseUrl,
    int globalLimitPerQuery = 12,
    int characterSearchLimit = 16,
    int characterRelatedLimit = 16,
  }) async {
    // 1) 全局：对 scene + style + nsfw 每条短语并发 search()
    final globalQueries = <String>[
      ...keywords.scene,
      ...keywords.style,
      if (showNsfw) ...keywords.nsfw,
    ];

    final globalFutures = globalQueries
        .where((q) => q.trim().isNotEmpty)
        .map((q) => _api
            .search(
              query: q,
              topK: 5,
              limit: globalLimitPerQuery,
              showNsfw: showNsfw,
              customBaseUrl: customBaseUrl,
            )
            .catchError((_) => <DanbooruTag>[]))
        .toList();

    // 2) 每个角色：search + related 并发
    final charFutures = <Future<List<DanbooruTag>>>[];
    for (final c in keywords.characters) {
      final q = c.trim();
      if (q.isEmpty) {
        charFutures.add(Future.value(const <DanbooruTag>[]));
        continue;
      }
      charFutures.add(_searchPerCharacter(
        query: q,
        showNsfw: showNsfw,
        customBaseUrl: customBaseUrl,
        searchLimit: characterSearchLimit,
        relatedLimit: characterRelatedLimit,
      ));
    }

    final globalResults = await Future.wait(globalFutures);
    final charResults = await Future.wait(charFutures);

    // 合并 + 去重
    final globalMerged = _mergeUnique(globalResults.expand((e) => e));

    final pool = DanbooruTagPool(
      globalTags: globalMerged,
      perCharacterTags: charResults,
    );
    if (pool.isEmpty) {
      throw Exception('Danbooru 检索未返回任何 tag');
    }
    return pool;
  }

  /// 单角色：先 search 取 top tag，再用前 5 个 SD 风格 tag 作种子跑 related
  Future<List<DanbooruTag>> _searchPerCharacter({
    required String query,
    required bool showNsfw,
    required String? customBaseUrl,
    required int searchLimit,
    required int relatedLimit,
  }) async {
    List<DanbooruTag> searchResult;
    try {
      searchResult = await _api.search(
        query: query,
        topK: 5,
        limit: searchLimit,
        showNsfw: showNsfw,
        customBaseUrl: customBaseUrl,
      );
    } catch (_) {
      searchResult = const [];
    }

    List<DanbooruTag> relatedResult = const [];
    if (searchResult.isNotEmpty) {
      final seeds = searchResult
          .take(5)
          .map((t) => _toDanbooruTag(t.tag))
          .where((t) => t.isNotEmpty)
          .toList();
      if (seeds.isNotEmpty) {
        try {
          relatedResult = await _api.related(
            tags: seeds,
            limit: relatedLimit,
            showNsfw: showNsfw,
            customBaseUrl: customBaseUrl,
          );
        } catch (_) {
          relatedResult = const [];
        }
      }
    }

    return _mergeUnique([...searchResult, ...relatedResult]);
  }

  /// 按 _normKey 去重，保持原顺序。
  List<DanbooruTag> _mergeUnique(Iterable<DanbooruTag> list) {
    final seen = <String>{};
    final out = <DanbooruTag>[];
    for (final t in list) {
      if (t.tag.trim().isEmpty) continue;
      if (seen.add(_normKey(t.tag))) out.add(t);
    }
    return out;
  }

  /// NovelAI 风格 → Danbooru SD 风格（空格转下划线），用于 /related 种子。
  String _toDanbooruTag(String tag) {
    return tag.trim().replaceAll(RegExp(r'\s+'), '_');
  }

  /// 归一化键：忽略大小写，下划线视同空格。
  String _normKey(String tag) {
    return tag.toLowerCase().replaceAll('_', ' ').trim();
  }
}
