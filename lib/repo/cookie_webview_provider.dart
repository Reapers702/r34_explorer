import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:r34_video/page/webview_login_page.dart';

/// 网页登录抓取 cookie 的结果。
class CookieLoginResult {
  /// 完整的 `a=1; b=2` cookie 串。
  final String cookieText;

  /// 能识别出来就带上，用于同步登录态。
  final int? userId;
  final String? displayName;

  /// 用户登录时用的用户名，可用于展示。
  final String? username;

  const CookieLoginResult({
    required this.cookieText,
    this.userId,
    this.displayName,
    this.username,
  });
}

/// 「打开站点网页 → 用户登录 → 抓取 cookie」的能力接口。
///
/// 做成接口是因为内置浏览器要额外依赖；没有该依赖的构建用
/// [UnavailableCookieWebViewProvider]，页面照常可用，走「手动粘贴 Cookie」。
abstract class CookieWebViewProvider {
  const CookieWebViewProvider();

  /// 当前平台/构建是否具备内置浏览器。
  bool get available;

  /// 打开站点让用户登录，返回抓到的 cookie；用户取消则返回 null。
  Future<CookieLoginResult?> loginAndCapture(BuildContext context);

  /// 默认实现。
  ///
  /// 移动端用内置 WebView；Windows 上插件（0.6.0）也支持我们用到的那几个回调
  /// 和 CookieManager，所以一并开启 —— 但桌面端若取不到 cookie，页面会提示
  /// 并引导走「手动粘贴」，不会卡死。
  static CookieWebViewProvider instance = _createDefault();

  static CookieWebViewProvider _createDefault() {
    try {
      if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) {
        return const InAppCookieWebViewProvider();
      }
    } catch (_) {
      // Web 等没有 dart:io Platform 的环境，落到「不可用」。
    }
    return const UnavailableCookieWebViewProvider();
  }
}

class UnavailableCookieWebViewProvider extends CookieWebViewProvider {
  const UnavailableCookieWebViewProvider();

  @override
  bool get available => false;

  @override
  Future<CookieLoginResult?> loginAndCapture(BuildContext context) async => null;
}

/// 基于 `flutter_inappwebview` 的真实实现。
class InAppCookieWebViewProvider extends CookieWebViewProvider {
  const InAppCookieWebViewProvider();

  @override
  bool get available => true;

  @override
  Future<CookieLoginResult?> loginAndCapture(BuildContext context) async {
    final cookieText = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const WebViewLoginPage()),
    );
    if (cookieText == null || cookieText.trim().isEmpty) {
      return null;
    }
    return CookieLoginResult(cookieText: cookieText);
  }
}
