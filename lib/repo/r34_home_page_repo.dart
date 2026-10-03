import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/r34_video_list_parser.dart';

/// 首页视频流。
///
/// 首页原本用 cookie 传时长/时间筛选（服务端会据此改后续所有请求），
/// 现在改成 query 参数，语义更清楚，也不会污染其他请求。
class R34HomePageRepo {
  static const String _blockId = 'custom_list_videos_most_recent_videos';

  static Future<R34Page> getPage(FilterSelection option, {int page = 1}) async {
    final uri = Uri.https(R34Const.host, '/', {
      'mode': 'async',
      'function': 'get_block',
      'block_id': _blockId,
      'tag_ids': '',
      'sort_by': option.sortType.officialTag,
      'from': page.toString().padLeft(2, '0'),
      '_': '${DateTime.now().millisecondsSinceEpoch}',
      ...option.queryParams,
    });

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

    final document = parser.parse(res.body);
    return R34Page(
      videos: R34VideoListParser.parseVideosIn(
        doc: document,
        parseType: ParseType.homepage,
      ),
      pageCount: R34VideoListParser.parsePageCount(
        document,
        ParseType.homepage,
      ),
    );
  }
}
