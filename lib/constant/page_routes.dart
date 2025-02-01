import 'package:flutter/material.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/page/index_page.dart';
import 'package:r34_video/page/login_page.dart';
import 'package:r34_video/page/my_info_page.dart';

class PageRoutes {
  static const String indexPage = '/index';
  static const String detailPage = '/detail';
  static const String loginPage = '/login';
  static const String myInfoPage = '/myInfo';

  static final Map<String, WidgetBuilder> routes = {
    indexPage: (context) => const IndexPage(),
    detailPage: (context) => const DetailPage(),
    loginPage: (context) => const LoginPage(),
    myInfoPage: (context) => const MyInfoPage(),
  };
}
