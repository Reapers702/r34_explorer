import 'dart:developer' as dev;

import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_search_request.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/util/http_trace_util.dart';

class R34SearchRepo {
  static const Map<SearchKeywordType, String> blockIdMap = {
    SearchKeywordType.keyword: 'custom_list_videos_videos_list_search',
    SearchKeywordType.tag: 'custom_list_videos_common_videos',
    SearchKeywordType.artist: 'custom_list_videos_common_videos',
    SearchKeywordType.category: 'custom_list_videos_common_videos',
  };

  static const Map<SearchKeywordType, String> videoBundleIdMap = {
    SearchKeywordType.keyword: 'custom_list_videos_videos_list_search_items',
    SearchKeywordType.tag: 'custom_list_videos_common_videos_items',
    SearchKeywordType.artist: 'custom_list_videos_common_videos_items',
    SearchKeywordType.category: 'custom_list_videos_common_videos_items',
  };

  static const Map<SearchKeywordType, String> pageBundleIdMap = {
    SearchKeywordType.keyword:
        'custom_list_videos_videos_list_search_pagination',
    SearchKeywordType.tag: 'custom_list_videos_common_videos_pagination',
    SearchKeywordType.artist: 'custom_list_videos_common_videos_pagination',
    SearchKeywordType.category: 'custom_list_videos_common_videos_pagination',
  };

  static Future<R34Page> searchResult(R34SearchRequest request) async {
    final future = request.keywordType == SearchKeywordType.keyword
        ? _searchByKeyword(request)
        : request.keywordType == SearchKeywordType.tag
            ? _searchByTag(request)
            : request.keywordType == SearchKeywordType.artist
                ? _searchByArtist(request)
                : request.keywordType == SearchKeywordType.category
                    ? _searchByCategory(request)
                    : Future.value(R34Page(pageCount: 1, videos: []));
    return await future;
  }

  static Future<R34Page> _searchByKeyword(R34SearchRequest request) async {
    http.Response? res;
    try {
      Uri uri = Uri.https(
          R34Const.host,
          '/search/${request.keyword.replaceAll('-', '--').replaceAll(' ', '-')}/',
          {
            'mode': 'async',
            'function': 'get_block',
            'block_id': blockIdMap[request.keywordType],
            'q': request.keyword,
            'sort_by': request.sortType.officialTag,
            'from_videos': request.page.toString().padLeft(2, '0'),
            'from_albums': request.page.toString().padLeft(2, '0'),
            '_': '${DateTime.now().millisecondsSinceEpoch}',
          });

      res = await http
          .get(uri, headers: R34Const.headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      HttpTraceUtil.handleConnectionError(e);
    }

    if (res == null || res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res?.statusCode ?? -1);
      return R34Page(videos: [], pageCount: 1);
    }
    return _parseDocToPage(res.body, request.keywordType);
  }

  static Future<R34Page> _searchByTag(R34SearchRequest request) async {
    http.Response? res;
    try {
      Uri uri = Uri.https(R34Const.host, '/tags/${request.keyword}/', {
        'mode': 'async',
        'function': 'get_block',
        'block_id': blockIdMap[request.keywordType],
        'sort_by': request.sortType.officialTag,
        'from': request.page.toString().padLeft(2, '0'),
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      });

      res = await http
          .get(uri, headers: R34Const.headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      HttpTraceUtil.handleConnectionError(e);
    }

    if (res == null || res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res?.statusCode ?? -1);
      return R34Page(videos: [], pageCount: 1);
    }
    return _parseDocToPage(res.body, request.keywordType);
  }

  static Future<R34Page> _searchByArtist(R34SearchRequest request) async {
    http.Response? res;
    try {
      Uri uri = Uri.https(R34Const.host, '/models/${request.keyword}/', {
        'mode': 'async',
        'function': 'get_block',
        'block_id': blockIdMap[request.keywordType],
        'sort_by': request.sortType.officialTag,
        'from': request.page.toString().padLeft(2, '0'),
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      });

      res = await http
          .get(uri, headers: R34Const.headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      HttpTraceUtil.handleConnectionError(e);
    }

    if (res == null || res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res?.statusCode ?? -1);
      return R34Page(videos: [], pageCount: 1);
    }
    return _parseDocToPage(res.body, request.keywordType);
  }

  static Future<R34Page> _searchByCategory(R34SearchRequest request) async {
    http.Response? res;
    try {
      Uri uri = Uri.https(R34Const.host, '/categories/${request.keyword}/', {
        'mode': 'async',
        'function': 'get_block',
        'block_id': blockIdMap[request.keywordType],
        'sort_by': request.sortType.officialTag,
        'from': request.page.toString().padLeft(2, '0'),
        '_': '${DateTime.now().millisecondsSinceEpoch}',
      });

      res = await http
          .get(uri, headers: R34Const.headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      HttpTraceUtil.handleConnectionError(e);
    }

    if (res == null || res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res?.statusCode ?? -1);
      return R34Page(videos: [], pageCount: 1);
    }
    return _parseDocToPage(res.body, request.keywordType);
  }

  static R34Page _parseDocToPage(String body, SearchKeywordType keywordType) {
    dev.log('_parseDocToVideo start');
    try {
      final doc = parser.parse(body);
      final videoParentEl = doc.getElementById(videoBundleIdMap[keywordType]!);
      final aThList = videoParentEl!.querySelectorAll('a.th.js-open-popup');

      List<R34Video> data = [];
      for (var aTh in aThList) {
        String title = aTh.attributes['title']!;
        String detailUrl = aTh.attributes['href']!;
        String videoPreviewUrl = aTh
            .querySelector('div.img.wrap_image')!
            .attributes['data-preview']!;
        String thumbPreviewUrl =
            aTh.querySelector('img.thumb.lazy-load')!.attributes['data-webp']!;
        String videoDuration = aTh.querySelector('div.time')!.text;
        data.add(R34Video(
          title: title,
          detailUrl: detailUrl,
          videoPreviewUrl: videoPreviewUrl,
          thumbImageUrl: thumbPreviewUrl,
          videoDuration: videoDuration,
        ));
      }

      int pageCount = 1;
      final pageBtns = doc.getElementById(pageBundleIdMap[keywordType]!);
      for (var pageBtn in pageBtns?.getElementsByTagName('a') ?? []) {
        if (pageBtn.text.trim() == 'Last') {
          final href = pageBtn.attributes['data-parameters']!;
          pageCount = int.parse(href.split(':').last);
          break;
        } else {
          pageCount = int.tryParse(pageBtn.text.trim()) ?? pageCount;
        }
      }

      return R34Page(videos: data, pageCount: pageCount);
    } catch (e) {
      dev.log('_parseDocToVideo Error: $e');
      return R34Page.empty();
    }
  }
}
