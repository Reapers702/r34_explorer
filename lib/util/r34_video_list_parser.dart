import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:r34_video/repo/entity/r34_community_video.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/util/log_util.dart';

/// 视频列表所在区块。
///
/// 站点各个页面用的 block id 不同，但卡片 DOM 结构是一致的，
/// 所以解析逻辑只写一份，靠这个枚举区分容器。
enum ParseType {
  homepage,
  favorite,
  upload,
  watchHistory,
  related,
  searchKeyword,
  searchCommon,
  ;

  String get parseId => {
        homepage: 'custom_list_videos_most_recent_videos_items',
        favorite: 'list_videos_favourite_videos_items',
        upload: 'list_videos_uploaded_videos_items',
        watchHistory: 'list_videos_my_watch_history_items',
        related: 'custom_list_videos_related_videos_items',
        searchKeyword: 'custom_list_videos_videos_list_search_items',
        searchCommon: 'custom_list_videos_common_videos_items',
      }[this]!;

  /// 分页容器 id。
  String get paginationId => {
        homepage: 'custom_list_videos_most_recent_videos_pagination',
        favorite: 'list_videos_favourite_videos_pagination',
        upload: 'list_videos_uploaded_videos_pagination',
        watchHistory: '',
        related: '',
        searchKeyword: 'custom_list_videos_videos_list_search_pagination',
        searchCommon: 'custom_list_videos_common_videos_pagination',
      }[this]!;
}

/// 站点列表页 DOM 解析。
///
/// 早期是三份几乎一样的实现（首页、搜索、社区），字段稍有缺失就会整页解析失败。
/// 现在统一成一份，并且**单张卡片解析失败只跳过这一张**，不再让整个列表变空。
class R34VideoListParser {
  static final RegExp _ratingInfoReg = RegExp(r'(\d+)%?\s*\(([\d\w.,KMB]+)\)');
  static final RegExp _durationReg = RegExp(r'(\d+):(\d{2})(?::(\d{2}))?');

  /// 网格卡片（`a.th.js-open-popup`）。
  static List<R34Video> parseVideosIn({
    String? body,
    dom.Document? doc,
    required ParseType parseType,
  }) {
    final document = doc ?? parser.parse(body ?? '');
    final parent = document.getElementById(parseType.parseId);
    if (parent == null) {
      LogUtil.warn('parse videos: container ${parseType.parseId} not found');
      return const [];
    }

    final result = <R34Video>[];
    for (final anchor in parent.querySelectorAll('a.th')) {
      final video = _parseGridItem(anchor);
      if (video != null) {
        result.add(video);
      }
    }
    return result;
  }

  static R34Video? _parseGridItem(dom.Element anchor) {
    final detailUrl = anchor.attributes['href'];
    if (detailUrl == null || detailUrl.isEmpty) {
      return null;
    }

    final title = anchor.attributes['title']?.trim().isNotEmpty == true
        ? anchor.attributes['title']!
        : (anchor.querySelector('.thumb_title')?.text.trim() ?? '未知标题');

    final img = anchor.querySelector('img.thumb');
    final thumbImageUrl = img?.attributes['data-webp'] ??
        img?.attributes['data-original'] ??
        img?.attributes['src'] ??
        '';

    final previewWrap = anchor.querySelector('div.img.wrap_image');
    final videoPreviewUrl = previewWrap?.attributes['data-preview'] ?? '';

    // 广告卡片（Advertisement）没有封面图，跳过，避免点进详情页后出错。
    if (thumbImageUrl.isEmpty) {
      return null;
    }

    final duration = anchor.querySelector('div.time')?.text.trim() ?? '';

    return R34Video(
      title: title,
      detailUrl: detailUrl,
      videoPreviewUrl: videoPreviewUrl,
      thumbImageUrl: thumbImageUrl,
      videoDuration: duration,
    );
  }

  /// 搜索结果（网格 + 总页数）。
  static R34Page parseSearchResult({
    required ParseType parseType,
    String? body,
    dom.Document? doc,
  }) {
    final document = doc ?? parser.parse(body ?? '');
    final videos = parseVideosIn(doc: document, parseType: parseType);
    return R34Page(
      videos: videos,
      pageCount: parsePageCount(document, parseType),
    );
  }

