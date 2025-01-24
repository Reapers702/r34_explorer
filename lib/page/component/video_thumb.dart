import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/page/page_routes.dart';
import 'package:r34_video/repo/entity/r34_page.dart';

class VideoThumb extends StatelessWidget {
  final R34Video r34video;

  const VideoThumb(this.r34video, {super.key});

  @override
  Widget build(BuildContext context) {
    double maxWidth = MediaQuery.of(context).size.width * 0.4;
    double maxHeight = maxWidth * 9 / 16;

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomLeft,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  PageRoutes.detailPage,
                  arguments: DetailPageArg(r34video),
                );
              },
              child: CachedNetworkImage(
                imageUrl: r34video.thumbImageUrl,
                width: maxWidth,
                height: maxHeight,
                fit: BoxFit.fill,
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    LinearProgressIndicator(value: downloadProgress.progress),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            ),
            Positioned(
              left: 5,
              bottom: 5,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  r34video.videoDuration,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        SizedBox(
          width: maxWidth,
          child: Text(
            r34video.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
