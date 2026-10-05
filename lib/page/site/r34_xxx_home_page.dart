import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_paged_grid_controller.dart';
import 'package:r34_video/page/component/common/app_search_bar.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/page/component/common/tag_search_bar.dart';
import 'package:r34_video/page/site/r34_xxx_detail_page.dart';
import 'package:r34_video/page/site/r34_xxx_search_options.dart';
import 'package:r34_video/page/site/r34_xxx_sort_filter_dialog.dart';
import 'package:r34_video/repo/entity/r34_xxx_post.dart';
import 'package:r34_video/repo/r34_xxx_repo.dart';
import 'package:r34_video/repo/r34_xxx_search_history_repo.dart';
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
  /// 跟 video 站首页一致：左右滑动翻页 + 跳页，而不是无限滚动。
  final PageController _pageController = PageController();

  /// 当前已选 tag（原值，下划线形式，如 `ada_wong`）。
  List<String> _tags = const [];

  /// 排序 / 筛选条件（只进待提交区，点「搜索」才生效，见 [_onSearchSubmit]）。
  R34XxxSearchOptions _searchOptions = const R34XxxSearchOptions();

  /// 传给接口的 tag 串（不含排序/筛选伪标签，用于搜索历史）。
  String get _query => TagRules.rule34xxx.joinTags(_tags);

  /// 完整搜索串 = tags + 排序/筛选伪标签（真正发给接口的）。
  String get _fullQuery => _searchOptions.toTagQuery(_query);

  late final AppPagedGridController _grid = AppPagedGridController(
    loader: (page) async {
      final result = await R34XxxRepo.getPosts(
        tags: _fullQuery,
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

  /// 最近 tag 搜索历史（本地），搜索框聚焦时展示，点击可再次搜索。
  List<String> _searchHistory = const [];

  /// 搜索框是否聚焦：聚焦时展示「最近 tag」条。
  bool _searchFocused = false;

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
    _loadSearchHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _grid.loadPage(1);
      }
    });
  }

  Future<void> _loadSearchHistory() async {
    final history = await R34XxxSearchHistoryRepo.getHistory();
    if (mounted && history.isNotEmpty) {
      setState(() => _searchHistory = history);
    }
  }

  @override
  void dispose() {
    _grid.removeListener(_onGridChanged);
    _grid.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onGridChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// tag 条件变化（点联想 / 加号 / 回车 / 删除 / 清空）。
  ///
  /// 只更新「待提交区」（已选 chips），**永不**自动发起搜索——
  /// 搜索一律由用户点右侧「搜索」按钮发起（见 [_onSearchSubmit]）。
  Future<void> _onTagsChanged(String tags) async {
    final next = tags.trim().isEmpty
        ? const <String>[]
        : tags.trim().split(' ');
    if (listEquals(next, _tags)) {
      return;
    }
    setState(() => _tags = next);
  }

  /// 显式搜索（点「搜索」按钮）：按当前所有已选 tag + 排序/筛选条件请求，
  /// 并记一条搜索历史（历史只记 tag，不记排序/筛选）。
  Future<void> _onSearchSubmit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _recordCurrentSearch();
    await _grid.reset();
    if (mounted && _pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  /// 把当前 tag 组合记入「最近 tag」历史。
  void _recordCurrentSearch() {
    final query = _query;
    if (query.isEmpty) {
      return;
    }
    R34XxxSearchHistoryRepo.addSearchHistory(query).then((_) async {
      final history = await R34XxxSearchHistoryRepo.getHistory();
      if (mounted) {
        setState(() => _searchHistory = history);
      }
    });
  }

  /// 点击「最近 tag」里的某一项：把该组合放入「待提交区」，**不**自动搜索。
  ///
  /// 注意：**不能**一开始就 unfocus——失焦会让 `_searchFocused` 变 false、
  /// 历史条从树上移除，正在点的条目被卸载导致 onTap 中断、后面代码不执行。
  /// 所以先应用 tag，最后再收起历史条。
  Future<void> _applyTags(String tags) async {
    final next = tags.trim().isEmpty
        ? const <String>[]
        : tags.trim().split(' ');
    setState(() => _tags = next);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _removeHistory(String tags) async {
    await R34XxxSearchHistoryRepo.removeSearchHistory(tags);
    final history = await R34XxxSearchHistoryRepo.getHistory();
    if (mounted) {
      setState(() => _searchHistory = history);
    }
  }

  Future<void> _clearSearchHistory() async {
    await R34XxxSearchHistoryRepo.clearSearchHistory();
    if (mounted) {
      setState(() => _searchHistory = const []);
    }
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
                          child: Focus(
                            onFocusChange: (focused) {
                              if (mounted && focused != _searchFocused) {
                                setState(() => _searchFocused = focused);
                              }
                            },
                            child: TagSearchBar(
                              selectedTags: _tags,
                              rules: TagRules.rule34xxx,
                              searchTags: _autocomplete,
                              onChanged: _onTagsChanged,
                              onSearch: _onSearchSubmit,
                            ),
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
                  // 搜索框聚焦时才展示「最近 tag」，避免常驻占地方。
                  if (_searchFocused && _searchHistory.isNotEmpty)
                    _buildHistoryBar(),
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

  /// 打开「排序与筛选」对话框。
  ///
  /// 只更新待提交区的条件，**不**自动搜索（约定同 tag 编辑，
  /// 见 [_onSearchSubmit]）。
  Future<void> _openSortFilter() async {
    final next = await R34XxxSortFilterDialog.show(context, _searchOptions);
    if (next != null && mounted && next != _searchOptions) {
      setState(() => _searchOptions = next);
    }
  }

  /// 结果计数行：左侧是「排序/筛选」入口（显示当前条件），右侧报总数。
  Widget _buildQueryBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openSortFilter,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _searchOptions.describe(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 15,
                  color: AppColors.textHint,
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            _total >= 0 ? '$_total 条' : '—',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _showPageSwitcher,
            tooltip: '跳到指定页',
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.last_page_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// 「最近 tag」横滑条：点击把组合放入待提交区，单条可删，尾部可清空。
  Widget _buildHistoryBar() {
    return SizedBox(
      // 高度要给足，否则 chip 底部会被裁剪（之前 34 盖住一点）。
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          2,
          AppSpacing.page,
          0,
        ),
        children: [
          ..._searchHistory.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: AppChip.text(
                entry,
                onTap: () => _applyTags(entry),
                onDeleted: () => _removeHistory(entry),
              ),
            ),
          ),
          AppChip.text(
            '清空',
            fontSize: 12,
            leading: const Icon(
              Icons.clear_all_rounded,
              size: 14,
              color: AppColors.textHint,
            ),
            onTap: _clearSearchHistory,
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_grid.loading && _grid.videosOf(1).isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.page),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppSpacing.sm,
          mainAxisSpacing: AppSpacing.sm,
        ),
        itemCount: 12,
        itemBuilder: (context, index) => const _GridSkeleton(),
      );
    }

    // 跟 video 站首页一致：左右滑动按页切换，支持跳页。每页一个 3 列网格。
    return PageView.builder(
      controller: _pageController,
      itemCount: _grid.pageCount,
      onPageChanged: (index) => _grid.onPageChanged(index + 1),
      itemBuilder: (context, index) {
        final page = index + 1;
        final posts = _grid.videosOf(page).cast<R34XxxPost>();

        if (posts.isEmpty && _grid.loading) {
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.page),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: 12,
            itemBuilder: (context, i) => const _GridSkeleton(),
          );
        }

        if (posts.isEmpty) {
          return AppStateView.empty(
            title: '这一页没有内容',
            description: _fullQuery.isEmpty
                ? '接口可能限流了，稍后再试'
                : '换个 tag 试试，多个 tag 用空格分隔',
            actionLabel: '重新加载',
            onAction: () => _grid.loadPage(page),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _grid.reset(),
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.page),
            physics: const AlwaysScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: posts.length,
            itemBuilder: (context, i) => _XxxThumb(posts[i]),
          ),
        );
      },
    );
  }

  /// 跳到指定页（和 video 站首页一致）。
  Future<void> _showPageSwitcher() async {
    final controller = TextEditingController();
    final target = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('跳到指定页'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '1 - ${_grid.pageCount}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              if (page == null || page < 1 || page > _grid.pageCount) {
                _toast('请输入 1 - ${_grid.pageCount} 之间的页码');
                return;
              }
              Navigator.of(dialogContext).pop(page);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (target != null && mounted && _pageController.hasClients) {
      _pageController.jumpToPage(target - 1);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
    return ExcludeSemantics(
      child: GestureDetector(
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
              placeholder: (context, url) =>
                  const ColoredBox(color: AppColors.skeleton),
              errorWidget: (context, url, error) => const ColoredBox(
                color: AppColors.skeleton,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.textHint,
                  size: 20,
                ),
              ),
            ),
            if (post.isVideo)
              const Positioned.fill(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
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
      ),
    );
  }
}

/// 网格加载占位：静态色块。
///
/// 特意不用 [AppSkeleton]（呼吸动画）：网格里几十个骨架同时动画，
/// 每帧都在重建语义节点，会把 Windows 引擎的 accessibility 树刷崩
/// （就是日志里刷屏的 `Failed to update ui::AXTree`），也浪费性能。
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.skeleton,
        borderRadius: BorderRadius.circular(AppRadius.sm),
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
