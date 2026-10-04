import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:r34_video/page/component/common/app_state_view.dart';
import 'package:r34_video/page/component/common/section_header.dart';
import 'package:r34_video/page/component/video_tag_chip.dart';
import 'package:r34_video/repo/entity/r34_xxx_post.dart';
import 'package:r34_video/repo/r34_xxx_repo.dart';
import 'package:r34_video/theme/app_colors.dart';
import 'package:r34_video/theme/app_dimens.dart';

class R34XxxDetailPageArgs {
  final R34XxxPost post;

  const R34XxxDetailPageArgs(this.post);
}

/// rule34.xxx 详情：看图为主。
///
/// 默认先加载 `sample`（省流量），点一下切到原图；双指缩放看细节。
class R34XxxDetailPage extends StatefulWidget {
  const R34XxxDetailPage({super.key});

  @override
  State<R34XxxDetailPage> createState() => _R34XxxDetailPageState();
}

class _R34XxxDetailPageState extends State<R34XxxDetailPage> {
  R34XxxPost? _post;
  bool _showOriginal = false;
  bool _immersive = false;

  List<R34XxxComment>? _comments;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_post != null) {
      return;
    }
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is R34XxxDetailPageArgs) {
      _post = args.post;
      _loadComments();
    }
  }

  @override
  void dispose() {
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  Future<void> _loadComments() async {
    final post = _post;
    if (post == null) {
      return;
    }
    final comments = await R34XxxRepo.getComments(post.id);
    if (mounted) {
      setState(() => _comments = comments);
    }
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(
      _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    if (post == null) {
      return const Scaffold(
        body: AppStateView.error(title: '缺少帖子数据'),
      );
    }

    return Scaffold(
      backgroundColor: _immersive ? Colors.black : AppColors.background,
      appBar: _immersive
          ? null
          : AppBar(
              title: Text(
                'post #${post.id}',
                style: const TextStyle(fontSize: 15),
              ),
            ),
      body: _immersive
          ? Stack(
              children: [
                Positioned.fill(child: _buildImage(post, immersive: true)),
                Positioned(
                  right: AppSpacing.md,
                  top: MediaQuery.of(context).padding.top + AppSpacing.md,
                  child: _CircleButton(
                    icon: Icons.close_fullscreen_rounded,
                    onTap: _toggleImmersive,
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              children: [
                _buildImage(post),
                _buildMeta(post),
                _buildTags(post),
                _buildComments(),
              ],
            ),
    );
  }

  Widget _buildImage(R34XxxPost post, {bool immersive = false}) {
    // 先 sample 后原图：sample 通常只有几百 KB，原图动辄十几 MB。
    final useOriginal = _showOriginal;
    final url = useOriginal
        ? post.fileUrl
        : (post.sampleUrl.isNotEmpty ? post.sampleUrl : post.fileUrl);

    final canvas = ColoredBox(
      color: Colors.black,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (context, u) => const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ),
          errorWidget: (context, u, error) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 40,
            ),
          ),
        ),
      ),
    );

    return GestureDetector(
      onTap: _toggleImmersive,
      onLongPress: () {
        setState(() => _showOriginal = !_showOriginal);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_showOriginal ? '已切到原图' : '已切回压缩图'),
              duration: const Duration(seconds: 1),
            ),
          );
      },
      child: immersive
          ? canvas
          : AspectRatio(
              aspectRatio: post.aspectRatio.clamp(0.4, 2.5),
              child: canvas,
            ),
    );
  }

  Widget _buildMeta(R34XxxPost post) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              VideoMetaItem(
                icon: Icons.aspect_ratio_rounded,
                text: '${post.width}×${post.height}',
              ),
              VideoMetaItem(
                icon: Icons.thumb_up_outlined,
                text: '${post.score}',
              ),
              VideoMetaItem(
                icon: Icons.flag_outlined,
                text: post.ratingLabel,
              ),
              if (post.owner.isNotEmpty)
                VideoMetaItem(
                  icon: Icons.person_outline_rounded,
                  text: post.owner,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _showOriginal ? '当前：原图（长按切换）' : '当前：压缩图（长按切原图）',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildTags(R34XxxPost post) {
    final tags = post.tags;
    if (tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '标签',
          subtitle: '${tags.length} 个',
          trailing: TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: post.tagsRaw));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('标签已复制'),
                    duration: Duration(seconds: 1),
                  ),
                );
            },
            child: const Text('复制', style: TextStyle(fontSize: 12)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: tags
                .map((tag) => AppChip.text(tag, fontSize: 12))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildComments() {
    final comments = _comments;
    if (comments == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (comments.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: '评论'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              '这个帖子还没有评论',
              style: TextStyle(fontSize: 13, color: AppColors.textHint),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: '评论', subtitle: '${comments.length} 条'),
        ...comments.map(
          (c) => Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              0,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.author.isEmpty ? '匿名' : c.author,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (c.createdAt.isNotEmpty)
                        Text(
                          c.createdAt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    c.body,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
