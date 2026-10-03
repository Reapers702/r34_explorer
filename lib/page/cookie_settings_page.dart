import 'package:flutter/material.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/provider/login_user_provider.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/repo/cookie_store.dart';
import 'package:r34_video/repo/cookie_webview_provider.dart';
import 'package:r34_video/repo/local_repo.dart';
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';
import 'package:r34_video/util/log_util.dart';

/// Cookie 管理页。
///
/// 站点的 Cloudflare/DDG 风控 cookie 一旦过期，所有列表/搜索/详情都会失败。
/// 早期那份 cookie 是硬编码在代码里的，用户除了改代码毫无办法。这个页面给了
/// 三条出路：网页登录自动抓取、手动粘贴、清空重来。
class CookieSettingsPage extends StatefulWidget {
  const CookieSettingsPage({super.key});

  @override
  State<CookieSettingsPage> createState() => _CookieSettingsPageState();
}

class _CookieSettingsPageState extends State<CookieSettingsPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 确保已经读过本地存储，页面上的数量才是准的。
    CookieStore.load().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _run(Future<void> Function() action, String successText) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        _snack(successText);
      }
    } catch (e, st) {
      LogUtil.error('cookie action failed: $e\n$st');
      if (mounted) {
        _snack('操作失败：$e');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _loginByWebView() async {
    final provider = CookieWebViewProvider.instance;
    if (!provider.available) {
      _snack('当前构建没有内置网页登录，请先「手动粘贴 Cookie」');
      return;
    }

    final loginUser = context.read<LoginUserProvider>();

    final result = await provider.loginAndCapture(context);
    if (result == null || !mounted) {
      return;
    }

    await _run(() async {
      await CookieStore.replaceFromString(result.cookieText);
      if (result.userId != null) {
        loginUser.setUserId(result.userId);
      }
      if (result.displayName != null) {
        loginUser.setDisplayName(result.displayName);
      }
    }, '已从网页登录抓取 Cookie');
  }

  Future<void> _importManually() async {
    final controller = TextEditingController(
      text: CookieStore.hasCookies ? CookieStore.toHeaderValue() : '',
    );

    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('粘贴 Cookie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '在浏览器打开 rule34video.com 并登录，F12 → Network → 任意请求 → '
              'Request Headers 里的 Cookie 整行复制过来。',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textHint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 6,
              minLines: 4,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                hintText: '__ddg1_=...; PHPSESSID=...; kt_ips=...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (text == null || text.isEmpty || !mounted) {
      return;
    }

    await _run(() async {
      await CookieStore.replaceFromString(text);
      // 顺带刷新登录态：能拿到 userId 就说明 cookie 有效。
      final isLogin = await LocalUserRepo.isLogin();
      if (isLogin && mounted) {
        final login = context.read<LoginUserProvider>();
        login.setUserId(await LocalUserRepo.getUserId());
        login.setDisplayName(await LocalUserRepo.getDisplayName());
      }
    }, 'Cookie 已保存');
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空 Cookie'),
        content: const Text('清空后需要重新获取，否则请求可能被站点拦截。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await _run(() async {
      await CookieStore.clear();
      if (mounted) {
        context.read<LoginUserProvider>().logout();
      }
    }, 'Cookie 已清空');
  }

  /// 用当前 cookie 拉一次首页，判断是否还有效。
  Future<void> _testConnection() async {
    await _run(() async {
      final response = await R34Client.instance
          .get(Uri.https('rule34video.com', '/'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      // 站点被风控拦下时会返回验证页，用标题做个粗判断。
      final body = response.body.toLowerCase();
      if (body.contains('just a moment') ||
          body.contains('cf-challenge') ||
          body.contains('checking your browser')) {
        throw Exception('被站点风控拦截，需要重新获取 Cookie');
      }
    }, '连接正常，Cookie 可用');
  }

  @override
  Widget build(BuildContext context) {
    final count = CookieStore.length;
    final hasProtection = CookieStore.hasProtectionCookie;
    final cookies = CookieStore.all;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cookie 与登录')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          const SectionHeader(title: '当前状态'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasProtection
                            ? Icons.verified_user_outlined
                            : Icons.gpp_maybe_outlined,
                        size: 18,
                        color: hasProtection
                            ? AppColors.success
                            : AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        hasProtection ? '已包含风控 Cookie' : '缺少风控 Cookie（__ddg*）',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: hasProtection
                              ? AppColors.textPrimary
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '共 $count 条 cookie',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                    ),
                  ),
                  if (cookies.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: cookies.entries
                          .map((e) => AppChip.text(e.key, fontSize: 11))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SectionHeader(title: '获取方式'),
          _buildAction(
            icon: Icons.login_rounded,
            title: '网页登录并自动抓取',
            subtitle: CookieWebViewProvider.instance.available
                ? '在内置浏览器里登录站点，自动保存 Cookie'
                : '当前构建未内置浏览器内核',
            enabled: CookieWebViewProvider.instance.available,
            onTap: _loginByWebView,
          ),
          _buildAction(
            icon: Icons.content_paste_rounded,
            title: '手动粘贴 Cookie',
            subtitle: '从浏览器复制 Cookie 整行，最可靠',
            onTap: _importManually,
          ),
          _buildAction(
            icon: Icons.network_check_rounded,
            title: '测试连通性',
            subtitle: '用当前 Cookie 请求首页，确认是否被风控拦截',
            onTap: _testConnection,
          ),
          _buildAction(
            icon: Icons.delete_outline_rounded,
            title: '清空 Cookie',
            subtitle: '清空后需重新获取',
            destructive: true,
            onTap: _clear,
          ),
          if (!CookieWebViewProvider.instance.available)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: AppStateView.error(
                icon: Icons.info_outline_rounded,
                title: '关于网页登录',
                description:
                    '内置浏览器需要 flutter_inappwebview 依赖。当前构建没有它时，'
                    '「手动粘贴 Cookie」同样可用，效果一样。',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
    bool destructive = false,
  }) {
    final color = destructive
        ? AppColors.error
        : (enabled ? AppColors.textPrimary : AppColors.textHint);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: destructive ? AppColors.error : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textHint,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
