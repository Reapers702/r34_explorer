import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:r34_video/util/log_util.dart';

/// 设置项。
///
/// 之前 `settingsModel` 是可空的，页面里到处 `settingsModel!`，只要用户在
/// 读取完成前点了播放就会崩。现在给 `SettingsProvider` 一个立即可用的默认值，
/// 之后再异步覆盖成已保存的值。
class SettingsProvider extends ChangeNotifier {
  static const String _prefsKey = 'settings_content';

  late SettingsModel settingsModel = SettingsModel.defaultSettings();

  bool _loaded = false;

  /// 是否已经从本地读过一次设置。
  bool get loaded => _loaded;

  SettingsProvider() {
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final content = prefs.getString(_prefsKey);
      if (content != null && content.isNotEmpty) {
        settingsModel = SettingsModel.fromJson(
          jsonDecode(content) as Map<String, dynamic>,
        );
      }
    } catch (e, st) {
      LogUtil.error('restore settings failed: $e\n$st');
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<bool> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_prefsKey, jsonEncode(settingsModel.toJson()));
  }

  Future<void> _update(VoidCallback mutate) async {
    mutate();
    notifyListeners();
    await saveSettings();
  }

  // ---- 播放 ----

  set playUrlType(PlayUrlType value) =>
      _update(() => settingsModel.playUrlType = value);

  set parseAutoRedirect(bool value) =>
      _update(() => settingsModel.parseAutoRedirect = value);

  set autoPlay(bool value) => _update(() => settingsModel.autoPlay = value);

  set preferredQuality(String? value) =>
      _update(() => settingsModel.preferredQuality = value);
}

class SettingsModel {
  PlayUrlType playUrlType;
  bool parseAutoRedirect;

  /// 进入播放页后是否自动开始播放。
  bool autoPlay;

  /// 首选清晰度标签（例如 `720p`），`null` 表示总是用最高清晰度。
  String? preferredQuality;

  String version = '1.0.0';

  SettingsModel({
    PlayUrlType? playUrlType,
    bool? parseAutoRedirect,
    bool? autoPlay,
    this.preferredQuality,
  })  : playUrlType = playUrlType ?? PlayUrlType.webPlay,
        parseAutoRedirect = parseAutoRedirect ?? true,
        autoPlay = autoPlay ?? true;

  factory SettingsModel.defaultSettings() {
    return SettingsModel(
      playUrlType: PlayUrlType.webPlay,
      parseAutoRedirect: true,
      autoPlay: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playUrlType': playUrlType.name,
      'parseAutoRedirect': parseAutoRedirect,
      'autoPlay': autoPlay,
      'preferredQuality': preferredQuality,
      'version': version,
    };
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      playUrlType: PlayUrlType.values
          .where((e) => e.name == json['playUrlType'])
          .firstOrNull,
      parseAutoRedirect: json['parseAutoRedirect'] ?? true,
      autoPlay: json['autoPlay'] ?? true,
      preferredQuality: json['preferredQuality'] as String?,
    );
  }
}

enum PlayUrlType {
  /// 走网页解析出来的直链（推荐，站点的 `get_file` 会自动 302 到 CDN）。
  webPlay,

  /// 走下载链接。
  download,
  ;

  static final Map<PlayUrlType, String> _descMap = {
    PlayUrlType.webPlay: '网页解析',
    PlayUrlType.download: '下载链接',
  };

  String get desc => _descMap[this]!;
}
