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
  CommunityUserPageArg({required this.userId});
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
      } else {
        final CommunityUserPageArg pageArg =
            ModalRoute.of(context)?.settings.arguments as CommunityUserPageArg;
        _userId = pageArg.userId;
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
              // 可浮动且吸顶的 Container
              SliverPersistentHeader(
                pinned: true,
                delegate:
                    _FloatingContainerDelegate(communityUser, widget.userSelf),
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

// 可浮动且吸顶的 Container 的代理类
class _FloatingContainerDelegate extends SliverPersistentHeaderDelegate {
  final R34CommunityUser? _communityUser;
  final bool _userSelf;

  _FloatingContainerDelegate(this._communityUser, this._userSelf);

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final screenTopPadding = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    final double maxAvatarSize = (maxExtent - screenTopPadding) * 0.5;
    final Offset maxAvatarOffset =
        Offset(screenWidth * 0.1, maxExtent * 0.4 - maxAvatarSize * 0.5);

    final double minAvatarSize = (minExtent - screenTopPadding) * 0.8;
    final Offset minAvatarOffset =
        Offset(screenWidth * 0.3, (minExtent - screenTopPadding) * 0.1);

    final double maxNickSize = 20;
    final Offset maxNickOffset = Offset(screenWidth * 0.5, maxExtent * 0.2);
    final double minNickSize = 20;
    final Offset minNickOffset = Offset(
      minAvatarOffset.dx + minAvatarSize + screenWidth * 0.05,
      (minExtent - screenTopPadding) * 0.2,
    );

    shrinkOffset = shrinkOffset.clamp(0.0, maxExtent - minExtent);
    final double visiblePercentage =
        (maxExtent - minExtent - shrinkOffset) / (maxExtent - minExtent);
    final double currentHeight =
        minExtent + (maxExtent - minExtent) * visiblePercentage;
    // dev.log('shrinkOffset: $shrinkOffset');
    // dev.log(
    //     'current precent: $visiblePercentage, currentHeight: $currentHeight');

    final avatarLeft = minAvatarOffset.dx +
        visiblePercentage * (maxAvatarOffset.dx - minAvatarOffset.dx);
    final avatarTop = minAvatarOffset.dy +
        visiblePercentage * (maxAvatarOffset.dy - minAvatarOffset.dy);
    final avatarSize =
        minAvatarSize + visiblePercentage * (maxAvatarSize - minAvatarSize);

    final nickLeft = minNickOffset.dx +
        visiblePercentage * (maxNickOffset.dx - minNickOffset.dx);
    final nickTop = minNickOffset.dy +
        visiblePercentage * (maxNickOffset.dy - minNickOffset.dy);
    final nickSize =
        minNickSize + visiblePercentage * (maxNickSize - minNickSize);

    return SizedBox(
      height: currentHeight,
      child: Column(
        children: [
          Container(
            height: screenTopPadding,
            color: AppColors.primaryDark,
          ),
          Container(
            height: currentHeight - screenTopPadding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                ],
              ),
            ),
            child: Stack(
              children: [
                // 桌面端没有系统返回键，这里给个显式返回入口。
                if (Navigator.of(context).canPop())
                  Positioned(
                    left: 4,
                    top: 0,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ...(_userSelf
                    ? [
                        Positioned(
                          right: 10,
                          top: 0,
                          child: IconButton(
                            onPressed: () async {
                              Navigator.of(context)
                                  .pushNamed(PageRoutes.settingsPage);
                            },
                            icon: const Icon(
                              Icons.more_horiz_outlined,
                              color: Colors.white,
                            ),
                          ),
                        )
                      ]
                    : []),
                Positioned(
                  left: avatarLeft,
                  top: avatarTop,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(avatarSize),
                    child: _communityUser != null
                        ? CachedNetworkImage(
                            imageUrl: _communityUser.avatarUrl,
                            width: avatarSize,
                            height: avatarSize,
                            fit: BoxFit.fill,
                          )
                        : Image.asset(
                            'assets/images/theporndude.png',
                            width: avatarSize,
                            height: avatarSize,
                            fit: BoxFit.fill,
                          ),
                  ),
                ),
                Positioned(
                  left: nickLeft,
                  top: nickTop,
                  child: Text(
                    _communityUser?.nickName ?? '我的昵称',
                    style: TextStyle(
                      fontSize: nickSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Positioned(
                  left: maxNickOffset.dx,
                  top: maxNickOffset.dy + maxNickSize + 10,
                  child: Column(
                    children: [
                      Text(
                        '粉丝 ${_communityUser?.subscriberCount ?? "-"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 180;
  @override
  double get minExtent => 80;

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
