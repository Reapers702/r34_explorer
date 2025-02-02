import 'dart:developer';

import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/constant/search_option.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/util/http_trace_util.dart';

class R34HomePageRepo {
  static Future<R34Page> getPage(R34HomeFilterOption option) async {
    http.Response? res;
    try {
      Uri uri = Uri.https(R34Const.host, '/', {
        'mode': 'async',
        'function': 'get_block',
        'block_id': 'custom_list_videos_most_recent_videos',
        'tag_ids': '',
        'sort_by': option.sortType.officialTag,
        '_': '${DateTime.now().millisecondsSinceEpoch}',
        'from': option.officialPage,
      });

      final header = Map.of(R34Const.headers);
      header['cookie'] = header['cookie']! + option.dateAdded.cookieValue;
      header['cookie'] = header['cookie']! + option.duration.cookieValue;

      res = await http
          .get(uri, headers: header)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      log(e.toString());
      HttpTraceUtil.handleConnectionError(e);
    }

    final document = parser.parse(res!.body);
    final videoParentEl =
        document.getElementById('custom_list_videos_most_recent_videos_items');
    final aThList = videoParentEl!.querySelectorAll('a.th.js-open-popup');
    List<R34Video> data = [];
    for (var aTh in aThList) {
      String title = aTh.attributes['title']!;
      String detailUrl = aTh.attributes['href']!;
      String videoPreviewUrl =
          aTh.querySelector('div.img.wrap_image')!.attributes['data-preview']!;
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
    final pageBtns = document
        .getElementById('custom_list_videos_most_recent_videos_pagination')!;
    for (var pageBtn in pageBtns.getElementsByTagName('a')) {
      if (pageBtn.text.trim() == 'Last') {
        final href = pageBtn.attributes['href']!;
        final splitPart = href.split('/')..removeLast();
        pageCount = int.parse(splitPart.last);
        break;
      }
    }

    final r34Page = R34Page(videos: data, pageCount: pageCount);
    // log('getPage: ${jsonEncode(r34Page.toJson())}');
    return r34Page;
  }
}
