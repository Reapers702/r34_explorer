import 'dart:developer';

import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_community_user.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/util/http_trace_util.dart';

enum _ParseType {
  favorite,
  upload,
  ;

  String get parseId => {
        favorite: 'list_videos_favourite_videos_items',
        upload: 'list_videos_uploaded_videos_items'
      }[this]!;
}

class R34CommunityRepo {
  static const int _pageSize = 24;
  static final RegExp _ratingInfoReg = RegExp(r'(\d+%)[ ]+\(([\d\w]+)\)');
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
      final avatarUrl = doc.querySelector('div.avatar img')!.attributes['src'];
      final subscriberCount = doc
          .querySelector('div.subscribers_count')!
          .text
          .replaceAll('Subscribers', '')
          .trim();
      final totalResultSpans = doc.querySelectorAll('span.total_results');
      final uploadCount =
          totalResultSpans[0].text.replaceAll(RegExp(r'[()]'), '');
      final favoriteCount = totalResultSpans
              .elementAtOrNull(1)
              ?.text
              .replaceAll(RegExp(r'[()]'), '') ??
          '0';

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
    return _parseDocToVideo(res.body, _ParseType.upload);
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
    return _parseDocToVideo(res.body, _ParseType.favorite);
  }

  static List<R34CommunityVideo> _parseDocToVideo(
      String body, _ParseType parseType) {
    log('_parseDocToVideo start');
    try {
      final doc = parser.parse(body);
      final videoParentEl = doc.getElementById(parseType.parseId);
      final aThList = videoParentEl!.querySelectorAll('a.th.js-open-popup');
      List<R34CommunityVideo> data = [];

      for (var aTh in aThList) {
        String title = aTh.attributes['title']!;
        String detailUrl = aTh.attributes['href']!;
        String thumbPreviewUrl =
            aTh.querySelector('img.thumb.lazy-load')!.attributes['data-webp']!;
        String videoDuration = aTh.querySelector('div.time')!.text;

        String uploadTime = aTh.querySelector('div.added')!.text.trim();
        String viewCount = aTh.querySelector('div.views')!.text.trim();
        String ratingInfo = aTh.querySelector('div.rating')!.text.trim();
        final match = _ratingInfoReg.firstMatch(ratingInfo);
        String ratingScore = match != null ? match[1]! : '';
        String ratingCount = match != null ? match[2]! : '';

        data.add(R34CommunityVideo(
          title: title,
          detailUrl: detailUrl,
          thumbImageUrl: thumbPreviewUrl,
          duration: videoDuration,
          viewCount: viewCount,
          rating: ratingScore,
          ratingCount: ratingCount,
          uploadTime: uploadTime,
        ));
      }
      return data;
    } catch (e) {
      log('_parseDocToVideo Error: $e');
      return [];
    }
  }
}
