import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/community_video_block.dart';
import 'package:r34_video/repo/entity/r34_community_user.dart';
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/repo/r34_community_repo.dart';
import 'package:r34_video/theme/app_colors.dart';

class CommunityUserPageArg {
  final int userId;
  final String? avatarUrl;
  CommunityUserPageArg({required this.userId, this.avatarUrl});
}

class CommunityUserPage extends StatefulWidget {
  final int? userId;
  final bool userSelf;

  const CommunityUserPage({super.key, this.userId, this.userSelf = false});

  @override
  State<CommunityUserPage> createState() => _CommunityUserPageState();
}

class _CommunityUserPageState extends State<CommunityUserPage>
    with SingleTickerProviderStateMixin {
  int? _userId;
  String? _avatarUrl;
  late TabController _tabController;
  Future<R34CommunityUser?>? _communityUserFuture;

  /// 一个云端子 Tab（浏览历史 / 喜欢的视频 / 上传的视频）。
  ///
  /// 「我的」【userSelf=true】三个都展示，顺序 浏览历史→喜欢的→上传；
  /// 「作者」【userSelf=false】只有 上传 / 喜欢 两个。
  late List<_UserTab> _tabs;

  int _getUid(BuildContext context) {
    if (_userId == null) {
      if (widget.userId != null) {
        _userId = widget.userId!;
        _avatarUrl = null;
      } else {
        final CommunityUserPageArg pageArg =
            ModalRoute.of(context)?.settings.arguments as CommunityUserPageArg;
        _userId = pageArg.userId;
        _avatarUrl = pageArg.avatarUrl;
      }
    }
    return _userId!;
  }

  List<_UserTab> _buildTabs() {
    final userId = _getUid(context);
    final upload = _UserTab(_UserTabKind.upload);
    final favorite = _UserTab(_UserTabKind.favorite);
    final history = _UserTab(_UserTabKind.history);
    upload.fetcher = () async {
      return R34CommunityRepo.getUserUploadVideo(userId, upload.length);
    };
    favorite.fetcher = () async {
      return R34CommunityRepo.getUserFavoriteVideo(userId, favorite.length);
    };
    history.fetcher = () async {
      return R34CommunityRepo.getUserWatchHistory();
    };
    return widget.userSelf
        ? [history, favorite, upload]
        : [upload, favorite];
  }

  void _loadMore(_UserTab tab) async {
    if (tab.isLoading) {
      return;
    }
    setState(() => tab.isLoading = true);
    try {
      final data = await tab.fetcher();
      if (data.isNotEmpty) {
        setState(() => tab.items.addAll(data));
      }
    } finally {
      if (mounted) {
        setState(() => tab.isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs();
    _tabController =
        TabController(length: _tabs.length, vsync: this);

    for (final tab in _tabs) {
      tab.controller.addListener(() {
        if (tab.controller.position.pixels ==
            tab.controller.position.maxScrollExtent) {
          _loadMore(tab);
        }
      });
    }

    Future.microtask(() {
      for (final tab in _tabs) {
        _loadMore(tab);
      }
    });
  }

  @override
  void dispose() {
    for (final tab in _tabs) {
      tab.controller.dispose();
    }
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _communityUserFuture ??=
        R34CommunityRepo.getCommunityUser(_getUid(context));

    return Scaffold(
      body: FutureBuilder<R34CommunityUser?>(
        future: _communityUserFuture,
        builder: (context, snapshot) {
          final communityUser = snapshot.data;
          return CustomScrollView(
            slivers: [
              // 固定高度的用户信息头部（无随滚缩放动画）。
              SliverPersistentHeader(
                pinned: true,
                delegate: _UserHeaderDelegate(
                  communityUser: communityUser,
                  userSelf: widget.userSelf,
                  avatarUrl: _avatarUrl,
                ),
              ),
              // 吸顶的 TabBar
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabController: _tabController,
                  communityUser: communityUser,
                  tabs: _tabs,
                ),
              ),
              // TabBarView
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [for (final tab in _tabs) _buildList(tab)],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(_UserTab tab) {
    return ListView.separated(
      controller: tab.controller,
      itemCount: tab.items.length + (tab.isLoading ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(indent: 10),
      itemBuilder: (context, index) {
        if (index < tab.items.length) {
          return CommunityVideoBlock(video: tab.items[index]);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

/// “我的”页当前的用户信息头部。
///
/// 不再做随滚动缩放/移位的动画：桌面端观感差且状态栏适配麻烦。
/// 高度固定（pinned 吸顶但不变形），头像直接用入站 [avatarUrl]，
/// 无需等用户详情接口返回就能先展示。
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final R34CommunityUser? communityUser;
  final List<_UserTab> tabs;

  _TabBarDelegate({
    required this.tabController,
    required this.communityUser,
    required this.tabs,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 40,
      color: AppColors.surface,
      child: TabBar(
        controller: tabController,
        tabs: [
          for (final tab in tabs)
            Tab(text: tab.label(communityUser)),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 40;

  @override
  double get minExtent => 40;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

// 固定的用户信息头部。
//
// 不再做随滚动缩放/移位的动画：桌面端观感差且状态栏适配麻烦。
// 高度固定（pinned 吸顶但不变形），头像直接用入站 [avatarUrl]，
// 无需等用户详情接口返回就能先展示。
class _UserHeaderDelegate extends SliverPersistentHeaderDelegate {
  final R34CommunityUser? _communityUser;
  final bool _userSelf;
  final String? _avatarUrl;

  _UserHeaderDelegate({
    required R34CommunityUser? communityUser,
    required bool userSelf,
    required String? avatarUrl,
  })  : _communityUser = communityUser,
        _userSelf = userSelf,
        _avatarUrl = avatarUrl;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final topPadding = MediaQuery.of(context).padding.top;
    final avatarUrl = _avatarUrl ?? _communityUser?.avatarUrl;
    final nickname =
        _communityUser?.nickName ?? (_userSelf ? '我的昵称' : '作者');

    return Container(
      height: maxExtent,
      padding: EdgeInsets.only(top: topPadding),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF23202E), Color(0xFF3A2C44)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 桌面端没有系统返回键，这里给个显式返回入口。
          if (Navigator.of(context).canPop())
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 20,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          const SizedBox(width: 4),
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: avatarUrl == null
                  ? Image.asset(
                      'assets/images/theporndude.png',
                      fit: BoxFit.cover,
                    )
                  : CachedNetworkImage(
                      imageUrl: avatarUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: Colors.white38,
                      ),
                      errorWidget: (context, url, error) => Image.asset(
                        'assets/images/theporndude.png',
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nickname,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '粉丝 ${_communityUser?.subscriberCount ?? "-"}',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (_userSelf)
            IconButton(
              icon: const Icon(
                Icons.more_horiz_outlined,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context)
                  .pushNamed(PageRoutes.settingsPage),
            ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  // 固定高度：max == min，因此滚动时不变形、头像不移动。
  @override
  double get maxExtent => 128;
  @override
  double get minExtent => 128;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

/// 云端子 Tab 的类型，决定标题计数显示的来源。
enum _UserTabKind { history, favorite, upload }

/// “我的”页用户信息头部下方的云端 Tab。
class _UserTab {
  final List<R34CommunityVideo> items = [];
  final ScrollController controller = ScrollController();
  bool isLoading = false;

  /// 分页取数：`this.length` 作为偏移。
  late Future<List<R34CommunityVideo>> Function() fetcher;

  final _UserTabKind kind;

  _UserTab(this.kind);

  String label(R34CommunityUser? user) {
    switch (kind) {
      case _UserTabKind.history:
        return '浏览历史';
      case _UserTabKind.favorite:
        return '喜欢的视频 (${user?.favoriteVideoCount ?? "-"})';
      case _UserTabKind.upload:
        return '上传的视频 (${user?.uploadVideoCount ?? "-"})';
    }
  }

  /// 取数偏移：已经加载了多少条，作为下一屏起点。
  int get length => items.length;
}
