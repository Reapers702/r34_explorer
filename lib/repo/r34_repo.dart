import 'dart:convert';
import 'dart:developer';

import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/repo/entity/r34_search_option.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';

class R34Repo {
  static const String host =
      'https://rule34video.com/?mode=async&function=get_block&block_id=custom_list_videos_most_recent_videos&tag_ids=&sort_by=post_date';
  static Map<String, String> headers = {
    'accept': '*/*',
    'accept-language': 'zh-CN,zh;q=0.9',
    'cookie':
        '__ddg9_=89.185.25.139; __ddg1_=yth3oyQ9pnKVfRopt7kS; PHPSESSID=thbeskm7a9gm2kg4o9mvt3l6d3; kt_ips=89.185.25.139; kt_tcookie=1; _ga=GA1.1.1262203059.1737562572; kt_rt_popAccess=1; _ga_QKBWZM1667=GS1.1.1737562571.1.1.1737562576.0.0.0; __ddg8_=mM1NTjMIvsZXLPWK; __ddg10_=1737562600',
    'priority': 'u=1, i',
    'referer': 'https://rule34video.com/',
    'sec-ch-ua':
        '"Not A(Brand";v="8", "Chromium";v="132", "Microsoft Edge";v="132"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-origin',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36 Edg/132.0.0.0',
    'x-requested-with': 'XMLHttpRequest',
  };

  static Future<R34Page> getPage(R34SearchOption option) async {
    http.Response? res;
    try {
      res = await http.get(
        Uri.parse('$host&_=${DateTime.now().millisecondsSinceEpoch}'),
        headers: headers,
      );
    } catch (e) {
      log('getPageError: $e');
    }

    final document = parser.parse(res!.body);
    final listVideo =
        document.getElementById('custom_list_videos_most_recent_videos_items');
    final aThList = listVideo!.querySelectorAll('a.th.js-open-popup');
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

    final r34Page = R34Page(videos: data);
    log('getPage: ${jsonEncode(r34Page.toJson())}');
    return r34Page;
  }

  static Future<R34VideoInfo> getVideoInfo(String detailUrl) async {
    http.Response? res;
    try {
      res = await http.get(Uri.parse(detailUrl), headers: headers);
    } catch (e) {
      log('getVideoInfoError: $e');
    }

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
