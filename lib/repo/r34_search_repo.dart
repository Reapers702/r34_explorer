import 'dart:convert';

import 'package:html/parser.dart' as parser;
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_search_request.dart';
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/log_util.dart';
import 'package:r34_video/util/r34_video_list_parser.dart';

/// 搜索 / 分类页请求。
///
/// 相比早期版本的变化：
/// * 时长（`duration_from` / `duration_to`）和上传时间（`post_date_from`）
///   作为 query 参数下发，所以「关键词搜索 + 时长限制」可以叠加了；
/// * 解析统一走 [R34VideoListParser]，单张卡片坏掉不会让整页空掉；
/// * 补了 HTTP 状态码与解析失败的区分，不再一律弹「联系开发者」；
/// * 请求走 [R34Client]，cookie 由它注入与回写。
class R34SearchRepo {
  static const Map<SearchKeywordType, ParseType> _parseTypeMap = {
    SearchKeywordType.keyword: ParseType.searchKeyword,
    SearchKeywordType.tag: ParseType.searchCommon,
    SearchKeywordType.artist: ParseType.searchCommon,
    SearchKeywordType.category: ParseType.searchCommon,
  };

  static const Map<SearchKeywordType, String> _blockIdMap = {
    SearchKeywordType.keyword: 'custom_list_videos_videos_list_search',
    SearchKeywordType.tag: 'custom_list_videos_common_videos',
    SearchKeywordType.artist: 'custom_list_videos_common_videos',
    SearchKeywordType.category: 'custom_list_videos_common_videos',
  };

