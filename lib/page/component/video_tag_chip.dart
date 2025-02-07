import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/search_result_page.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';

class VideoSearchHistoryChip extends StatelessWidget {
  final String val;
  final double fontSize;
  final void Function()? onDelete;
  const VideoSearchHistoryChip(
    this.val, {
    super.key,
    this.onDelete,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        log('on tap $val');
        Navigator.of(context).pushNamed(
          PageRoutes.searchResultPage,
          arguments: SearchResultPageArg(val),
        );
      },
      child: Chip(
        label: Text(
          val,
          style: TextStyle(fontSize: fontSize, color: Colors.black),
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.grey[400],
        onDeleted: onDelete != null
            ? () {
                log('on delete $val');
                onDelete?.call();
              }
            : null,
        deleteIcon: onDelete != null ? Icon(Icons.delete) : null,
      ),
    );
  }
}

class VideoTagChip extends StatelessWidget {
  final VideoTag tag;
  final double fontSize;
  const VideoTagChip(this.tag, {super.key, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.searchResultPage,
          arguments: SearchResultPageArg('t:${tag.id}'),
        );
      },
      child: Chip(
        label: Text(tag.name,
            style: TextStyle(fontSize: fontSize, color: Colors.black)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.grey[400],
      ),
    );
  }
}

class VideoCategoryChip extends StatelessWidget {
  final VideoCategory category;
  final double fontSize;
  final bool showAvatar;
  const VideoCategoryChip(
    this.category, {
    super.key,
    this.fontSize = 14,
    this.showAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.searchResultPage,
          arguments: SearchResultPageArg('c:${category.name}'),
        );
      },
      child: Chip(
        label: showAvatar
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(fontSize / 4),
                    child: CachedNetworkImage(
                      imageUrl: category.imgUrl,
                      height: fontSize,
                    ),
                  ),
                  SizedBox(width: fontSize / 2),
                  Text(category.desc,
                      style:
                          TextStyle(fontSize: fontSize, color: Colors.black)),
                ],
              )
            : Text(category.desc,
                style: TextStyle(fontSize: fontSize, color: Colors.black)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.grey[400],
      ),
    );
  }
}

class VideoArtistChip extends StatelessWidget {
  final VideoArtistInfo artist;
  final double fontSize;
  final bool showAvatar;
  const VideoArtistChip(
    this.artist, {
    super.key,
    this.fontSize = 14,
    this.showAvatar = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed(
          PageRoutes.searchResultPage,
          arguments: SearchResultPageArg('a:${artist.name}'),
        );
      },
      child: Chip(
        label: showAvatar
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(fontSize / 4),
                    child: CachedNetworkImage(
                      imageUrl: artist.avatarUrl,
                      height: fontSize,
                    ),
                  ),
                  SizedBox(width: fontSize / 2),
                  Text(
                    artist.desc,
                    style: TextStyle(fontSize: fontSize, color: Colors.black),
                  ),
                ],
              )
            : Text(artist.desc,
                style: TextStyle(fontSize: fontSize, color: Colors.black)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.grey[400],
      ),
    );
  }
}
