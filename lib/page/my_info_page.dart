import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/community_user_page.dart';
import 'package:r34_video/provider/login_user_provider.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 「我的」页。
///
/// 已登录时直接复用 [CommunityUserPage]，未登录时给一个干净的引导页
/// （早期这里是红底 TabBar + 「登录后解锁功能」的占位，比较粗糙）。
class MyInfoPage extends StatelessWidget {
  const MyInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<LoginUserProvider>().userId;

    if (userId != null) {
      return CommunityUserPage(userId: userId, userSelf: true);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            tooltip: '设置',
            onPressed: () =>
                Navigator.of(context).pushNamed(PageRoutes.settingsPage),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const Text(
                '还没有登录',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              const Text(
                '登录后可以查看自己的上传、收藏和订阅',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textHint),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 180,
                child: FilledButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed(PageRoutes.loginPage),
                  child: const Text('去登录'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
