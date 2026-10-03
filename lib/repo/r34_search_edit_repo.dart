import 'dart:developer';

import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tuple/tuple.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

class R34SearchEditRepo {
  static const int _maxHistoryCount = 20;

  static Future<List<String>> getSearchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('searchHistory') ?? [];
  }

  static Future<bool> addSearchHistory(String searchText) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> searchHistory = prefs.getStringList('searchHistory') ?? [];
    searchHistory.remove(searchText);
    searchHistory.insert(0, searchText);
    if (searchHistory.length > _maxHistoryCount) {
      searchHistory.removeLast();
    }
    return prefs.setStringList('searchHistory', searchHistory);
  }

  static Future<bool> removeSearchHistory(String searchText) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> searchHistory = prefs.getStringList('searchHistory') ?? [];
    searchHistory.remove(searchText);
    return prefs.setStringList('searchHistory', searchHistory);
  }

  static Future<bool> clearSearchHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.remove('searchHistory');
  }

  static Future<
          Tuple3<List<VideoTag>, List<VideoCategory>, List<VideoArtistInfo>>>
      getTrendingData() async {
    http.Response? res;
    try {
      res = await R34Client.instance.get(Uri.https(R34Const.host, '/'));
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
    }

    if (res == null || res.statusCode != 200) {
      HttpTraceUtil.handleHttpError(res?.statusCode ?? -1);
      return Tuple3([], [], []);
    }

    try {
      List<VideoTag> tags = [];
      List<VideoCategory> categories = [];
      List<VideoArtistInfo> artists = [];
      final doc = parser.parse(res.body);
      final sideBar = doc.getElementsByClassName('sidebar-aside')[0];

      try {
        final searchCloud = sideBar.getElementsByClassName('search-cloud')[0];
        for (var btn in searchCloud.querySelectorAll('a.button')) {
          final href = btn.attributes['href'];
          final id = href!.split('/').lastWhere((e) => e.isNotEmpty);
          tags.add(VideoTag(btn.text, id));
        }
      } catch (e, st) {
        log('parse tags error: $st');
      }

      try {
        final categoryWrap = sideBar.getElementsByClassName('aside_wrap')[0];
        for (var btnEl in categoryWrap.querySelectorAll('a.item:not(.all)')) {
          final href = btnEl.attributes['href'];
          final id = href!.split('/').lastWhere((e) => e.isNotEmpty);
          final imgEl = btnEl.getElementsByTagName('img')[0];
          categories.add(VideoCategory(
            id,
            imgEl.attributes['alt']!,
            imgEl.attributes['src']!,
          ));
        }
      } catch (e, st) {
        log('parse categories error: $st');
      }

      try {
        final artistWrap = sideBar.getElementsByClassName('aside_wrap')[1];
        for (var btnEl in artistWrap.querySelectorAll('a.item:not(.all)')) {
          final href = btnEl.attributes['href'];
          final id = href!.split('/').lastWhere((e) => e.isNotEmpty);
          final imgEl = btnEl.getElementsByTagName('img')[0];
          artists.add(VideoArtistInfo(
            id,
            imgEl.attributes['alt']!,
            imgEl.attributes['src']!,
          ));
        }
      } catch (e, st) {
        log('parse artists error: $st');
      }

      return Tuple3(tags, categories, artists);
    } catch (e, st) {
      log('getTrendingData Error: $st');
      return Tuple3([], [], []);
    }
  }
}
