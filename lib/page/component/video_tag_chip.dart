import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/page/search_result_page.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 统一跳转到搜索结果页。
///
/// 前缀约定：`t:` tag、`c:` category、`a:` artist，不带前缀就是关键词。
void _openSearchResult(BuildContext context, String rawText) {
  Navigator.of(context).pushNamed(
    PageRoutes.searchResultPage,
    arguments: SearchResultPageArgs(rawText),
  );
}

Widget _avatar(String url, double size) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(size / 4),
    child: CachedNetworkImage(
      imageUrl: url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => Container(
        width: size,
        height: size,
        color: AppColors.skeleton,
      ),
    ),
  );
}

/// 搜索历史标签。
class VideoSearchHistoryChip extends StatelessWidget {
  final String val;
  final double fontSize;
  final void Function()? onDelete;

  const VideoSearchHistoryChip(
    this.val, {
    super.key,
    this.onDelete,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return AppChip.text(
      val,
      fontSize: fontSize,
      onTap: () => _openSearchResult(context, val),
      onDeleted: onDelete,
    );
  }
}

class VideoTagChip extends StatelessWidget {
  final VideoTag tag;
  final double fontSize;

  const VideoTagChip(this.tag, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return AppChip.text(
      tag.name,
      fontSize: fontSize,
      onTap: () => _openSearchResult(context, 't:${tag.id}'),
    );
  }
}

class VideoCategoryChip extends StatelessWidget {
  final VideoCategory category;
  final double fontSize;
  final bool showAvatar;

  const VideoCategoryChip(
    this.category, {
    super.key,
    this.fontSize = 13,
    this.showAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppChip.text(
      category.desc,
      fontSize: fontSize,
      leading: showAvatar ? _avatar(category.imgUrl, fontSize + 3) : null,
      onTap: () => _openSearchResult(context, 'c:${category.name}'),
    );
  }
}

class VideoArtistChip extends StatelessWidget {
  final VideoArtistInfo artist;
  final double fontSize;
  final bool showAvatar;

  const VideoArtistChip(
    this.artist, {
    super.key,
    this.fontSize = 13,
    this.showAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppChip.text(
      artist.desc,
      fontSize: fontSize,
      leading: showAvatar ? _avatar(artist.avatarUrl, fontSize + 3) : null,
      onTap: () => _openSearchResult(context, 'a:${artist.name}'),
    );
  }
}

/// 详情页里「艺术家 / 分类 / Tag」这种「左边标题 + 右边一堆标签」的行。
class VideoChipRow extends StatelessWidget {
  final String label;
  final List<Widget> children;
  final double labelWidth;

  const VideoChipRow({
    super.key,
    required this.label,
    required this.children,
    this.labelWidth = 56,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textHint,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// 详情页视频信息里的一行元数据（图标 + 文本）。
class VideoMetaItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const VideoMetaItem({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
