import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_search_request.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/r34_video_list_parser.dart';

/// 搜索 / 分类页请求。
///
/// 相比早期版本的变化：
/// * 时长（`duration_from` / `duration_to`）和上传时间（`post_date_from`）
///   作为 query 参数下发，所以「关键词搜索 + 时长限制」可以叠加了；
/// * 解析统一走 [R34VideoListParser]，单张卡片坏掉不会让整页空掉；
/// * 补了 HTTP 状态码与解析失败的区分，不再一律弹「联系开发者」。
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

    http.Response? res;
    try {
      res = await http
          .get(uri, headers: R34Const.headers)
          .timeout(const Duration(seconds: 15));
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
    }

    if (res == null || res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res?.statusCode ?? -1);
      return R34Page.empty();
    }

    return R34VideoListParser.parseSearchResult(
      parseType: parseType,
      body: res.body,
    );
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
