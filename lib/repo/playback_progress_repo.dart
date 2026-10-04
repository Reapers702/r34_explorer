import 'dart:convert';

import 'package:r34_video/util/log_util.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 播放进度记忆：按视频的 detailUrl 记住上次看到哪，下次续播。
///
/// 只存「值得续播」的进度：
/// * 进度不足 5 秒不记（误触/没怎么看）；
/// * 进度超过时长的 92% 视为「基本看完」，清掉旧进度不再续播。
class PlaybackProgressRepo {
  PlaybackProgressRepo._();

  static const String _key = 'playback_progress';

  static Map<String, int> _progress = {};
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
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _progress = decoded.map(
          (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
        );
      }
    } catch (e, st) {
      LogUtil.error('load playback progress failed: $e\n$st');
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_progress));
    } catch (e, st) {
      LogUtil.error('persist playback progress failed: $e\n$st');
    }
  }

  /// 取要续播的位置；没有「值得续播」的进度时返回 null。
  static Future<Duration?> getResume(String key) async {
    if (key.isEmpty) {
      return null;
    }
    await _ensureLoaded();
    final ms = _progress[key] ?? 0;
    if (ms < 5000) {
      return null;
    }
    return Duration(milliseconds: ms);
  }

  /// 记录播放位置；接近看完会清掉记录，重新打开从头播。
  static Future<void> save(
    String key,
    Duration position,
    Duration duration,
  ) async {
    if (key.isEmpty) {
      return;
    }
    await _ensureLoaded();
    final ms = position.inMilliseconds;
    if (ms < 5000) {
      return;
    }
    if (duration > Duration.zero &&
        ms > duration.inMilliseconds * 0.92) {
      _progress.remove(key);
    } else {
      _progress[key] = ms;
    }
    await _persist();
  }
}