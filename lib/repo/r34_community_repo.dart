import 'dart:developer';

import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_community_user.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/r34_video_list_parser.dart';

class R34CommunityRepo {
  static const int _pageSize = 24;
  static const String _userPageUrl = 'https://${R34Const.host}/members/{uid}/';

  static Future<R34CommunityUser?> getCommunityUser(int userId) async {
    Uri uri = Uri.parse(_userPageUrl.replaceAll('{uid}', userId.toString()));
    http.Response? res;
    try {
      res = await http.get(uri, headers: R34Const.headers);
    } catch (e) {
      HttpTraceUtil.handleConnectionError(e);
    }

    if (res == null || res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res?.statusCode ?? -1);
      return null;
    }

    try {
      final doc = parser.parse(res.body);
      final nickName =
          doc.querySelector('div.avatar')?.nextElementSibling?.text.trim() ??
              'Something Error';
      final avatarUrl = doc.querySelector('div.avatar img')?.attributes['src'];
      final subscriberCount = doc
          .querySelector('div.subscribers_count')!
          .text
          .replaceAll('Subscribers', '')
          .trim();

      final videoStatisticsTitles = doc
          .getElementsByClassName('content_general')[0]
          .querySelectorAll('h2.title');
      final uploadCount = videoStatisticsTitles
          .where((e) => e.text.contains('\'s Videos'))
          .firstOrNull
          ?.querySelector('span.total_results')
          ?.text
          .replaceAll(RegExp(r'[()]'), '');
      final favoriteCount = videoStatisticsTitles
          .where((e) => e.text.contains('\'s Favorites'))
          .firstOrNull
          ?.querySelector('span.total_results')
          ?.text
          .replaceAll(RegExp(r'[()]'), '');

      final communityUser = R34CommunityUser(
        nickName: nickName,
        avatarUrl: avatarUrl,
        subscriberCount: subscriberCount,
        uploadVideoCount: uploadCount,
        favoriteVideoCount: favoriteCount,
      );
      return communityUser;
    } catch (e, st) {
      log('$st');
      return null;
    }
  }

  static Future<List<R34CommunityVideo>> getUserUploadVideo(
      int userId, int fromIndex) async {
    http.Response? res;
    try {
      Uri uri = Uri.https(R34Const.host, '/members/$userId/videos/', {
        'mode': 'async',
        'function': 'get_block',
        'block_id': 'list_videos_uploaded_videos',
        'sort_by': '',
        'from_videos': '${fromIndex ~/ _pageSize + 1}'.padLeft(2, '0'),
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
      return [];
    }
    return R34VideoListParser.parseDocToVideo(ParseType.upload, body: res.body);
  }

  static Future<List<R34CommunityVideo>> getUserFavoriteVideo(
      int userId, int fromIndex) async {
    http.Response? res;
    try {
      Uri uri =
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

      res = await http
          .get(uri, headers: R34Const.headers)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      HttpTraceUtil.handleConnectionError(e);
    }

    if (res == null || res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res?.statusCode ?? -1);
      return [];
    }
    return R34VideoListParser.parseDocToVideo(ParseType.favorite,
        body: res.body);
  }
}
