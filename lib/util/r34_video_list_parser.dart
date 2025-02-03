import 'dart:developer';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/repo/entity/r34_community_video.dart';

enum ParseType {
  favorite,
  upload,
  related,
  ;

  String get parseId => {
        favorite: 'list_videos_favourite_videos_items',
        upload: 'list_videos_uploaded_videos_items',
        related: 'custom_list_videos_related_videos_items',
      }[this]!;
}

class R34VideoListParser {
  static final RegExp _ratingInfoReg = RegExp(r'(\d+%)[ ]+\(([\d\w]+)\)');

  static List<R34CommunityVideo> parseDocToVideo(ParseType parseType,
      {String? body, dom.Document? doc}) {
    log('_parseDocToVideo start');
    try {
      doc ??= parser.parse(body!);
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
    } catch (e, st) {
      log('_parseDocToVideo Error: $e, stackTrace: $st');
      return [];
    }
  }

  static List<R34CommunityVideo> parseDocToRelatedVideo(
      {String? body, dom.Document? doc}) {
    log('_parseDocToVideo start');
    try {
      doc ??= parser.parse(body!);
      final videoParentEl = doc.getElementById(ParseType.related.parseId);
      final aThList = videoParentEl!.querySelectorAll('a.th');
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
    } catch (e, st) {
      log('_parseDocToVideo Error: $e, stackTrace: $st');
      return [];
    }
  }
}
