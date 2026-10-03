import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';
import 'package:r34_video/util/log_util.dart';

/// 内置浏览器登录页。
///
/// 站点有 Cloudflare/DDG 风控，手填 cookie 经常因为 `__ddg*` 过期而失效。
/// 这里让用户在真实 WebView 里正常登录（该过验证过关卡），登录成功后把
/// 浏览器里所有 cookie 一次性取回来。
///
/// 返回取到的 cookie 串；用户直接返回则返回 null。
class WebViewLoginPage extends StatefulWidget {
  const WebViewLoginPage({super.key});

  @override
  State<WebViewLoginPage> createState() => _WebViewLoginPageState();
}

class _WebViewLoginPageState extends State<WebViewLoginPage> {
  InAppWebViewController? _webViewController;
  WebUri _currentUrl = WebUri(R34Const.baseUrl);
  bool _loading = true;
  bool _busy = false;

  /// 每加载完一页就把浏览器 cookie 同步到内存缓存。
  ///
  /// 不能只在最后读一次：用户点「我已登录」时可能停在第三方跳转页上，
  /// `CookieManager` 是按传入 URL 取的，那时就取不到主域的会话 cookie。
  final Map<String, String> _cookieCache = {};

  static final WebUri _loginUrl = WebUri('${R34Const.baseUrl}login/');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          return;
        }
        // 先把 Navigator 拿到手，后面跨 async gap 就不再碰 context。
        final navigator = Navigator.of(context);
        // 优先在网页内回退，回退到头了才退出登录页。
        final controller = _webViewController;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
        navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('网页登录', style: TextStyle(fontSize: 16)),
              Text(
                _currentUrl.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: const Text('返回'),
            ),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton(
                onPressed: _busy ? null : _captureCookies,
                child: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('我已登录'),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: const Text(
                    '在下方页面登录站点（如需过 Cloudflare 验证也在这里完成），'
                    '看到登录成功后再点右上角「我已登录」。',
                    style: TextStyle(fontSize: 11.5, height: 1.4),
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(url: _loginUrl),
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      domStorageEnabled: true,
                      thirdPartyCookiesEnabled: true,
                      useShouldOverrideUrlLoading: true,
                      useHybridComposition: true,
                      mediaPlaybackRequiresUserGesture: true,
                      // 站点 cookie 是按域下发的，这里不要额外覆盖 UA，
                      // 否则风控可能认为环境不一致。
                      supportZoom: true,
                      transparentBackground: false,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    shouldOverrideUrlLoading: (controller, action) async {
                      // 保持导航在 WebView 内部完成。
                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStart: (controller, url) {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _loading = true;
                        if (url != null) {
                          _currentUrl = url;
                        }
                      });
                    },
                    onLoadStop: (controller, url) async {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _loading = false;
                        if (url != null) {
                          _currentUrl = url;
                        }
                      });
                      await _snapshotCookies();
                    },
                    onReceivedError: (controller, request, error) {
                      LogUtil.warn('webview error: ${error.description}');
                    },
                    onConsoleMessage: (controller, message) {
                      LogUtil.info('[webview] ${message.message}');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _snapshotCookies() async {
    try {
      final cookies = await CookieManager.instance().getCookies(
        url: WebUri(R34Const.baseUrl),
      );
      for (final cookie in cookies) {
        if (cookie.name.isNotEmpty) {
          _cookieCache[cookie.name] = cookie.value;
        }
      }
    } catch (e, st) {
      LogUtil.warn('snapshot cookies failed: $e $st');
    }
  }

  Future<void> _captureCookies() async {
    setState(() => _busy = true);
    try {
      await _snapshotCookies();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }

    if (_cookieCache.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('还没拿到 cookie，请先在页面里完成登录')),
          );
      }
      return;
    }

    final cookieText =
        _cookieCache.entries.map((e) => '${e.key}=${e.value}').join('; ');
    if (mounted) {
      Navigator.of(context).pop(cookieText);
    }
  }
}
