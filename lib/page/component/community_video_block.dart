import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/video_tag_chip.dart' show VideoMetaItem;
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 横排视频卡：左封面 + 右信息，社区页和详情页「相关视频」共用。
class CommunityVideoBlock extends StatelessWidget {
  final R34CommunityVideo video;

  /// 封面宽度，窄屏或列表里可以调小。
  final double thumbWidth;

  const CommunityVideoBlock({
    super.key,
    required this.video,
    this.thumbWidth = AppSizes.communityThumbWidth,
  });

  @override
  Widget build(BuildContext context) {
    final thumbHeight = thumbWidth * 9 / 16;

    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.detailPage,
          arguments: DetailPageArgs(
            R34Video(
              title: video.title,
              detailUrl: video.detailUrl,
              videoPreviewUrl: R34Const.websiteIcon,
              thumbImageUrl: video.thumbImageUrl,
              videoDuration: video.duration,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbImageUrl,
                    width: thumbWidth,
                    height: thumbHeight,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => AppSkeleton(
                      width: thumbWidth,
                      height: thumbHeight,
                      radius: 0,
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: thumbWidth,
                      height: thumbHeight,
                      color: AppColors.skeleton,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                    ),
                  ),
                  if (video.duration.isNotEmpty)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.badgeBackground,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          video.duration,
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
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (video.uploadTime.isNotEmpty)
                        VideoMetaItem(
                          icon: Icons.schedule_rounded,
                          text: video.uploadTime,
                        ),
                      if (video.viewCount.isNotEmpty)
                        VideoMetaItem(
                          icon: Icons.visibility_outlined,
                          text: video.viewCount,
                        ),
                      if (video.rating.isNotEmpty)
                        VideoMetaItem(
                          icon: Icons.thumb_up_outlined,
                          text: video.ratingCount.isEmpty
                              ? video.rating
                              : '${video.rating} (${video.ratingCount})',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
