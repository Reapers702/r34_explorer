class R34Page {
  List<R34Video> videos = [];

  R34Page({required this.videos});

  Map<String, dynamic> toJson() {
    return {
      'videos': videos.map((e) => e.toJson()).toList(),
    };
  }
}

class R34Video {
  String title;
  String detailUrl;
  String videoPreviewUrl;
  String thumbImageUrl;

  String videoDuration;

  R34Video({
    required this.title,
    required this.detailUrl,
    required this.videoPreviewUrl,
    required this.thumbImageUrl,
    required this.videoDuration,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'detailUrl': detailUrl,
      'videoPreviewUrl': videoPreviewUrl,
      'thumbImageUrl': thumbImageUrl,
      'videoDuration': videoDuration,
    };
  }
}
