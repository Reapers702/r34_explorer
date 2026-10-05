import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/community_user_page.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/page/component/community_video_block.dart';
import 'package:r34_video/page/component/video_tag_chip.dart';
import 'package:r34_video/player/player_args.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/local_content_repo.dart';
import 'package:r34_video/repo/r34_comment_repo.dart';
import 'package:r34_video/repo/r34_video_detail_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

class DetailPageArgs {
  final R34Video r34video;

  DetailPageArgs(this.r34video);
}

class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  DetailPageArgs? _args;
  Future<R34VideoInfo?>? _videoFuture;
  Future<List<R34Comment>>? _commentFuture;

  bool _favorited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_args != null) {
      return;
    }
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is! DetailPageArgs) {
      return;
    }
    _args = arguments;
    _videoFuture =
        R34VideoDetailRepo.getVideoInfo(arguments.r34video.detailUrl);
    _commentFuture = R34CommentRepo.getComments(arguments.r34video.detailUrl);
    _onViewed(arguments.r34video);
  }

  /// 进入详情即记一条本地历史并同步收藏状态。
  ///（历史在「收藏」Tab 的“浏览历史”子页展示，按站点可过滤。）
  Future<void> _onViewed(R34Video video) async {
    LocalContentRepo.pushHistory(SavedContent.fromVideo(video));
    final fav = await LocalContentRepo.isFavorite(video.detailUrl);
    if (mounted) {
      setState(() => _favorited = fav);
    }
  }

  Future<void> _toggleFavorite() async {
    final video = _args?.r34video;
    if (video == null) {
      return;
    }
    final fav = await LocalContentRepo.toggleFavorite(SavedContent.fromVideo(video));
    if (mounted) {
      setState(() => _favorited = fav);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openPlayer(R34VideoInfo video) {
    if (video.playUrls.isEmpty && video.downloadUrls.isEmpty) {
      _toast('这个视频没有解析到可播放的地址');
      return;
    }

    final args = PlayerArgs.fromUrls(
      title: video.title,
      webUrls: video.playUrls,
      downloadUrls: video.downloadUrls,
      durationText: _args?.r34video.videoDuration ?? '',
      posterUrl: video.thumbImageUrl,
      detailUrl: _args?.r34video.detailUrl,
    );

    if (args.resolutions.isEmpty) {
      _toast('这个视频没有可播放的地址');
      return;
    }

    Navigator.of(context).pushNamed(
      PageRoutes.playerPage,
      arguments: args,
    );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _args?.r34video.title ?? '视频详情',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: _favorited ? '取消收藏' : '收藏',
            onPressed: _toggleFavorite,
            icon: Icon(
              _favorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _favorited ? AppColors.error : null,
            ),
          ),
        ],
      ),
      body: FutureBuilder<R34VideoInfo?>(
        future: _videoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final video = snapshot.data;
          if (video == null) {
            return AppStateView.error(
              title: '详情加载失败',
              description: '可能是网络问题，或者这个视频被删除了',
              onAction: () {
                setState(() {
                  _videoFuture = R34VideoDetailRepo.getVideoInfo(
                    _args!.r34video.detailUrl,
                  );
                });
              },
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              // Header 用 16:9 比例，横屏/窄高窗口下会撑得比可用高度还高，
              // 导致外层 Column 底部溢出。这里给个上限：不能超过可用高度的 45%。
              final aspectHeight = constraints.maxWidth / 16 * 9;
              final headerHeight = aspectHeight > constraints.maxHeight * 0.45
                  ? constraints.maxHeight * 0.45
                  : aspectHeight;

              return Column(
                children: [
                  _buildHeader(video, height: headerHeight),
                  _buildTabs(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildInfoTab(video),
                        _buildCommentTab(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(R34VideoInfo video, {required double height}) {
    return SizedBox(
      height: height,
      child: GestureDetector(
        onTap: () => _openPlayer(video),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (video.thumbImageUrl != null)
              CachedNetworkImage(
                imageUrl: video.thumbImageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const AppSkeleton(radius: 0),
                errorWidget: (context, url, error) => const ColoredBox(
                  color: AppColors.skeleton,
                ),
              )
            else
              const ColoredBox(color: AppColors.skeleton),
            const ColoredBox(color: Color(0x66000000)),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              bottom: AppSpacing.md,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.badgeBackground,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '在应用内播放 · ${video.playUrls.length} 个清晰度',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: '视频信息'), Tab(text: '评论')],
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildInfoTab(R34VideoInfo video) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: [
        if (video.uploaderInfo.id > 0) _buildUploader(video.uploaderInfo),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Text(
            video.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        if (video.artistInfos.isNotEmpty)
          VideoChipRow(
            label: '艺术家',
            children: video.artistInfos
                .map((e) => VideoArtistChip(e, showAvatar: true))
                .toList(),
          ),
        if (video.categories.isNotEmpty)
          VideoChipRow(
            label: '分类',
            children: video.categories
                .map((e) => VideoCategoryChip(e, showAvatar: true))
                .toList(),
          ),
        if (video.tags.isNotEmpty)
          VideoChipRow(
            label: 'Tag',
            children: video.tags.map((e) => VideoTagChip(e)).toList(),
          ),
        if (video.downloadUrls.isNotEmpty) ...[
          const SectionHeader(title: '下载'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: video.downloadUrls.entries
                  .map(
                    (entry) => AppChip.text(
                      entry.key,
                      onTap: () => _openPlayer(video),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (video.relatedVideos.isNotEmpty) ...[
          const SectionHeader(title: '相关视频'),
          ...video.relatedVideos.map(
            (related) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: CommunityVideoBlock(video: related),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUploader(VideoUploaderInfo uploader) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.communityUserPage,
          arguments: CommunityUserPageArg(
            userId: uploader.id,
            avatarUrl: uploader.avatarUrl,
          ),
        );
      },
      child: Container(
        color: AppColors.surface,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: uploader.avatarUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => const SizedBox(
                  width: 36,
                  height: 36,
                  child: ColoredBox(color: AppColors.skeleton),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    uploader.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    '查看作者主页',
                    style: TextStyle(fontSize: 11, color: AppColors.textHint),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTab() {
    return FutureBuilder<List<R34Comment>>(
      future: _commentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final comments = snapshot.data ?? const <R34Comment>[];
        if (comments.isEmpty) {
          return AppStateView.empty(
            title: '还没有评论',
            description: '站点评论由前端脚本注入，拿不到时就会显示这里',
            actionLabel: '重新加载',
            onAction: () {
              setState(() {
                _commentFuture =
                    R34CommentRepo.getComments(_args!.r34video.detailUrl);
              });
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.page),
          itemCount: comments.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) => _CommentTile(comments[index]),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final R34Comment comment;

  const _CommentTile(this.comment);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: comment.avatarUrl == null
                ? const SizedBox(
                    width: 32,
                    height: 32,
                    child: ColoredBox(color: AppColors.skeleton),
                  )
                : CachedNetworkImage(
                    imageUrl: comment.avatarUrl!,
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const SizedBox(
                      width: 32,
                      height: 32,
                      child: ColoredBox(color: AppColors.skeleton),
                    ),
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName.isEmpty ? '匿名' : comment.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (comment.timeText.isNotEmpty)
                      Text(
                        comment.timeText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
