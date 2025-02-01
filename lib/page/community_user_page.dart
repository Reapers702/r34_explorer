import 'dart:convert';
import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/repo/entity/r34_community_user.dart';
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/repo/r34_community_repo.dart';

class CommunityUserPage extends StatefulWidget {
  final int userId;

  const CommunityUserPage({super.key, required this.userId});

  @override
  State<CommunityUserPage> createState() => _CommunityUserPageState();
}

class _CommunityUserPageState extends State<CommunityUserPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _favoriteIsLoading = false;
  bool _uploadIsLoading = false;

  final List<R34CommunityVideo> _favoriteVideoList = [];
  final List<R34CommunityVideo> _uploadVideoList = [];

  final _favoriteScrollController = ScrollController();
  final _uploadScrollController = ScrollController();

  Future<void> _loadData({int? index}) async {
    final pageViewIndex = index ?? _tabController.index;
    if (pageViewIndex == 0) {
      setState(() {
        _uploadIsLoading = true;
      });
      List<R34CommunityVideo> data = await R34CommunityRepo.getUserUploadVideo(
          widget.userId, _uploadVideoList.length);
      if (data.isNotEmpty) {
        setState(() {
          _uploadVideoList.addAll(data);
          _uploadIsLoading = false;
        });
      }
    } else {
      setState(() {
        _favoriteIsLoading = true;
      });
      List<R34CommunityVideo> data =
          await R34CommunityRepo.getUserFavoriteVideo(
              widget.userId, _favoriteVideoList.length);
      if (data.isNotEmpty) {
        setState(() {
          _favoriteVideoList.addAll(data);
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
      dev.log(
          'current ${_favoriteScrollController.position.pixels}, max: ${_favoriteScrollController.position.maxScrollExtent}');
      if (_favoriteScrollController.position.pixels ==
              _favoriteScrollController.position.maxScrollExtent &&
          !_favoriteIsLoading) {
        _favoriteIsLoading = true;
        _loadData();
      }
    });

    _uploadScrollController.addListener(() {
      dev.log(
          'current ${_uploadScrollController.position.pixels}, max: ${_uploadScrollController.position.maxScrollExtent}');
      if (_uploadScrollController.position.pixels ==
              _uploadScrollController.position.maxScrollExtent &&
          !_uploadIsLoading) {
        _uploadIsLoading = true;
        _loadData();
      }
    });

    _loadData(index: 0);
    _loadData(index: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<R34CommunityUser?>(
      future: R34CommunityRepo.getCommunityUser(widget.userId),
      builder: (context, snapshot) {
        final communityUser = snapshot.data;
        dev.log('communityUser: ${jsonEncode(communityUser)}');
        return CustomScrollView(
          slivers: [
            // 可浮动且吸顶的 Container
            SliverPersistentHeader(
              pinned: true,
              delegate: _FloatingContainerDelegate(communityUser),
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
                        return _buildVideoWidget(video);
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
                        return _buildVideoWidget(video);
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
    );
  }

  Widget _buildVideoWidget(R34CommunityVideo video) {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(left: 10),
      child: Row(
        children: [
          CachedNetworkImage(
            imageUrl: video.thumbImageUrl,
            width: 160,
            height: 90,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.of(context).size.width - 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  video.title,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  direction: Axis.horizontal,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_outlined),
                        Text(video.uploadTime),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_arrow_outlined,
                        ),
                        Text(video.viewCount),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rate_review_outlined),
                        Text('${video.rating} (${video.ratingCount})'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// 可浮动且吸顶的 Container 的代理类
class _FloatingContainerDelegate extends SliverPersistentHeaderDelegate {
  final R34CommunityUser? _communityUser;

  _FloatingContainerDelegate(this._communityUser);

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
            color: Colors.grey,
          ),
          Container(
            height: currentHeight - screenTopPadding,
            color: Colors.grey,
            child: Stack(
              children: [
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
                      color: Colors.pink.shade500,
                    ),
                  ),
                ),
                Positioned(
                  left: maxNickOffset.dx,
                  top: maxNickOffset.dy + maxNickSize + 10,
                  child: Column(
                    children: [
                      Text('粉丝数 ${_communityUser?.subscriberCount ?? "未知"}'),
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
  double get maxExtent => 240;
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
      color: Colors.pinkAccent,
      child: TabBar(
        controller: tabController,
        tabs: [
          Tab(text: '上传的视频 (${communityUser?.uploadVideoCount ?? "未知"})'),
          Tab(text: '喜欢的视频 (${communityUser?.favoriteVideoCount ?? "未知"})'),
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
