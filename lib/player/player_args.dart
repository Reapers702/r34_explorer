import 'package:r34_video/repo/entity/r34_page.dart';

/// 一个可播放的清晰度。
///
/// 站点详情页会同时给出「网页解析」和「下载链接」两套地址，两边按清晰度一一对应，
/// 这里统一成一个列表，播放器只管切换 [url]。
class StreamResolution {
  final String label;
  final String url;

  /// 来源：网页解析 / 下载直链。
  final StreamSource source;

  const StreamResolution({
    required this.label,
    required this.url,
    this.source = StreamSource.web,
  });

  bool get playable => url.trim().isNotEmpty;

  /// 解析出「720p」里的数字，用于挑选默认清晰度。解析不出来时当作 0。
  int get height {
    final match = RegExp(r'(\d{3,4})').firstMatch(label);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  @override
  String toString() => 'StreamResolution($label, $source, $url)';
}

enum StreamSource {
  web,
  download,
  ;

  String get desc => this == StreamSource.web ? '网页解析' : '下载链接';
}

/// 播放页需要的全部信息。
class PlayerArgs {
  final String title;

  /// 时长文案，例如 `10:17`。
  final String durationText;

  final String? posterUrl;

  /// 详情页地址，解码失败时可回退。
  final String? detailUrl;

  /// 按清晰度从高到低排好序的候选地址。
  final List<StreamResolution> resolutions;

  PlayerArgs({
    required this.title,
    required this.resolutions,
    this.durationText = '',
    this.posterUrl,
    this.detailUrl,
  });

  /// 把详情页解析出的两张表合并成一个列表。
  ///
  /// 排序规则：分辨率高的在前；同分辨率优先「网页解析」（通常是直链）。
  factory PlayerArgs.fromUrls({
    required String title,
    required Map<String, String> webUrls,
    required Map<String, String> downloadUrls,
    String durationText = '',
    String? posterUrl,
    String? detailUrl,
  }) {
    final merged = <String, StreamResolution>{};

    void put(String label, String url, StreamSource source) {
      if (url.trim().isEmpty) {
        return;
      }
      final existing = merged[label];
      if (existing == null ||
          (existing.source == StreamSource.download &&
              source == StreamSource.web)) {
        merged[label] = StreamResolution(
          label: label,
          url: url,
          source: source,
        );
      }
    }

    webUrls.forEach((label, url) => put(label, url, StreamSource.web));
    downloadUrls.forEach((label, url) => put(label, url, StreamSource.download));

    final list = merged.values.where((e) => e.playable).toList()
      ..sort((a, b) {
        final byHeight = b.height.compareTo(a.height);
        if (byHeight != 0) {
          return byHeight;
        }
        return a.source.index.compareTo(b.source.index);
      });

    return PlayerArgs(
      title: title,
      resolutions: list,
      durationText: durationText,
      posterUrl: posterUrl,
      detailUrl: detailUrl,
    );
  }

  /// 从视频列表项直接构建（列表页只有封面和时长）。
  factory PlayerArgs.fromVideo(
    R34Video video, {
    required Map<String, String> webUrls,
    required Map<String, String> downloadUrls,
  }) {
    return PlayerArgs.fromUrls(
      title: video.title,
      webUrls: webUrls,
      downloadUrls: downloadUrls,
      durationText: video.videoDuration,
      posterUrl: video.thumbImageUrl,
      detailUrl: video.detailUrl,
    );
  }

  /// 首选清晰度下标。`preferredLabel` 命中就用它，否则用最高清晰度。
  int initialIndex(String? preferredLabel) {
    if (resolutions.isEmpty) {
      return 0;
    }
    if (preferredLabel != null && preferredLabel.isNotEmpty) {
      final index = resolutions.indexWhere((e) => e.label == preferredLabel);
      if (index >= 0) {
        return index;
      }
    }
    return 0;
  }
}
