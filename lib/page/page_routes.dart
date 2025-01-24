import 'package:flutter/material.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/page/home_page.dart';

class PageRoutes {
  static const String homePage = '/home';
  static const String detailPage = '/detail';

  static final Map<String, WidgetBuilder> routes = {
    homePage: (context) => const HomePage(),
    detailPage: (context) => const DetailPage(),
  };
}
