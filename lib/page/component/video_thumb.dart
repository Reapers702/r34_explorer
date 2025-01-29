import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/page/detail_page.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/repo/entity/r34_page.dart';

class VideoThumb extends StatelessWidget {
  final R34Video? r34video;
  static const double fontSize = 12;
  static const double imgTextSpacing = 6;

  const VideoThumb(this.r34video, {super.key});

  static VideoThumb fromLoading() {
    return VideoThumb(null);
  }

  @override
  Widget build(BuildContext context) {
    if (r34video == null) {
      return _buildLoading(context);
    }

    double imgMaxWidth = MediaQuery.of(context).size.width * 0.47;
    double imgMaxHeight = imgMaxWidth * 9 / 16;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.white,
        height: imgMaxHeight + imgTextSpacing * 2 + fontSize * 3,
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomLeft,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      PageRoutes.detailPage,
                      arguments: DetailPageArg(r34video!),
                    );
                  },
                  child: CachedNetworkImage(
                    imageUrl: r34video!.thumbImageUrl,
                    width: imgMaxWidth,
                    height: imgMaxHeight,
                    fit: BoxFit.fill,
                    progressIndicatorBuilder:
                        (context, url, downloadProgress) =>
                            LinearProgressIndicator(
                                value: downloadProgress.progress),
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
                      r34video!.videoDuration,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              width: imgMaxWidth,
              child: Text(
                r34video!.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    double imgMaxWidth = MediaQuery.of(context).size.width * 0.47;
    double imgMaxHeight = imgMaxWidth * 9 / 16;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.white,
        height: imgMaxHeight + imgTextSpacing * 2 + fontSize * 3,
        child: Column(
          children: [
            SizedBox(
              width: imgMaxWidth,
              height: imgMaxHeight,
              child: LinearProgressIndicator(),
            ),
            SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              width: imgMaxWidth,
              child: Text(
                'Loading ...',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
