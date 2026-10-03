import 'package:html/parser.dart' as parser;
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/r34_video_list_parser.dart';

/// 首页视频流。
///
/// 时长/时间筛选走 query 参数（站点服务端认这几个键），不走 cookie，
/// 这样不会污染后续所有请求。
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

    try {
      final res = await R34Client.instance.get(uri);
      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
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
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return R34Page.empty();
    }
  }
}
