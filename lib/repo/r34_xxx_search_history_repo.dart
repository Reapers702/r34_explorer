import 'dart:convert';

import 'package:r34_video/util/log_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// rule34.xxx 图片站的「最近 tag 搜索」历史。
///
/// 与视频站（rule34video）的 `R34SearchEditRepo` 分开：图片站是 tag 组合搜索，
/// 存的是空格分隔的 tag 串（如 `ada_wong animation`），两站的匹配规则本就不一致。
class R34XxxSearchHistoryRepo {
  R34XxxSearchHistoryRepo._();

  static const String _key = 'r34xxx_search_history';

  /// 上限条数，超出丢最旧。
  static const int _max = 20;

  static List<String> _history = [];
  static bool _loaded = false;

  static Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        _history = (jsonDecode(raw) as List)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList();
      }
    } catch (e, st) {
      LogUtil.error('load xxx search history failed: $e\n$st');
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_history));
    } catch (e, st) {
      LogUtil.error('persist xxx search history failed: $e\n$st');
    }
  }

  static Future<List<String>> getHistory() async {
    await _ensureLoaded();
    return List.unmodifiable(_history);
  }

  /// 记一条 tag 组合：去重移到最前，超出上限丢最旧。
  static Future<void> addSearchHistory(String tags) async {
    final text = tags.trim();
    if (text.isEmpty) {
      return;
    }
    await _ensureLoaded();
    _history.removeWhere((e) => e == text);
    _history.insert(0, text);
    if (_history.length > _max) {
      _history.removeRange(_max, _history.length);
    }
    await _persist();
  }

  static Future<void> removeSearchHistory(String tags) async {
    await _ensureLoaded();
    final before = _history.length;
    _history.removeWhere((e) => e == tags);
    if (_history.length != before) {
      await _persist();
    }
  }

  static Future<void> clearSearchHistory() async {
    await _ensureLoaded();
    if (_history.isEmpty) {
      return;
    }
    _history = [];
    await _persist();
  }
}