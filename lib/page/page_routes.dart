import 'package:drag_bottom_sheet/page/detail_page.dart';
import 'package:drag_bottom_sheet/page/home_page.dart';
import 'package:flutter/material.dart';

class PageRoutes {
  static const String homePage = '/home';
  static const String detailPage = '/detail';

  static final Map<String, WidgetBuilder> routes = {
    homePage: (context) => const HomePage(),
    detailPage: (context) => const DetailPage(),
  };
}
