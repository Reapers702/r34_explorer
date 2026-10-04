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

    final path = _pathOf(request);
    final pageToken = request.page.toString().padLeft(2, '0');

    final query = <String, String>{
      'mode': 'async',
      'function': 'get_block',
      'block_id': _blockIdMap[request.keywordType] ?? '',
      'sort_by': request.sortType.officialTag,
      // 时长 / 上传时间筛选。
      ...request.filter.queryParams,
      '_': '${DateTime.now().millisecondsSinceEpoch}',
    };

    // 关键词搜索用 search 页面自己的分页参数，分类页用 `from`。
    if (request.keywordType == SearchKeywordType.keyword) {
      query['q'] = request.keyword;
      query['from_videos'] = pageToken;
      query['from_albums'] = pageToken;
    } else {
      query['from'] = pageToken;
    }

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
  static Future<List<R34VideoTagSuggestion>> autocompleteTags(
    String query, {
    int limit = 10,
  }) async {
    final keyword = query.trim();
    if (keyword.isEmpty) {
      return const [];
    }

    final uri = Uri.https(R34Const.host, '/tags_json.php', {
      'id': 'true',
      'advanced_search': 'true',
      'q': keyword,
    });

    try {
      final res = await R34Client.instance.get(uri);
      if (res.statusCode != 200) {
        return const [];
      }

      final dynamic decoded = jsonDecode(res.body);
      if (decoded is! Map || decoded['items'] is! List) {
        // 无结果时站点返回 "items":"" 而不是数组，这里一并兜住。
        return const [];
      }

      final result = <R34VideoTagSuggestion>[];
      for (final item in decoded['items'] as List) {
        if (item is! Map) {
          continue;
        }
        final title = '${item['title'] ?? ''}'.trim();
        if (title.isEmpty) {
          continue;
        }
        result.add(R34VideoTagSuggestion(
          title: title,
          id: '${item['id'] ?? ''}',
          total: '${item['total'] ?? ''}',
        ));
        if (result.length >= limit) {
          break;
        }
      }
      return result;
    } catch (e) {
      // 联想失败静默处理，不打扰用户输入。
      LogUtil.warn('rule34video tag autocomplete failed: $e');
      return const [];
    }
  }

  /// 站点把空格换成 `-`，`-` 换成 `--`。
  static String _pathOf(R34SearchRequest request) {
    switch (request.keywordType) {
      case SearchKeywordType.keyword:
        final slug =
            request.keyword.replaceAll('-', '--').replaceAll(' ', '-');
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

/// rule34video 的 tag 联想结果。
///
/// 与 rule34.xxx 的区别：这里 tag 的 [title] 内部**保留空格**
/// （`ada wong (resident evil)`），搜索时原样当关键词用即可。
class R34VideoTagSuggestion {
  /// 真正的 tag 文本，可直接用于搜索。
  final String title;

  /// 站点内部的 tag id（`/tags/<id>/` 用得到）。
  final String id;

  /// 使用量。
  final String total;

  const R34VideoTagSuggestion({
    required this.title,
    this.id = '',
    this.total = '',
  });

  @override
  String toString() => 'R34VideoTagSuggestion($title/$id/$total)';
}
