import 'dart:developer';

import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/r34_video_list_parser.dart';

class R34VideoDetailRepo {
  static Future<R34VideoInfo?> getVideoInfo(String detailUrl) async {
    http.Response? res;
    try {
      res = await http
          .get(
            Uri.parse(detailUrl),
            headers: R34Const.headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      HttpTraceUtil.handleConnectionError(e);
    }

    try {
      final resBody = res!.body;
      final document = parser.parse(resBody);
      final titleEle = document.querySelector('h1.title_video')!;

      // 解析下载链接、Tag 及作者数据
      Map<String, String> downloadUrls = {};
      VideoUploaderInfo uploaderInfo =
          VideoUploaderInfo('-1', 'Unknown', R34Const.websiteIcon);
      List<VideoArtistInfo> artistInfos = [];
      List<VideoTag> tags = [];
      List<VideoCategory> categories = [];
      final tabVideoInfo = document.getElementById('tab_video_info')!;
      for (var labelDiv in tabVideoInfo.querySelectorAll('div.label')) {
        final parent = labelDiv.parent!;

        // 下载链接
        if (labelDiv.text == 'Download') {
          for (var tagItem in parent.querySelectorAll('a.tag_item')) {
            downloadUrls[tagItem.text] = tagItem.attributes['href']!;
          }
          continue;
        }

        // 作者数据
        if (labelDiv.text == 'Artist') {
          for (var item in parent.querySelectorAll('a.item.btn_link')) {
            final imgEl = item.getElementsByTagName('img').elementAtOrNull(0);
            final descEl = item.querySelector('span.name');
            final name = item.attributes['href']!
                .split('/')
                .lastWhere((e) => e.isNotEmpty);
            artistInfos.add(
                VideoArtistInfo(name, descEl!.text, imgEl?.attributes['src']));
          }
        }

        // 上传者数据
        if (labelDiv.text == 'Uploaded by') {
          final imgEl = parent.getElementsByTagName('img').elementAtOrNull(0);
          final btnEl = parent.querySelector('a.item.btn_link')!;
          final id = btnEl.attributes['href']!
              .split('/')
              .lastWhere((e) => e.isNotEmpty);
          uploaderInfo = VideoUploaderInfo(
              id, btnEl.text.trim(), imgEl?.attributes['src']);
        }

        // 类别数据
        if (labelDiv.text == 'Categories') {
          for (var item in parent.querySelectorAll('a.item.btn_link')) {
            final imgEl = item.getElementsByTagName('img').elementAtOrNull(0);
            final descEl = item.querySelector('span');
            final name = item.attributes['href']!
                .split('/')
                .lastWhere((e) => e.isNotEmpty);
            categories.add(
                VideoCategory(name, descEl!.text, imgEl?.attributes['src']));
          }
        }

        // Tag 数据
        if (labelDiv.text == 'Tags') {
          for (var item
              in parent.querySelectorAll('a.tag_item:not(.tag_item_suggest)')) {
            final id = item.attributes['href']!
                .split('/')
                .lastWhere((e) => e.isNotEmpty);
            tags.add(VideoTag(item.text, id));
          }
        }
      }

      // 解析视频元数据
      final startLabel = 'var flashvars =', endLabel = 'kt_player(\'kt_player';
      final jsonInfoStart = resBody.indexOf(startLabel);
      final jsonInfoEnd = resBody.indexOf(endLabel, jsonInfoStart);

      String jsonProp = resBody
          .substring(jsonInfoStart + startLabel.length, jsonInfoEnd)
          .trim();
      jsonProp = jsonProp.endsWith(';')
          ? jsonProp.substring(0, jsonProp.length - 1)
          : jsonProp;
      Map<String, String> jsonInfo = parseMap(jsonProp);

      // 解析相关视频数据
      final relatedVideos =
          R34VideoListParser.parseDocToRelatedVideo(doc: document);

      R34VideoInfo videoInfo = R34VideoInfo(
        title: titleEle.text,
        downloadUrls: downloadUrls,
        thumbImageUrl: jsonInfo['preview_url'],
        artistInfos: artistInfos,
        uploaderInfo: uploaderInfo,
        categories: categories,
        tags: tags,
        relatedVideos: relatedVideos,
      );
      // log('getVideoInfo: ${jsonEncode(videoInfo.toJson())}');
      return videoInfo;
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e);
      log('r34 video detail repo error: $detailUrl $st');
      return null;
    }
  }

  static Map<String, String> parseMap(String prop) {
    Map<String, String> re = {};
    String state = 'KEY_IDLE';
    String k = '', v = '';

    for (var rune in prop.runes) {
      final c = String.fromCharCode(rune);
      if (state == 'IDLE' || state == 'KEY_IDLE') {
        if (c == ':' || c == ',' || c.trim() == '') {
          continue;
        }
        if (c == '{') {
          state = 'KEY_IDLE';
          continue;
        }
        if (c == '}') {
          break;
        }
      }

      if (state == 'KEY_IDLE' || state == 'KEY') {
        if (c == ':') {
          state = 'VALUE_IDLE';
          continue;
        }
        k += c;
        state = 'KEY';
        continue;
      }

      if (state == 'VALUE_IDLE') {
        if (c == '\'') {
          state = 'VALUE';
          continue;
        }
      }
      if (state == 'VALUE') {
        if (c == '\'') {
          re[k] = v;
          k = v = '';
          state = 'KEY_IDLE';
          continue;
        }
        v += c;
        continue;
      }
    }
    return re;
  }
}
