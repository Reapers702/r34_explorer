import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/repo/entity/r34_page.dart';

class CommunityVideoBlock extends StatelessWidget {
  final R34CommunityVideo video;

  const CommunityVideoBlock({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.detailPage,
          arguments: DetailPageArg(
            R34Video(
              title: video.title,
              detailUrl: video.detailUrl,
              videoPreviewUrl: R34Const.websiteIcon,
              thumbImageUrl: video.thumbImageUrl,
              videoDuration: video.duration,
            ),
          ),
        );
      },
      child: SizedBox(
        height: 95,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                CachedNetworkImage(
                  imageUrl: video.thumbImageUrl,
                  width: 160,
                  height: 90,
                  progressIndicatorBuilder: (context, url, downloadProgress) =>
                      LinearProgressIndicator(value: downloadProgress.progress),
                  errorWidget: (context, url, error) => Icon(Icons.error),
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
                      video.duration,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
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
      ),
    );
  }
}
