import 'dart:convert';
import 'dart:developer';

import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/util/http_trace_util.dart';
import 'package:r34_video/util/toast_util.dart';

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

      Map<String, String> downloadUrls = {};
      final tabVideoInfo = document.getElementById('tab_video_info')!;
      for (var labelDiv in tabVideoInfo.querySelectorAll('div.label')) {
        if (labelDiv.text == 'Download') {
          for (var tagItem in labelDiv.parent!.querySelectorAll('a.tag_item')) {
            downloadUrls[tagItem.text] = tagItem.attributes['href']!;
          }
          break;
        }
      }

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

      R34VideoInfo videoInfo = R34VideoInfo(
          title: titleEle.text,
          downloadUrls: downloadUrls,
          thumbImageUrl: jsonInfo['preview_url']);
      log('getVideoInfo: ${jsonEncode(videoInfo.toJson())}');
      return videoInfo;
    } catch (e) {
      ToastUtil.showToast('Load Video Error, Please Contact Developer');
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
