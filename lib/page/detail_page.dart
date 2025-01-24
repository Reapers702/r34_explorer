import 'dart:developer';

import 'package:android_intent_plus/android_intent.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';
import 'package:r34_video/repo/r34_repo.dart';

class DetailPageArg {
  final R34Video r34video;
  DetailPageArg(this.r34video);
}

class DetailPage extends StatelessWidget {
  const DetailPage({super.key});

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
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: Text('Data Still Loading'),
            );
          }

          final resolutions = data.downloadUrls.keys.toList();
          return Column(
            children: [
              Expanded(
                  flex: 1,
                  child: CachedNetworkImage(imageUrl: data.thumbImageUrl!)),
              Expanded(
                flex: 2,
                child: ListView.separated(
                    itemBuilder: (context, index) {
                      return ElevatedButton(
                          onPressed: () async {
                            final url = data.downloadUrls[resolutions[index]]!;
                            log('url: $url');

                            final intent = AndroidIntent(
                              action: 'android.intent.action.VIEW',
                              data: url,
                              type: 'video/*',
                            );
                            intent.launchChooser('选择应用打开');

                            // if (await canLaunchUrl(uri)) {
                            //   await launchUrl(
                            //     uri,
                            //     mode: LaunchMode.externalNonBrowserApplication,
                            //   );
                            // } else {
                            //   log('Could not launch $uri');
                            // }
                          },
                          child: Text(
                            resolutions[index],
                          ));
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
