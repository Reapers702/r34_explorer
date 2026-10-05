import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/page/site/r34_xxx_detail_page.dart';
import 'package:r34_video/repo/local_content_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// 本地收藏 / 浏览历史 页。
///
/// 两个站（rule34.xxx 图片站 + rule34video 视频站）的内容统一成一个网格，
/// 类型只决定点击后跳到哪套详情页。数据只存本机，不依赖登录。
///
/// 提供站点过滤：不限 / 只看 rule34.xxx / 只看 rule34video，对「收藏」和
/// 「浏览历史」两个子 Tab 同时生效。
class LocalLibraryPage extends StatefulWidget {
  const LocalLibraryPage({super.key});

  @override
  State<LocalLibraryPage> createState() => _LocalLibraryPageState();
}

enum _SiteFilter { all, xxx, video }

class _LocalLibraryPageState extends State<LocalLibraryPage> {
  bool _favTab = true;
  _SiteFilter _filter = _SiteFilter.all;

  void _reload() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTabChanged(int index) {
    if (mounted) {
      setState(() => _favTab = index == 0);
    }
  }

  /// 按站点过滤后的列表。
  List<SavedContent> _filterBySite(List<SavedContent> items) {
    switch (_filter) {
      case _SiteFilter.all:
        return items;
      case _SiteFilter.xxx:
        return items.where((e) => e.type == SavedType.xxx).toList();
      case _SiteFilter.video:
        return items.where((e) => e.type == SavedType.video).toList();
    }
  }

  Future<void> _confirmClear(List<SavedContent> items) async {
    if (items.isEmpty) {
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_favTab ? '清空收藏' : '清空历史'),
        content: Text(
          _favTab ? '确定清空全部 ${items.length} 条收藏？' : '确定清空全部浏览历史？',
        ),
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
    if (_favTab) {
      await LocalContentRepo.clearFavorites();
    } else {
      await LocalContentRepo.clearHistory();
    }
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('收藏'),
          actions: [
            FutureBuilder<List<SavedContent>>(
              future: _favTab
                  ? LocalContentRepo.favorites()
                  : LocalContentRepo.history(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <SavedContent>[];
                return IconButton(
                  tooltip: _favTab ? '清空收藏' : '清空历史',
                  onPressed:
                      items.isEmpty ? null : () => _confirmClear(items),
                  icon: const Icon(Icons.delete_sweep_outlined),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            _buildFilterBar(),
            TabBar(
              onTap: _onTabChanged,
              tabs: const [Tab(text: '收藏'), Tab(text: '浏览历史')],
            ),
            Expanded(
              child: TabBarView(
                children: [_buildGrid(true), _buildGrid(false)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 站点过滤条：不限 / rule34.xxx / rule34video。
  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        0,
      ),
      child: SegmentedButton<_SiteFilter>(
        segments: const [
          ButtonSegment(value: _SiteFilter.all, label: Text('不限')),
          ButtonSegment(value: _SiteFilter.xxx, label: Text('rule34.xxx')),
          ButtonSegment(value: _SiteFilter.video, label: Text('rule34video')),
        ],
        selected: {_filter},
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
        ),
        onSelectionChanged: (selection) {
          if (mounted) {
            setState(() => _filter = selection.first);
          }
        },
      ),
    );
  }

  Widget _buildGrid(bool favorite) {
    return FutureBuilder<List<SavedContent>>(
      future: favorite
          ? LocalContentRepo.favorites()
          : LocalContentRepo.history(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var items = _filterBySite(snapshot.data ?? const <SavedContent>[]);
        if (items.isEmpty) {
          final filtered = _filter != _SiteFilter.all;
          return AppStateView.empty(
            title: favorite ? '还没有收藏' : '还没有浏览记录',
            description: filtered
                ? (favorite ? '该站点暂无收藏' : '该站点暂无浏览记录')
                : (favorite
                    ? '在图片或视频详情页点收藏就能在这里看到'
                    : '浏览过的图片、视频会出现在这里'),
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
                if (favorite) {
                  await LocalContentRepo.removeFavorite(item.keyId);
                } else {
                  await LocalContentRepo.removeHistory(item.keyId);
                }
                _reload();
              },
            );
          },
        );
      },
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