import 'dart:developer';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/r34_repo.dart';
import 'package:url_launcher/url_launcher.dart';

class DetailPageArg {
  final R34Video r34video;
  DetailPageArg(this.r34video);
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    // 从 arguments 中提取参数
    final DetailPageArg pageArg =
        ModalRoute.of(context)?.settings.arguments as DetailPageArg;
    final r34Video = pageArg.r34video;
    final future = R34Repo.getVideoInfo(r34Video.detailUrl);

    return Scaffold(
      appBar: AppBar(
        title: Text('Video Detail'),
      ),
      body: FutureBuilder<R34VideoInfo>(
        future: future,
        builder: (context, snapshot) {
          final videoDetail = snapshot.data;
          if (videoDetail == null) {
            return Center(
              child: Text('Data Still Loading'),
            );
          }

          final resolutions = videoDetail.downloadUrls.keys.toList();
          return Column(
            children: [
              Expanded(
                flex: 1,
                child: CachedNetworkImage(imageUrl: videoDetail.thumbImageUrl!),
              ),
              Expanded(
                flex: 2,
                child: ListView.separated(
                    itemBuilder: (context, index) {
                      final resolution = resolutions[index];
                      return ElevatedButton(
                        onPressed: () async => openVideo(
                          videoDetail.downloadUrls[resolution]!,
                        ),
                        child: Text(resolution),
                      );
                    },
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemCount: resolutions.length),
              ),
            ],
          );
        },
      ),
    );
  }
}
