import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/provider/login_user_provider.dart';
import 'package:r34_video/provider/settings_provider.dart';
import 'package:r34_video/repo/cookie_store.dart';
import 'package:r34_video/repo/site_registry.dart';
import 'package:r34_video/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // package:media_kit 的初始化，必须在 runApp 之前完成。
  MediaKit.ensureInitialized();

  // 先把 cookie 读出来，之后所有请求都从它取（避免首个请求漏带 cookie 被风控拦）。
  await CookieStore.load();

  // 恢复上次选择的站点。
  await SiteRegistry.instance.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LoginUserProvider()),
        ChangeNotifierProvider(create: (context) => SettingsProvider()),
      ],
      child: const R34App(),
    ),
  );
}

class R34App extends StatelessWidget {
  const R34App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rule34 Explorer',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      routes: PageRoutes.routes,
      initialRoute: PageRoutes.indexPage,
    );
  }
}
