import 'package:flutter/material.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/page/index_page.dart';
import 'package:r34_video/page/temp_page.dart';

class PageRoutes {
  static const String indexPage = '/index';
  static const String detailPage = '/detail';
  static const String tempPage = '/temp';

  static final Map<String, WidgetBuilder> routes = {
    indexPage: (context) => const IndexPage(),
    detailPage: (context) => const DetailPage(),
    tempPage: (context) => const TempPage(),
  };
}
