import 'package:r34_video/constant/r34_const.dart';

class R34VideoInfo {
  String title;
  String? thumbImageUrl;
  Map<String, String> downloadUrls;

  VideoUploaderInfo uploaderInfo;
  List<VideoArtistInfo> artistInfos;
  List<VideoCategory> categories;
  List<VideoTag> tags;

  R34VideoInfo({
    required this.title,
    required this.thumbImageUrl,
    required this.downloadUrls,
    required this.uploaderInfo,
    this.artistInfos = const [],
    this.categories = const [],
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'thumbImageUrl': thumbImageUrl,
      'downloadUrls': downloadUrls,
      'uploaderInfo': uploaderInfo.toJson(),
      'artistInfos': artistInfos.map((e) => e.toJson()).toList(),
      'categories': categories.map((e) => e.toJson()).toList(),
      'tags': tags.map((e) => e.toJson()).toList(),
    };
  }
}

class VideoCategory {
  String name;
  String desc;
  String? imgUrl;
  VideoCategory(this.name, this.desc, imgUrl)
      : imgUrl = imgUrl ?? R34Const.websiteIcon;

  Map<String, dynamic> toJson() => {
        'name': name,
        'desc': desc,
        'imgUrl': imgUrl,
      };
}

class VideoTag {
  String name;
  String id;
  VideoTag(this.name, this.id);

  Map<String, dynamic> toJson() => {
        'name': name,
        'id': id,
      };
}

class VideoArtistInfo {
  String name;
  String desc;
  String? avatarUrl;
  VideoArtistInfo(this.name, this.desc, avatarUrl)
      : avatarUrl = avatarUrl ?? R34Const.websiteIcon;

  Map<String, dynamic> toJson() => {
        'name': name,
        'desc': desc,
        'avatarUrl': avatarUrl,
      };
}

class VideoUploaderInfo {
  int id;
  String name;
  String avatarUrl;
  VideoUploaderInfo(String id, this.name, this.avatarUrl) : id = int.parse(id);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarUrl': avatarUrl,
      };
}
