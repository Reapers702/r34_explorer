import 'dart:developer';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/community_user_page.dart';
import 'package:r34_video/page/component/community_video_block.dart';
import 'package:r34_video/page/component/video_tag_chip.dart';
import 'package:r34_video/provider/settings_provider.dart';
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/r34_video_detail_repo.dart';
import 'package:r34_video/util/http_util.dart';
import 'package:r34_video/util/toast_util.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailPageArg {
  final R34Video r34video;
  DetailPageArg(this.r34video);
}

class DetailPage extends StatefulWidget {
  const DetailPage({super.key});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Future<R34VideoInfo?>? _videoFuture;
  final Map<String, String> _playRedirectUrl = {};

  void openVideo(String url) async {
    log('open video url $url');
    final settingsProvider = context.read<SettingsProvider>();
    if (settingsProvider.settingsModel!.parseAutoRedirect) {
      if (!_playRedirectUrl.containsKey(url)) {
        final redirectUrl = await HttpUtil.redirectUrl(url);
        if (redirectUrl == null || redirectUrl.isEmpty) {
          ToastUtil.showToast('Cannot Redirect Url, Please Try Again Later');
          return;
        }
        _playRedirectUrl[url] = redirectUrl;
      }
      url = _playRedirectUrl[url]!;
    }
    log('open video url redirect $url');

    if (Platform.isAndroid) {
      final intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: url,
        type: 'video/*',
      );
      intent.launchChooser('Choose an App');
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } else {
        log('Could not launch $uri');
      }
    }
  }

  void _showPlayDialog(Map<String, String> downloadUrls,
      Map<String, String> webUrls, PlayUrlType defaultUrlType) {
    final dlResolutions = downloadUrls.keys.toList();
    final webResolutions = webUrls.keys.toList();

    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Please choose resolution'),
          content: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.only(
              left: 10,
              right: 10,
            ),
            width: MediaQuery.of(context).size.width * 0.6,
            constraints: BoxConstraints(minHeight: 20, maxHeight: 300),
            child: DefaultTabController(
              length: 2,
              initialIndex: defaultUrlType == PlayUrlType.webPlay ? 0 : 1,
              child: Column(
                children: [
                  TabBar(
                    tabs: [Text('网页解析'), Text('下载链接')],
                    labelColor: Colors.grey,
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView.separated(
                          shrinkWrap: true,
                          itemCount: webResolutions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final resolution = webResolutions[index];
                            return ElevatedButton(
                              onPressed: () async =>
                                  openVideo(webUrls[resolution]!),
                              child: Text(resolution),
                            );
                          },
                        ),
                        ListView.separated(
                          shrinkWrap: true,
                          itemCount: dlResolutions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final resolution = dlResolutions[index];
                            return ElevatedButton(
                              onPressed: () async =>
                                  openVideo(downloadUrls[resolution]!),
                              child: Text(resolution),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 从 arguments 中提取参数
    final DetailPageArg pageArg =
        ModalRoute.of(context)?.settings.arguments as DetailPageArg;
    final r34Video = pageArg.r34video;
    _videoFuture ??= R34VideoDetailRepo.getVideoInfo(r34Video.detailUrl);

    final settingsProvider = context.read<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('视频详情'),
      ),
      body: FutureBuilder<R34VideoInfo?>(
        future: _videoFuture,
        builder: (futureContext, snapshot) {
          final videoDetail = snapshot.data;
          if (videoDetail == null) {
            return Center(
              child: Text('Data Still Loading'),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: 240,
                child: GestureDetector(
                  onTap: () => _showPlayDialog(
                      videoDetail.downloadUrls,
                      videoDetail.playUrls,
                      settingsProvider.settingsModel!.playUrlType),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      CachedNetworkImage(
                        height: 240,
                        imageUrl: videoDetail.thumbImageUrl!,
                        fit: BoxFit.fitHeight,
                      ),
                      Container(
                        color: Colors.white.withAlpha((0.3 * 255).toInt()),
                      ),
                      Positioned(
                        top: 0,
                        bottom: 0,
                        child: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 40,
                          child: TabBar(
                            dividerColor: Colors.red,
                            indicatorColor: Colors.pinkAccent,
                            labelColor: Colors.pinkAccent,
                            unselectedLabelColor: Colors.grey,
                            tabs: [
                              Tab(text: "视频信息"),
                              Tab(text: "评论"),
                            ],
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              _buildVideoInfoTab(context, videoDetail),
                              Center(child: Text('这里不太想做了'))
                            ],
                          ),
                        ),
                      ],
                    )),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVideoInfoTab(BuildContext context, R34VideoInfo video) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUploaderLabel(context, video.uploaderInfo),
          const SizedBox(height: 8),
          Container(
            margin: EdgeInsets.only(left: 8),
            child: Text(
              video.title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildArtistLabel(context, video.artistInfos),
          const SizedBox(height: 8),
          _buildCategoryLabel(context, video.categories),
          const SizedBox(height: 8),
          _buildTagLabel(context, video.tags),
          const SizedBox(height: 8),
          const Divider(color: Colors.red, indent: 8, endIndent: 8),
          _buildRelatedVideo(context, video.relatedVideos),
        ],
      ),
    );
  }

  Widget _buildUploaderLabel(
      BuildContext context, VideoUploaderInfo uploaderInfo) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.communityUserPage,
          arguments: CommunityUserPageArg(userId: uploaderInfo.id),
        );
      },
      child: Container(
        height: 40,
        color: Colors.grey[500],
        child: Row(
          children: [
            const SizedBox(width: 10),
            CachedNetworkImage(imageUrl: uploaderInfo.avatarUrl),
            const SizedBox(width: 10),
            Text(uploaderInfo.name, style: TextStyle(fontSize: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistLabel(
      BuildContext context, List<VideoArtistInfo> artistInfos) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        const SizedBox(width: 50, child: Text('艺术家')),
        Expanded(
          child: Wrap(
            direction: Axis.horizontal,
            children: artistInfos
                .map((e) => VideoArtistChip(e, showAvatar: true))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryLabel(
      BuildContext context, List<VideoCategory> categories) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        const SizedBox(width: 50, child: Text('分类')),
        Expanded(
          child: Wrap(
            direction: Axis.horizontal,
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (e) => VideoCategoryChip(e, showAvatar: true),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTagLabel(BuildContext context, List<VideoTag> tags) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        const SizedBox(width: 50, child: Text('Tag')),
        Expanded(
          child: Wrap(
            direction: Axis.horizontal,
            spacing: 4,
            runSpacing: 4,
            children: tags.map((e) => VideoTagChip(e)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedVideo(
      BuildContext context, List<R34CommunityVideo> videos) {
    return Container(
      padding: EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Related Videos',
            style: TextStyle(fontSize: 20),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemCount: videos.length,
            itemBuilder: (context, index) =>
                CommunityVideoBlock(video: videos[index]),
          ),
        ],
      ),
    );
  }
}
