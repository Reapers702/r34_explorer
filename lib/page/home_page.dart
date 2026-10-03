import 'package:flutter/material.dart';
import 'package:r34_video/constant/filter_selection.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/common/app_filter_chip_bar.dart';
import 'package:r34_video/page/component/common/app_paged_grid_controller.dart';
import 'package:r34_video/page/component/common/app_search_bar.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/filter_bottom_sheet.dart';
import 'package:r34_video/page/component/video_thumb.dart';
import 'package:r34_video/repo/entity/r34_page.dart' show R34Page, R34Video;
import 'package:r34_video/repo/r34_home_page_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();

  FilterSelection filter = FilterSelection();

  late final AppPagedGridController _grid = AppPagedGridController(
    loader: (page) async {
      final result = await R34HomePageRepo.getPage(
        filter.duplicate(),
        page: page,
      );
      return VideoPageResult(result.videos, result.pageCount);
    },
  );

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
    _pageController.dispose();
    super.dispose();
  }

  void _onGridChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() async {
    await _grid.reset();
    if (mounted && _pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  Future<void> _onSortSelected(HomeSortEnum sort) async {
    if (filter.sortType == sort) {
      return;
    }
    setState(() => filter.sortType = sort);
    await _reload();
  }

  Future<void> _openFilter() async {
    final result = await showFilterBottomSheet(
      context: context,
      initial: filter,
      showSort: false,
    );
    if (result == null || !mounted) {
      return;
    }
    if (result.filterEquals(filter)) {
      _toast('筛选条件没有变化');
      return;
    }
    setState(() => filter = result);
    await _reload();
  }

  Future<void> _clearSecondaryFilter() async {
    setState(() {
      filter = filter.copyWith(
        duration: VideoDuration.all,
        dateAdded: VideoDateAdded.all,
        clearCustomDuration: true,
      );
    });
    await _reload();
  }

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
  Widget build(BuildContext context) {
    super.build(context);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            toolbarHeight: topPadding + 48,
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 0,
            title: Padding(
              padding: EdgeInsets.only(top: topPadding),
              child: AppToolbar(
                searchBar: AppSearchBar(
                  hintText: '来搜点什么吧',
                  readOnly: true,
                  onTap: () {
                    Navigator.of(context).pushNamed(PageRoutes.searchEditPage);
                  },
                ),
                actions: [
                  AppToolbarAction(
                    icon: Icons.filter_list_alt,
                    tooltip: '筛选',
                    badgeCount: filter.activeLabels.length,
                    onPressed: _openFilter,
                  ),
                  AppToolbarAction(
                    icon: Icons.last_page_rounded,
                    tooltip: '跳到指定页',
                    onPressed: _showPageSwitcher,
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ColoredBox(
              color: AppColors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppFilterChipBar(
                    selection: filter,
                    sortOptions: HomeSortEnum.descriptionMap,
                    onSortSelected: _onSortSelected,
                    onOpenFilter: _openFilter,
                    onClearSecondary: _clearSecondaryFilter,
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: _buildGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    if (_grid.loading && _grid.videosOf(1).isEmpty) {
      return const VideoGridView([]);
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _grid.pageCount,
      onPageChanged: (index) => _grid.onPageChanged(index + 1),
      itemBuilder: (context, index) {
        final page = index + 1;
        final videos = _grid.videosOf(page).cast<R34Video>();

        if (videos.isEmpty && _grid.loading) {
          return const VideoGridView([]);
        }

        if (videos.isEmpty) {
          return AppStateView.empty(
            title: '这一页没有内容',
            description: '换个筛选条件试试',
            actionLabel: '重新加载',
            onAction: () => _grid.loadPage(page),
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _reload,
          child: VideoGridView(videos),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
