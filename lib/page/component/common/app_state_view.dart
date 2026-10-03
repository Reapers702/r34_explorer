import 'package:flutter/material.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 空的占位状态：无数据 / 无网络 / 出错，统一成同一个视觉。
///
/// 早期页面里这三种情况各写各的（有的直接 `Text('Data Still Loading')`），
/// 现在统一收口，顺便都带上重试入口。
class AppStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  const AppStateView.empty({
    super.key,
    this.title = '这里什么都没有',
    this.description,
    this.actionLabel,
    this.onAction,
  }) : icon = Icons.inbox_outlined;

  const AppStateView.error({
    super.key,
    this.title = '出了点问题',
    this.description,
    this.actionLabel = '重试',
    this.onAction,
  }) : icon = Icons.cloud_off_outlined;

  const AppStateView.noNetwork({
    super.key,
    this.title = '网络好像不太行',
    this.description,
    this.actionLabel = '重试',
    this.onAction,
  }) : icon = Icons.wifi_off_rounded;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textHint),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textHint,
                  height: 1.5,
                ),
              ),
            ],
            if (onAction != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel ?? '重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 骨架屏方块，带一个很轻的呼吸动画。
class AppSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double radius;

  const AppSkeleton({
    super.key,
    this.width,
    this.height,
    this.radius = AppRadius.sm,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              AppColors.skeleton,
              AppColors.divider,
              _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// 分页列表底部的状态行：加载中 / 到底了 / 加载失败。
class AppListFooter extends StatelessWidget {
  final bool loading;
  final bool hasMore;
  final VoidCallback? onRetry;

  const AppListFooter({
    super.key,
    this.loading = false,
    this.hasMore = true,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text(
            '没有更多了',
            style: TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ),
      );
    }
    if (onRetry != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: TextButton(
            onPressed: onRetry,
            child: const Text('加载失败，点击重试'),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}
