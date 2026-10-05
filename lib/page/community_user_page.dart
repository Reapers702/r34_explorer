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

  bool _favoriteIsLoading = false;
  bool _uploadIsLoading = false;

  final List<R34CommunityVideo> _favoriteVideoList = [];
  final List<R34CommunityVideo> _uploadVideoList = [];

  final _favoriteScrollController = ScrollController();
  final _uploadScrollController = ScrollController();

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

  Future<void> _loadData({int? index}) async {
    final pageViewIndex = index ?? _tabController.index;
    if (pageViewIndex == 0) {
      setState(() {
        _uploadIsLoading = true;
      });
      try {
        List<R34CommunityVideo> data =
            await R34CommunityRepo.getUserUploadVideo(
                _getUid(context), _uploadVideoList.length);
        if (data.isNotEmpty) {
          _uploadVideoList.addAll(data);
        }
      } finally {
        setState(() {
          _uploadIsLoading = false;
        });
      }
    } else {
      setState(() {
        _favoriteIsLoading = true;
      });
      try {
        List<R34CommunityVideo> data =
            await R34CommunityRepo.getUserFavoriteVideo(
                _getUid(context), _favoriteVideoList.length);
        if (data.isNotEmpty) {
          _favoriteVideoList.addAll(data);
        }
      } finally {
        setState(() {
          _favoriteIsLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _favoriteScrollController.addListener(() {
      if (_favoriteScrollController.position.pixels ==
              _favoriteScrollController.position.maxScrollExtent &&
          !_favoriteIsLoading) {
        _loadData(index: 1);
      }
    });

    _uploadScrollController.addListener(() {
      if (_uploadScrollController.position.pixels ==
              _uploadScrollController.position.maxScrollExtent &&
          !_uploadIsLoading) {
        _loadData(index: 0);
      }
    });

    Future.microtask(() {
      _loadData(index: 0);
      _loadData(index: 1);
    });
  }

  @override
  void dispose() {
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
                ),
              ),
              // TabBarView
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ListView.separated(
                      controller: _uploadScrollController,
                      itemCount:
                          _uploadVideoList.length + (_uploadIsLoading ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const Divider(indent: 10),
                      itemBuilder: (context, index) {
                        if (index < _uploadVideoList.length) {
                          final video = _uploadVideoList[index];
                          return CommunityVideoBlock(video: video);
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      },
                    ),
                    ListView.separated(
                      controller: _favoriteScrollController,
                      itemCount: _favoriteVideoList.length +
                          (_favoriteIsLoading ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const Divider(indent: 10),
                      itemBuilder: (context, index) {
                        if (index < _favoriteVideoList.length) {
                          final video = _favoriteVideoList[index];
                          return CommunityVideoBlock(video: video);
                        } else {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
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

// TabBar 的代理类
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final R34CommunityUser? communityUser;

  _TabBarDelegate({required this.tabController, this.communityUser});

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 40,
      color: AppColors.surface,
      child: TabBar(
        controller: tabController,
        tabs: [
          Tab(text: '上传的视频 (${communityUser?.uploadVideoCount ?? "-"})'),
          Tab(text: '喜欢的视频 (${communityUser?.favoriteVideoCount ?? "-"})'),
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
