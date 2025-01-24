class R34VideoInfo {
  String title;
  String? thumbImageUrl;
  Map<String, String> downloadUrls;

  R34VideoInfo({
    required this.title,
    required this.thumbImageUrl,
    required this.downloadUrls,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'thumbImageUrl': thumbImageUrl,
      'downloadUrls': downloadUrls,
    };
  }
}
