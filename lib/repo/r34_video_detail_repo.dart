import 'package:flutter/foundation.dart';

import 'package:html/parser.dart' as parser;
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/r34_video_list_parser.dart';

class R34VideoDetailRepo {
  static Future<R34VideoInfo?> getVideoInfo(String detailUrl) async {
    try {
      final res = await R34Client.instance.get(Uri.parse(detailUrl));
      if (res.statusCode != 200) {
        HttpTraceUtil.handleHttpError(res.statusCode);
        return null;
      }
      return _parse(res.body);
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return null;
    }
  }

  static R34VideoInfo? _parse(String resBody) {
    try {
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

      // 解析 Web 播放链接（kt_player 播放器用的那套地址）。
      //
      // 实测站点 flashvars 里 video_url / video_alt_url* 已是带鉴权参数的完整
      // 直链（形如 get_file/58/<cs>/.../<id>_<w>[p].mp4?v-acctoken=...），
      // 不再需要 function/0/ 前缀 + cs 置换那套旧逻辑。
      final playUrls = <String, String>{};
      final urlPattern = RegExp(r'_(\d+)p?\.mp4');
      for (var entry in jsonInfo.entries) {
        final isPlayerKey = entry.key == 'video_url' ||
            (entry.key.startsWith('video_alt_url') &&
                !entry.key.endsWith('_text'));
        if (!isPlayerKey) {
          continue;
        }
        final value = entry.value.trim();
        if (!value.startsWith('https://')) {
          continue;
        }
        final match = urlPattern.firstMatch(value);
        if (match == null || match.groupCount < 1) {
          continue;
        }
        playUrls['${match.group(1)}p'] = value;
      }

      // 解析相关视频数据
      final relatedVideos =
          R34VideoListParser.parseDocToRelatedVideo(doc: document);

      R34VideoInfo videoInfo = R34VideoInfo(
        title: titleEle.text,
        downloadUrls: downloadUrls,
        playUrls: playUrls,
        thumbImageUrl: jsonInfo['preview_url'],
        artistInfos: artistInfos,
        uploaderInfo: uploaderInfo,
        categories: categories,
        tags: tags,
        relatedVideos: relatedVideos,
      );
      return videoInfo;
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
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

  /// 供单元测试直接驱动 HTML 解析（不发起网络请求）。
  @visibleForTesting
  static R34VideoInfo? parseForTest(String html) => _parse(html);
}
