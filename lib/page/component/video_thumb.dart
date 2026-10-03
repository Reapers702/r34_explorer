import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 网格里的视频卡：封面 + 时长角标 + 标题。
///
/// 之前高度是按 `屏幕宽 * 0.47` 反推出来的（还依赖 MediaQuery），
/// 现在整卡只吃父级给的尺寸，放进 `AspectRatio` 就能自适应各种列数。
class VideoThumb extends StatelessWidget {
  final R34Video? r34video;

  static const double _titleFontSize = 12.5;

  const VideoThumb({super.key, this.r34video});

  /// 骨架占位。
  const VideoThumb.loading({super.key}) : r34video = null;

  @override
  Widget build(BuildContext context) {
    if (r34video == null) {
      return const _VideoThumbSkeleton();
    }
    final video = r34video!;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.detailPage,
          arguments: DetailPageArgs(video),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const AppSkeleton(
                      radius: 0,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.skeleton,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textHint,
                        size: 22,
                      ),
                    ),
                  ),
                  if (video.videoDuration.isNotEmpty)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.badgeBackground,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          video.videoDuration,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          SizedBox(
            height: _titleFontSize * 2 * 1.35,
            child: Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: _titleFontSize,
                height: 1.35,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoThumbSkeleton extends StatelessWidget {
  const _VideoThumbSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: AppSkeleton(radius: AppRadius.sm),
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppSkeleton(height: 10),
        const SizedBox(height: AppSpacing.xs),
        FractionallySizedBox(
          widthFactor: 0.6,
          child: const AppSkeleton(height: 10),
        ),
      ],
    );
  }
}

/// 两列网格。
///
/// 首页/搜索结果页共用。`padding` 用固定值而不是 `屏幕宽 * 0.02`，
/// 边缘留白在各分辨率下才一致。
class VideoGridView extends StatelessWidget {
  final List<R34Video> videos;

  /// 首屏/加载中时展示的骨架数量。
  final int skeletonCount;

  const VideoGridView(
    this.videos, {
    super.key,
    this.skeletonCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isSkeleton = videos.isEmpty;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount:
          (isSkeleton ? skeletonCount : videos.length / 2).ceil(),
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (isSkeleton) {
          return const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: VideoThumb.loading()),
              SizedBox(width: AppSpacing.md),
              Expanded(child: VideoThumb.loading()),
            ],
          );
        }

        final left = videos[index * 2];
        final right = index * 2 + 1 < videos.length ? videos[index * 2 + 1] : null;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: VideoThumb(r34video: left)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : VideoThumb(r34video: right),
            ),
          ],
        );
      },
    );
  }
}