  /// 总页数。
  ///
  /// 站点分页里「Last」按钮上带 `data-parameters="...:N"`，早期代码只认
  /// `href` 一种形式，遇到 `data-parameters` 就永远只有 1 页。
  ///
  /// 后来发现分页链接**全部**都带 `data-parameters`（首页 `from:02`、
  /// 搜索页 `q:x;from_videos+from_albums:02`）。若像早期版本那样在
  /// 第一个数字 > 1 的链接处提前 `break`，任何搜索/列表都只会显示 2 页，
  /// 所以这里改成遍历所有链接、取其中出现的最大页码 —— 「Last」链接的
  /// `data-parameters` 就是总页数，天然是最大值。
  static int parsePageCount(dom.Document doc, ParseType parseType) {
    if (parseType.paginationId.isEmpty) {
      return 1;
    }
    final parent = doc.getElementById(parseType.paginationId);
    if (parent == null) {
      return 1;
    }

    var pageCount = 1;
    for (final link in parent.getElementsByTagName('a')) {
      final parameters = link.attributes['data-parameters'] ?? '';
      final href = link.attributes['href'] ?? '';
      final label = link.text.trim();

      // 纯数字标签（01、02、…、09）。
      final numeric = int.tryParse(label);
      if (numeric != null) {
        if (numeric > pageCount) {
          pageCount = numeric;
        }
        continue;
      }

      // 「Last」/ `data-parameters` / `/page/` 链接：参数里的数字是页码，
      // 取全部链接中的最大值（Last 的页码即总页数）。
      if (label == 'Last' ||
          parameters.contains(':') ||
          href.contains('/page/')) {
        final fromParams = _lastNumber(parameters) ?? _lastNumber(href);
        if (fromParams != null && fromParams > pageCount) {
          pageCount = fromParams;
        }
      }
    }
    return pageCount;
  }

  static int? _lastNumber(String source) {
    if (source.isEmpty) {
      return null;
    }
    final matches = RegExp(r'(\d+)').allMatches(source).toList();
    if (matches.isEmpty) {
      return null;
    }
    final value = int.tryParse(matches.last.group(1)!);
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  /// 详情页的「相关视频」。
  static List<R34CommunityVideo> parseDocToRelatedVideo({
    String? body,
    dom.Document? doc,
  }) {
    final document = doc ?? parser.parse(body ?? '');
    final parent = document.getElementById(ParseType.related.parseId);
    if (parent == null) {
      return const [];
    }

    final result = <R34CommunityVideo>[];
    for (final anchor in parent.querySelectorAll('a.th')) {
      final item = _parseCommunityItem(anchor);
      if (item != null) {
        result.add(item);
      }
    }
    return result;
  }

  /// 社区页（上传/收藏）的横排卡片。
  static List<R34CommunityVideo> parseDocToVideo(
    ParseType parseType, {
    String? body,
    dom.Document? doc,
  }) {
    final document = doc ?? parser.parse(body ?? '');
    final parent = document.getElementById(parseType.parseId);
    if (parent == null) {
      LogUtil.warn('parse community videos: container not found');
      return const [];
    }

    final result = <R34CommunityVideo>[];
    for (final anchor in parent.querySelectorAll('a.th')) {
      final item = _parseCommunityItem(anchor);
      if (item != null) {
        result.add(item);
      }
    }
    return result;
  }

  static R34CommunityVideo? _parseCommunityItem(dom.Element anchor) {
    final detailUrl = anchor.attributes['href'];
    if (detailUrl == null || detailUrl.isEmpty) {
      return null;
    }

    final img = anchor.querySelector('img.thumb');
    final thumbImageUrl = img?.attributes['data-webp'] ??
        img?.attributes['data-original'] ??
        img?.attributes['src'] ??
        '';

    // 广告卡片（Advertisement）没有封面图，跳过，避免点进详情页后出错。
    if (thumbImageUrl.isEmpty) {
      return null;
    }

    final ratingInfo = anchor.querySelector('div.rating')?.text.trim() ?? '';
    final match = _ratingInfoReg.firstMatch(ratingInfo);

    return R34CommunityVideo(
      title: anchor.attributes['title']?.trim() ??
          (anchor.querySelector('.thumb_title')?.text.trim() ?? '未知标题'),
      detailUrl: detailUrl,
      thumbImageUrl: thumbImageUrl,
      duration: anchor.querySelector('div.time')?.text.trim() ?? '',
      viewCount: _viewCountOf(anchor),
      rating: match?.group(1) != null ? '${match!.group(1)}%' : '',
      ratingCount: match?.group(2) ?? '',
      uploadTime: anchor.querySelector('div.added')?.text.trim() ?? '',
    );
  }

  /// 播放量。
  ///
  /// 站点把评论数放在 `.video-comments-count`、播放量放在 `.video-views-count`，
  /// 两者 class 里都有 `views`，早期直接取 `div.views` 会取到评论数。
  static String _viewCountOf(dom.Element anchor) {
    final views = anchor.querySelector('.video-views-count') ??
        anchor.querySelector('.views:not(.video-comments-count)');
    if (views != null) {
      final title = views.attributes['title'] ?? '';
      final match = RegExp(r'Views:\s*(.+)').firstMatch(title);
      if (match != null) {
        return match.group(1)!.trim();
      }
      return views.text.trim();
    }
    return '';
  }

  /// 把 `1:02:03` / `12:34` 解析成秒，解析不出来返回 null。
  static int? durationToSeconds(String duration) {
    final match = _durationReg.firstMatch(duration.trim());
    if (match == null) {
      return null;
    }
    final first = int.tryParse(match.group(1)!) ?? 0;
    final second = int.tryParse(match.group(2)!) ?? 0;
    final third = match.group(3) == null ? null : int.tryParse(match.group(3)!);
    if (third == null) {
      return first * 60 + second;
    }
    return first * 3600 + second * 60 + third;
  }
}
