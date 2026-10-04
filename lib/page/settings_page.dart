import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_select_tile.dart';
import 'package:r34_video/provider/login_user_provider.dart';
import 'package:r34_video/provider/settings_provider.dart';
import 'package:r34_video/repo/cookie_store.dart';
import 'package:r34_video/repo/site_registry.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settingsModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          const _SettingsSectionTitle('播放'),
          _SettingsCard(
            children: [
              _SettingsNavTile(
                icon: Icons.link_rounded,
                title: '播放地址来源',
                value: settings.playUrlType.desc,
                onTap: () => _showPlayUrlTypeDialog(context),
              ),
              const _SettingsDivider(),
              _SettingsSwitchTile(
                icon: Icons.play_circle_outline_rounded,
                title: '进入播放页自动播放',
                subtitle: '关掉后需要手动点一下播放',
                value: settings.autoPlay,
                onChanged: (value) =>
                    context.read<SettingsProvider>().autoPlay = value,
              ),
              const _SettingsDivider(),
              _SettingsNavTile(
                icon: Icons.high_quality_rounded,
                title: '首选清晰度',
                value: settings.preferredQuality ?? '自动（最高）',
                onTap: () => _showQualityDialog(context),
              ),
              const _SettingsDivider(),
              _SettingsSwitchTile(
                icon: Icons.sync_alt_rounded,
                title: '播放链接自动重定向',
                subtitle: '解析 get_file 的真实 CDN 地址',
                value: settings.parseAutoRedirect,
                onChanged: (value) =>
                    context.read<SettingsProvider>().parseAutoRedirect = value,
              ),
            ],
          ),
          const _SettingsSectionTitle('数据源'),
          _SettingsCard(
            children: [
              _SettingsNavTile(
                icon: Icons.dns_outlined,
                title: '当前站点',
                value: SiteRegistry.instance.current.displayName,
                onTap: () => showSiteSwitcher(context),
              ),
              const _SettingsDivider(),
              _SettingsNavTile(
                icon: Icons.info_outline_rounded,
                title: '站点说明',
                value: '视频站 / 图片站',
                onTap: () => _showSiteHelp(context),
              ),
            ],
          ),
          const _SettingsSectionTitle('账户'),
          _SettingsCard(
            children: [
              _SettingsNavTile(
                icon: Icons.account_circle_outlined,
                title: '账号',
                value: _accountLabel(context),
                onTap: () => _onAccountTap(context),
              ),
              const _SettingsDivider(),
              _SettingsNavTile(
                icon: Icons.cookie_outlined,
                title: 'Cookie 与登录',
                value: CookieStore.hasCookies
                    ? '${CookieStore.length} 条'
                    : '未设置',
                onTap: () =>
                    Navigator.of(context).pushNamed(PageRoutes.cookieSettingsPage),
              ),
            ],
          ),
          const _SettingsSectionTitle('关于'),
          const _SettingsCard(
            children: [
              _SettingsNavTile(
                icon: Icons.info_outline_rounded,
                title: '版本号',
                value: '1.0.0',
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '播放内核：media_kit (libmpv)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSiteHelp(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('两个站点'),
        content: const SingleChildScrollView(
          child: Text(
            'rule34video：视频站。需要 cookie（站点有风控），登录/粘贴 cookie 后可用。\n'
            '播放走内置 player。\n\n'
            'rule34.xxx：图片站。走公开 JSON 接口，无需登录；标签搜索、看图。\n\n'
            '两者内容与服务端完全独立，切换只影响“首页”这一栏；'
            '账号与设置对两边都适用。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _accountLabel(BuildContext context) {
    final login = context.watch<LoginUserProvider>();
    return login.displayName ?? '未登录';
  }

  void _onAccountTap(BuildContext context) {    final login = context.read<LoginUserProvider>();
    Navigator.of(context).pushNamed(
      login.displayName == null ? PageRoutes.loginPage : PageRoutes.myInfoPage,
    );
  }

  Future<void> _showPlayUrlTypeDialog(BuildContext context) async {
    final provider = context.read<SettingsProvider>();
    final selected = await showDialog<PlayUrlType>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('播放地址来源'),
        children: PlayUrlType.values
            .map(
              (type) => AppSelectTile<PlayUrlType>(
                value: type,
                selectedValue: provider.settingsModel.playUrlType,
                title: type.desc,
                onSelected: (value) => Navigator.of(dialogContext).pop(value),
              ),
            )
            .toList(),
      ),
    );
    if (selected != null) {
      provider.playUrlType = selected;
    }
  }

  Future<void> _showQualityDialog(BuildContext context) async {
    final provider = context.read<SettingsProvider>();
    const options = <String?, String>{
      null: '自动（最高清晰度）',
      '1080p': '1080p',
      '720p': '720p',
      '480p': '480p',
      '360p': '360p',
    };

    final selected = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('首选清晰度'),
        children: options.entries
            .map(
              (entry) => AppSelectTile<String?>(
                value: entry.key,
                selectedValue: provider.settingsModel.preferredQuality,
                title: entry.value,
                onSelected: (value) => Navigator.of(dialogContext).pop(value),
              ),
            )
            .toList(),
      ),
    );

    if (selected != null || provider.settingsModel.preferredQuality != null) {
      provider.preferredQuality = selected;
    }
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  final String title;

  const _SettingsSectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page + AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 52),
      child: Divider(height: 1),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 14.5),
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppColors.textHint),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textHint,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14.5)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