  static Future<R34Page> searchResult(R34SearchRequest request) async {
    final parseType = _parseTypeMap[request.keywordType] ??
        ParseType.searchKeyword;

    final path = pathOf(request);

    final query = buildSearchQuery(request)
      ..['_'] = '${DateTime.now().millisecondsSinceEpoch}';

    final uri = Uri.https(R34Const.host, path, query);

    try {
      final res = await R34Client.instance.get(uri);
      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        return R34Page.empty();
      }
      return R34VideoListParser.parseSearchResult(
        parseType: parseType,
        body: res.body,
      );
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return R34Page.empty();
    }
  }

  /// 组装搜索接口的 query 参数（纯函数，便于单元测试）。
  ///
  /// 对齐原站搜索表单：
  /// * `tag_ids` / `category_ids` 带 `all,` 前缀（多选时 `all,` 表示不限定主分类）；
  /// * `model_ids` 是创作者 id 直接拼接；
  /// * `temp_skip_items` 是屏蔽列表 token（`tag:<id>` / `cat:<id>` / `model:<id>`）。
  /// 附加条件只在 [SearchKeywordType.keyword] 时下发，分类页照旧用 `from`。
  static Map<String, String> buildSearchQuery(R34SearchRequest request) {
    final pageToken = request.page.toString().padLeft(2, '0');

    final query = <String, String>{
      'mode': 'async',
      'function': 'get_block',
      'block_id': _blockIdMap[request.keywordType] ?? '',
      'sort_by': request.sortType.officialTag,
      // 时长 / 上传时间筛选。
      ...request.filter.queryParams,
    };

    // 关键词搜索用 search 页面自己的分页参数，分类页用 `from`。
    if (request.keywordType == SearchKeywordType.keyword) {
      query['q'] = request.keyword;
      query['from_videos'] = pageToken;
      query['from_albums'] = pageToken;

      if (request.tagIds.isNotEmpty) {
        query['tag_ids'] = 'all,${request.tagIds.join(',')}';
      }
      if (request.artistIds.isNotEmpty) {
        query['model_ids'] = request.artistIds.join(',');
      }
      if (request.categoryIds.isNotEmpty) {
        query['category_ids'] = 'all,${request.categoryIds.join(',')}';
      }
      if (request.blacklistTokens.isNotEmpty) {
        query['temp_skip_items'] = request.blacklistTokens.join(',');
      }
    } else {
      query['from'] = pageToken;
    }

    return query;
  }

  /// tag 联想。
  ///
  /// 站点搜索框自己用的就是这个端点：`/tags_json.php?id=true&advanced_search=true&q=`。
  /// **不需要 cookie**（实测无凭据直接 200）。
  ///
  /// 返回形如：
  /// ```json
  /// {"total_count":30,"items":[{"id":"51","title":"ada wong (resident evil)","total":"2997"}]}
  /// ```
  /// 注意本站在 tag 里**保留空格**（`ada wong (resident evil)`），
  /// 与 rule34.xxx 相反；搜索时把 `title` 原样当作关键词即可（实测能精确命中）。
  static Future<List<R34VideoAutocompleteItem>> autocompleteTags(
    String query, {
    int limit = 10,
  }) {
    return _autocomplete(
      '/tags_json.php',
      query,
      extra: const {'id': 'true', 'advanced_search': 'true'},
      limit: limit,
    );
  }

  /// 创作者联想，站点端点 `/models_json.php?q=`（无 advanced_search）。
  static Future<List<R34VideoAutocompleteItem>> autocompleteArtists(
    String query, {
    int limit = 10,
  }) {
    return _autocomplete('/models_json.php', query, limit: limit);
  }

  /// 分类联想，站点端点 `/categories_json.php?q=`（无 advanced_search）。
  static Future<List<R34VideoAutocompleteItem>> autocompleteCategories(
    String query, {
    int limit = 10,
  }) {
    return _autocomplete('/categories_json.php', query, limit: limit);
  }

  /// 屏蔽（temp blacklist）联想：tag / 分类 / 创作者三个端点各取若干条合并，
  /// 对齐原站搜索框的 temp blacklist 下拉。
  static Future<List<R34BlacklistSuggestion>> autocompleteBlacklist(
    String query, {
    int perSource = 5,
  }) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const [];
    }

    final results = await Future.wait([
      _autocomplete(
        '/tags_json.php',
        keyword,
        extra: const {'id': 'true'},
        limit: perSource,
      ),
      _autocomplete('/categories_json.php', keyword, limit: perSource),
      _autocomplete('/models_json.php', keyword, limit: perSource),
    ]);

    final list = <R34BlacklistSuggestion>[];
    for (final item in results[0]) {
      final token = toBlacklistToken('tag', item.id);
      if (token != null) {
        list.add(R34BlacklistSuggestion(
          typeLabel: 'Tag',
          name: item.title,
          token: token,
        ));
      }
    }
    for (final item in results[1]) {
      final token = toBlacklistToken('cat', item.id);
      if (token != null) {
        list.add(R34BlacklistSuggestion(
          typeLabel: '分类',
          name: item.title,
          token: token,
        ));
      }
    }
    for (final item in results[2]) {
      final token = toBlacklistToken('model', item.id);
      if (token != null) {
        list.add(R34BlacklistSuggestion(
          typeLabel: '创作者',
          name: item.title,
          token: token,
        ));
      }
    }
    return list;
  }

  /// 把联想项的 id 转成 blacklist token。
  ///
  /// 原站 JS 只认**纯数字 id**，非数字的丢弃（`initTempBlacklistSelect` 同款校验）。
  static String? toBlacklistToken(String typePrefix, String id) {
    if (!RegExp(r'^\d+$').hasMatch(id)) {
      return null;
    }
    return '$typePrefix:$id';
  }

  /// 解析联想 JSON body → 通用联想项列表。
  ///
  /// 三个端点的响应结构略有差异，id / 名称的键名按站点 JS 的顺序回退：
  /// id 取 `id || category_id || model_id || tag_id`，
  /// 名称取 `title || tag || name`。无结果时站点返回 `"items":""`，一并兜住。
  static List<R34VideoAutocompleteItem> parseAutocompleteItems(
    String body, {
    int limit = 100,
  }) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    if (decoded is! Map || decoded['items'] is! List) {
      return const [];
    }

    final result = <R34VideoAutocompleteItem>[];
    for (final item in decoded['items'] as List) {
      if (item is! Map) {
        continue;
      }
      final id = _firstNonEmpty(item, const ['id', 'category_id', 'model_id', 'tag_id']);
      final title = _firstNonEmpty(item, const ['title', 'tag', 'name']);
      if (id.isEmpty || title.isEmpty) {
        continue;
      }
      result.add(R34VideoAutocompleteItem(
        id: id,
        title: title,
        total: '${item['total'] ?? ''}',
      ));
      if (result.length >= limit) {
        break;
      }
    }
    return result;
  }

  static String _firstNonEmpty(Map item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && '$value'.trim().isNotEmpty) {
        return '$value'.trim();
      }
    }
    return '';
  }

  static Future<List<R34VideoAutocompleteItem>> _autocomplete(
    String path,
    String query, {
    Map<String, String> extra = const {},
    int limit = 10,
  }) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const [];
    }

    final uri = Uri.https(R34Const.host, path, {'q': keyword, ...extra});

    try {
      final res = await R34Client.instance.get(uri);
      if (res.statusCode != 200) {
        return const [];
      }
      return parseAutocompleteItems(res.body, limit: limit);
    } catch (e) {
      // 联想失败静默处理，不打扰用户输入。
      LogUtil.warn('rule34video $path autocomplete failed: $e');
      return const [];
    }
  }

  /// 组装搜索结果页 path。
  ///
  /// 站点把空格换成 `-`，`-` 换成 `--`。**空关键词**（仅用 Tag/创作者/分类/
  /// 屏蔽条件搜索）时返回 `/search/`（站点的 `data-videosUrl`），
  /// 附加条件由 [buildSearchQuery] 以 query 形式带上。
  static String pathOf(R34SearchRequest request) {
    switch (request.keywordType) {
      case SearchKeywordType.keyword:
        final keyword = request.keyword.trim();
        if (keyword.isEmpty) {
          return '/search/';
        }
        final slug = keyword.replaceAll('-', '--').replaceAll(' ', '-');
        return '/search/$slug/';
      case SearchKeywordType.tag:
        return '/tags/${request.keyword}/';
      case SearchKeywordType.artist:
        return '/models/${request.keyword}/';
      case SearchKeywordType.category:
        return '/categories/${request.keyword}/';
    }
  }

  /// 详情页里解析出的可见文本（调试用）。
  static String? debugParseContainer(String body, SearchKeywordType type) {
    final document = parser.parse(body);
    final parseType = _parseTypeMap[type] ?? ParseType.searchKeyword;
    return document.getElementById(parseType.parseId)?.outerHtml;
  }
}

/// 通用联想结果（tag / 分类 / 创作者共用）。
///
/// 三个端点响应里 id / 名称键名不同，解析时按站点 JS 的顺序统一回退，
/// 对外只暴露统一的 [id] 与 [title]。
class R34VideoAutocompleteItem {
  /// 站点内部的数字 id（blacklist token、tag_ids 参数都用它）。
  final String id;

  /// 展示 / 直接可用的名称。
  final String title;

  /// 使用量（tag 端点才有，可能为空）。
  final String total;

  const R34VideoAutocompleteItem({
    required this.id,
    required this.title,
    this.total = '',
  });

  @override
  String toString() => 'R34VideoAutocompleteItem($title/$id/$total)';
}

/// 屏蔽（temp blacklist）联想项。
class R34BlacklistSuggestion {
  /// 类型文案：`Tag` / `分类` / `创作者`。
  final String typeLabel;

  /// 展示名称。
  final String name;

  /// 服务端认的 token，如 `tag:51`。
  final String token;

  const R34BlacklistSuggestion({
    required this.typeLabel,
    required this.name,
    required this.token,
  });

  @override
  String toString() => 'R34BlacklistSuggestion($typeLabel:$name/$token)';
}
