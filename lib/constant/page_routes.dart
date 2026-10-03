import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/page/community_user_page.dart';
import 'package:r34_video/page/cookie_settings_page.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/page/index_page.dart';
import 'package:r34_video/page/login_page.dart';
import 'package:r34_video/page/my_info_page.dart';
import 'package:r34_video/page/search_edit_page.dart';
import 'package:r34_video/page/search_result_page.dart';
import 'package:r34_video/page/settings_page.dart';
import 'package:r34_video/player/player_page.dart';
import 'package:r34_video/provider/search_edit_provider.dart';

class PageRoutes {
  static const String indexPage = '/index';
  static const String detailPage = '/detail';
  static const String playerPage = '/player';
  static const String loginPage = '/login';
  static const String myInfoPage = '/myInfo';
  static const String communityUserPage = '/communityUser';
  static const String searchEditPage = '/searchEdit';
  static const String searchResultPage = '/searchResult';
  static const String settingsPage = '/settings';
  static const String cookieSettingsPage = '/cookieSettings';

  static final Map<String, WidgetBuilder> routes = {
    indexPage: (context) => const IndexPage(),
    detailPage: (context) => const DetailPage(),
    playerPage: (context) => const PlayerPage(),
    loginPage: (context) => const LoginPage(),
    myInfoPage: (context) => const MyInfoPage(),
    communityUserPage: (context) => const CommunityUserPage(),
    searchEditPage: (context) => ChangeNotifierProvider<SearchEditProvider>(
          create: (context) => SearchEditProvider(),
          child: const SearchEditPage(),
        ),
    searchResultPage: (context) => const SearchResultPage(),
    settingsPage: (context) => const SettingsPage(),
    cookieSettingsPage: (context) => const CookieSettingsPage(),
  };
}
