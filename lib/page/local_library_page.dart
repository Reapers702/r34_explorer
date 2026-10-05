import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/page/site/r34_xxx_detail_page.dart';
import 'package:r34_video/repo/local_content_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 本地收藏页。
///
/// 两个站（rule34.xxx 图片站 + rule34video 视频站）的内容统一成一个网格，
/// 类型只决定点击后跳到哪套详情页。数据只存本机，不依赖登录。
///
/// 注意：这里**只有本地收藏**，不包含浏览历史 —— 浏览历史已改走云端，
/// 在「我的」页里以「浏览历史」子 Tab 展示（仅 rule34video 站）。
class LocalLibraryPage extends StatefulWidget {
  const LocalLibraryPage({super.key});

  @override
  State<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

class _LocalLibraryPageState extends State<LocalLibraryPage> {
  void _reload() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmClear(List<SavedContent> items) async {
    if (items.isEmpty) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空收藏'),
        content: Text('确定清空全部 ${items.length} 条收藏？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await LocalContentRepo.clearFavorites();
    _reload();
  }

  void _open(SavedContent item) {
    if (item.type == SavedType.xxx) {
      final post = item.toPost();
      if (post == null) {
        return;
      }
      Navigator.of(context).pushNamed(
        PageRoutes.r34XxxDetailPage,
        arguments: R34XxxDetailPageArgs(post),
      );
    } else {
      final video = item.toVideo();
      if (video == null) {
        return;
      }
      Navigator.of(context).pushNamed(
        PageRoutes.detailPage,
        arguments: DetailPageArgs(video),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('收藏'),
        actions: [
          FutureBuilder<List<SavedContent>>(
            future: LocalContentRepo.favorites(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <SavedContent>[];
              return IconButton(
                tooltip: '清空收藏',
                onPressed:
                    items.isEmpty ? null : () => _confirmClear(items),
                icon: const Icon(Icons.delete_sweep_outlined),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<SavedContent>>(
        future: LocalContentRepo.favorites(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data ?? const <SavedContent>[];
          if (items.isEmpty) {
            return AppStateView.empty(
              title: '还没有收藏',
              description: '在图片或视频详情页点收藏就能在这里看到',
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.page),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              childAspectRatio: 3 / 4,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _LibraryCell(
                item: item,
                onTap: () => _open(item),
                onLongPress: () async {
                  await LocalContentRepo.removeFavorite(item.keyId);
                  _reload();
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// 收藏网格里的一格。
///
/// 长按可单独删除；不额外放删除按钮，保持网格干净。
class _LibraryCell extends StatelessWidget {
  final SavedContent item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _LibraryCell({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.thumbUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const AppSkeleton(radius: 0),
                    errorWidget: (context, url, error) => const ColoredBox(
                      color: AppColors.skeleton,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                    ),
                  ),
                  if (item.type == SavedType.xxx)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child: Icon(
                        Icons.photo_outlined,
                        size: 12,
                        color: Colors.white70,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}