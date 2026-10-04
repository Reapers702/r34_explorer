import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_paged_grid_controller.dart';
import 'package:r34_video/page/component/common/app_search_bar.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/common/tag_search_bar.dart';
import 'package:r34_video/page/site/r34_xxx_detail_page.dart';
import 'package:r34_video/repo/entity/r34_xxx_post.dart';
import 'package:r34_video/repo/r34_xxx_repo.dart';
import 'package:r34_video/repo/site_registry.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

/// rule34.xxx 首页：标签搜索 + 瀑布式网格。
///
/// 这个站点是**图片站**（Booru），和 rule34video 的视频流是两套模型，
/// 所以这里单独一套页面，只在主题与通用组件（搜索框/状态视图/分页控制器）上复用。
class R34XxxHomePage extends StatefulWidget {
  const R34XxxHomePage({super.key});

  @override
  State<R34XxxHomePage> createState() => _R34XxxHomePageState();
}

class _R34XxxHomePageState extends State<R34XxxHomePage>
    with AutomaticKeepAliveClientMixin {
  /// 当前已选 tag（原值，下划线形式，如 `ada_wong`）。
  List<String> _tags = const [];

  /// 传给接口的 tag 串。
  String get _query => TagRules.rule34xxx.joinTags(_tags);

  late final AppPagedGridController _grid = AppPagedGridController(
    loader: (page) async {
      final result = await R34XxxRepo.getPosts(
        tags: _query,
        page: page - 1, // 接口的 pid 从 0 开始
        limit: R34XxxRepo.defaultLimit,
      );
      if (page == 1) {
        _total = result.total;
      }
      return VideoPageResult(result.posts, _pageCountOf(result));
    },
  );

  int _total = -1;

  int _pageCountOf(R34XxxPage result) {
    if (result.posts.isEmpty) {
      return 1;
    }
    if (result.hasTotal) {
      final pages = result.totalPages(R34XxxRepo.defaultLimit);
      return pages <= 0 ? 1 : pages;
    }
    // 拿不到总数时按「可能还有」处理，滚到底会继续试下一页。
    return _grid.currentPage + 1;
  }

  @override
  void initState() {
    super.initState();
    _grid.addListener(_onGridChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _grid.loadPage(1);
      }
    });
  }

  @override
  void dispose() {
    _grid.removeListener(_onGridChanged);
    _grid.dispose();
    super.dispose();
  }

  void _onGridChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// tag 条件变化（增 / 删 / 清空）：回到第一页重新拉。
  Future<void> _onTagsChanged(String tags) async {
    final next = tags.trim().isEmpty
        ? const <String>[]
        : tags.trim().split(' ');
    if (listEquals(next, _tags)) {
      return;
    }
    setState(() => _tags = next);
    await _grid.reset();
  }

  /// 联想：走官方 `autocomplete.php`（无需鉴权）。
  Future<List<TagSuggestion>> _autocomplete(String query) async {
    final list = await R34XxxRepo.autocomplete(query);
    return list
        .map((e) => TagSuggestion(
              value: e.value,
              label: e.value,
              count: _countOf(e.label),
            ))
        .toList();
  }

  /// 官方返回的 label 形如 `ada_wong (23076)`，取出括号里的使用量。
  String? _countOf(String label) {
    final match = RegExp(r'\(([\d,]+)\)\s*$').firstMatch(label);
    return match?.group(1)?.replaceAll(',', '');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          ColoredBox(
            color: AppColors.surface,
            child: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TagSearchBar(
                            selectedTags: _tags,
                            rules: TagRules.rule34xxx,
                            searchTags: _autocomplete,
                            onChanged: _onTagsChanged,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        AppToolbarAction(
                          icon: Icons.swap_horiz_rounded,
                          tooltip:
                              '切换站点（当前 ${SiteRegistry.instance.current.displayName}）',
                          onPressed: () => showSiteSwitcher(context),
                        ),
                      ],
                    ),
                  ),
                  _buildQueryBar(),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildGrid()),
        ],
      ),
    );
  }

  /// 结果计数行。
  ///
  /// 当前 tag 条件已经由 [TagSearchBar] 的 chip 列表呈现，这里不再重复，
  /// 只报总数。
  Widget _buildQueryBar() {
    final isEmpty = _query.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            isEmpty ? '最新投稿' : '筛选结果',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            _total >= 0 ? '$_total 条' : '—',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final posts = _grid.videosOf(_grid.currentPage).cast<R34XxxPost>();

    if (posts.isEmpty && _grid.loading) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.page),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: 12,
        itemBuilder: (context, index) => const AppSkeleton(),
      );
    }

    if (posts.isEmpty) {
      return AppStateView.empty(
        title: '这里没有内容',
        description: _query.isEmpty
            ? '接口可能限流了，稍后再试'
            : '换个 tag 试试，多个 tag 用空格分隔',
        actionLabel: '重新加载',
        onAction: () => _grid.loadPage(_grid.currentPage),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _grid.reset(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 800 &&
              !_grid.loading &&
              _grid.currentPage < _grid.pageCount) {
            _grid.loadPage(_grid.currentPage + 1);
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.page),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: posts.length + (_grid.loading ? 3 : 0),
          itemBuilder: (context, index) {
            if (index >= posts.length) {
              return const AppSkeleton();
            }
            return _XxxThumb(posts[index]);
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// 单张缩略图。图片站宽高比差异大，这里用固定方格 + cover，保证网格整齐。
class _XxxThumb extends StatelessWidget {
  final R34XxxPost post;

  const _XxxThumb(this.post);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.r34XxxDetailPage,
          arguments: R34XxxDetailPageArgs(post),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: post.previewUrl,
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
            if (post.rating == 'explicit')
              const Positioned(
                left: 4,
                top: 4,
                child: _RatingDot(color: AppColors.error),
              )
            else if (post.rating == 'questionable')
              const Positioned(
                left: 4,
                top: 4,
                child: _RatingDot(color: AppColors.warning),
              ),
          ],
        ),
      ),
    );
  }
}

class _RatingDot extends StatelessWidget {
  final Color color;

  const _RatingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
