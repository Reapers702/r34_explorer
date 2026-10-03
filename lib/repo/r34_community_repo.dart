import 'package:html/parser.dart' as parser;
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_community_user.dart';
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/log_util.dart';
import 'package:r34_video/util/r34_video_list_parser.dart';

class R34CommunityRepo {
  static const int _pageSize = 24;

  static Future<R34CommunityUser?> getCommunityUser(int userId) async {
    final uri = Uri.https(R34Const.host, '/members/$userId/');

    try {
      final res = await R34Client.instance.get(uri);
      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        return null;
      }

      final doc = parser.parse(res.body);
      final nickName =
          doc.querySelector('div.avatar')?.nextElementSibling?.text.trim() ??
              '未知用户';
      final avatarUrl = doc.querySelector('div.avatar img')?.attributes['src'];
      final subscriberCount =
          doc.querySelector('div.subscribers_count')?.text.replaceAll(
                'Subscribers',
                '',
              ).trim() ??
              '0';

      final videoStatisticsTitles = doc
          .getElementsByClassName('content_general')
          .firstOrNull
          ?.querySelectorAll('h2.title') ??
          const [];

      String? countOf(String keyword) {
        return videoStatisticsTitles
            .where((e) => e.text.contains(keyword))
            .firstOrNull
            ?.querySelector('span.total_results')
            ?.text
            .replaceAll(RegExp(r'[()]'), '');
      }

      return R34CommunityUser(
        nickName: nickName,
        avatarUrl: avatarUrl,
        subscriberCount: subscriberCount,
        uploadVideoCount: countOf('\'s Videos'),
        favoriteVideoCount: countOf('\'s Favorites'),
      );
    } catch (e, st) {
      LogUtil.error('getCommunityUser failed: $e\n$st');
      return null;
    }
  }

  static Future<List<R34CommunityVideo>> getUserUploadVideo(
    int userId,
    int fromIndex,
  ) async {
    final uri = Uri.https(R34Const.host, '/members/$userId/videos/', {
      'mode': 'async',
      'function': 'get_block',
      'block_id': 'list_videos_uploaded_videos',
      'sort_by': '',
      'from_videos': '${fromIndex ~/ _pageSize + 1}'.padLeft(2, '0'),
      '_': '${DateTime.now().millisecondsSinceEpoch}',
    });

    try {
      final res = await R34Client.instance.get(uri);
      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        return const [];
      }
      return R34VideoListParser.parseDocToVideo(
        ParseType.upload,
        body: res.body,
      );
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return const [];
    }
  }

  static Future<List<R34CommunityVideo>> getUserFavoriteVideo(
    int userId,
    int fromIndex,
  ) async {
    final uri =
        Uri.https(R34Const.host, '/members/$userId/favourites/videos/', {
      'mode': 'async',
      'function': 'get_block',
      'block_id': 'list_videos_favourite_videos',
      'fav_type': '0',
      'playlist_id': '0',
      'sort_by': '',
      'from_fav_videos': '${fromIndex ~/ _pageSize + 1}'.padLeft(2, '0'),
      '_': '${DateTime.now().millisecondsSinceEpoch}',
    });

    try {
      final res = await R34Client.instance.get(uri);
      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        return const [];
      }
      return R34VideoListParser.parseDocToVideo(
        ParseType.favorite,
        body: res.body,
      );
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return const [];
    }
  }
}
