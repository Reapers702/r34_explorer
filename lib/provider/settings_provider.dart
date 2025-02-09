import 'dart:convert';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider {
  SettingsModel? settingsModel;

  SettingsProvider() {
    Future.microtask(() {
      getSettings().then((value) {
        settingsModel = value;
      });
    });
  }

  Future<SettingsModel> getSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final settingsContent = prefs.getString('settings_content') ?? null;
    log('settingsContent: $settingsContent');
    if (settingsContent == null || settingsContent.isEmpty) {
      return SettingsModel.defaultSettings();
    }

    final settings = SettingsModel.fromJson(jsonDecode(settingsContent));
    log('settings: ${jsonEncode(settings.toJson())}');
    return settings;
  }

  Future<bool> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(
        'settings_content', jsonEncode(settingsModel!.toJson()));
  }
}

class SettingsModel {
  PlayUrlType playUrlType;
  String version = '1.0.0';

  SettingsModel({
    PlayUrlType? playUrlType,
  }) : playUrlType = playUrlType ?? PlayUrlType.webPlay;

  Map<String, dynamic> toJson() {
    return {
      'playUrlType': playUrlType.name,
      'version': version,
    };
  }

  factory SettingsModel.defaultSettings() {
    return SettingsModel(
      playUrlType: PlayUrlType.webPlay,
    );
  }

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    return SettingsModel(
      playUrlType: PlayUrlType.values
          .where((e) => e.name == json['playUrlType'])
          .firstOrNull,
    );
  }
}

enum PlayUrlType {
  webPlay,
  download,
  ;

  static final Map<PlayUrlType, String> _descMap = {
    PlayUrlType.webPlay: '网页解析',
    PlayUrlType.download: '下载链接',
  };
  String get desc => _descMap[this]!;
}
