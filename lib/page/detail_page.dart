import 'dart:developer';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/community_user_page.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/r34_video_detail_repo.dart';
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
  void openVideo(String url) async {
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

  void _showPlayDialog(Map<String, String> downloadUrls) {
    final resolutions = downloadUrls.keys.toList();
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Please choose resolution'),
          content: Container(
            padding: EdgeInsets.only(
              left: 10,
              right: 10,
            ),
            child: ListView.separated(
                itemBuilder: (context, index) {
                  final resolution = resolutions[index];
                  return ElevatedButton(
                    onPressed: () async => openVideo(
                      downloadUrls[resolution]!,
                    ),
                    child: Text(resolution),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemCount: resolutions.length),
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
    final future = R34VideoDetailRepo.getVideoInfo(r34Video.detailUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text('Video Detail'),
      ),
      body: SafeArea(
        child: FutureBuilder<R34VideoInfo?>(
          future: future,
          builder: (futureContext, snapshot) {
            final videoDetail = snapshot.data;
            if (videoDetail == null) {
              return Center(
                child: Text('Data Still Loading'),
              );
            }

            return Column(
              children: [
                Container(
                  height: 240,
                  child: GestureDetector(
                    onTap: () => _showPlayDialog(videoDetail.downloadUrls),
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        CachedNetworkImage(
                            imageUrl: videoDetail.thumbImageUrl!),
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
                          TabBar(
                            indicatorColor: Colors.white,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey,
                            tabs: [
                              Tab(text: "Video Info"),
                              Tab(text: "Reviews"),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildVideoInfoTab(context, videoDetail),
                                Placeholder(),
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
      ),
    );
  }

  Widget _buildVideoInfoTab(BuildContext context, R34VideoInfo video) {
    return Column(
      children: [
        _buildUploaderLabel(context, video.uploaderInfo),
        Text(video.title),
      ],
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
        color: Colors.red,
        child: Row(
          children: [
            CachedNetworkImage(imageUrl: uploaderInfo.avatarUrl),
            Text(uploaderInfo.name),
          ],
        ),
      ),
    );
  }
}
