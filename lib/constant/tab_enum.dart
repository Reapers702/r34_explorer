import 'dart:collection';

import 'package:flutter/material.dart';

/// 底部导航项。
///
/// 注意：首页对应的具体页面不在这里写死 —— 它取决于当前站点
/// （rule34video / rule34.xxx 各有一套首页），由 `IndexPage` 决定。
/// 这里只负责“有哪几个 tab”。
enum TabEnum {
  homePage,
  userPage,
}

class TabConst {
  static const int homeTabIndex = 0;
  static const int userTabIndex = 1;

  static LinkedHashMap<TabEnum, MapEntry<String, IconData>> tabs =
      LinkedHashMap.from({
    TabEnum.homePage: const MapEntry('首页', Icons.home_outlined),
    TabEnum.userPage: const MapEntry('我的', Icons.person_outline_outlined),
  });
}
