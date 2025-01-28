import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:r34_video/page/home_page.dart';
import 'package:r34_video/page/user_page.dart';

enum TabEnum {
  homePage(),
  userPage(),
}

class TabConst {
  static const List<Widget> pages = [
    HomePage(),
    UserPage(),
  ];
  static LinkedHashMap<TabEnum, MapEntry<String, IconData>> tabs =
      LinkedHashMap.from({
    TabEnum.homePage: const MapEntry('首页', Icons.home_outlined),
    TabEnum.userPage: MapEntry('我的', Icons.person_outline_outlined),
  });
}
