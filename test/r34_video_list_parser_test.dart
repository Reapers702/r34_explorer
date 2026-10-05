import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:r34_video/util/r34_video_list_parser.dart';

/// 浏览历史页卡片样本（`/my/history/` 整页内 `list_videos_my_watch_history_items`
/// 容器，DOM 与原始页面一致）。
const _watchHistoryBody = '''
<html><body>
  <div id="list_videos_my_watch_history_items">
    <div class="item thumb video_1 watched">
      <a class="th js-open-popup" href="https://rule34video.com/video/3143712/rainy/" title="Rainy">
        <div class="img wrap_image" data-preview="https://rule34video.com/get_file/58/preview.mp4/">
          <img class="thumb lazy-load" src="https://rule34video.com/contents/screenshots/1.jpg" data-webp="https://rule34video.com/contents/screenshots/1.webp">
        </div>
        <div class="time">1:02:03</div>
      </a>
    </div>
    <div class="item thumb watched">
      <a class="th js-open-popup" href="https://rule34video.com/video/999/test/" title="Test Video">
        <div class="img wrap_image">
          <img class="thumb lazy-load" src="https://rule34video.com/contents/screenshots/2.jpg">
        </div>
        <div class="time">12:34</div>
      </a>
    </div>
  </div>
</body></html>
''';

/// [R34VideoListParser.parseDocToVideo] 的单元测试。
///
/// 早期只有 首页/上传/收藏 三种 ParseType。新增云端浏览历史后，
/// watchHistory 复用同一套卡片解析，这里验证容器 id 映射正确。
void main() {
  group('parsePageCount', () {
    test('搜索结果分页：02/03/…/Last(424)，应返回 424 而不是 2', () {
      final doc = parser.parse('''
        <div class="pagination" id="custom_list_videos_videos_list_search_pagination">
          <div class="item active"><a href="#search" data-parameters="q:resident%20evil;sort_by:;from_videos+from_albums:01">01</a></div>
          <div class="item"><a href="#search" data-parameters="q:resident%20evil;sort_by:;from_videos+from_albums:02">02</a></div>
          <div class="item"><a href="#search" data-parameters="q:resident%20evil;sort_by:;from_videos+from_albums:03">03</a></div>
          <div class="item"><a href="#search" data-parameters="q:resident%20evil;sort_by:;from_videos+from_albums:424">Last</a></div>
        </div>
      ''');
      expect(
        R34VideoListParser.parsePageCount(doc, ParseType.searchKeyword),
        424,
      );
    });

    test('搜索结果分页带省略号：01…Last(424)，仍应返回 424', () {
      final doc = parser.parse('''
        <div class="pagination" id="custom_list_videos_videos_list_search_pagination">
          <div class="item active"><a data-parameters="q:x;from_videos+from_albums:01">01</a></div>
          <div class="item"><a data-parameters="q:x;from_videos+from_albums:02">02</a></div>
          <div class="item"><a data-parameters="q:x;from_videos+from_albums:10">...</a></div>
          <div class="item"><a data-parameters="q:x;from_videos+from_albums:424">Last</a></div>
        </div>
      ''');
      expect(
        R34VideoListParser.parsePageCount(doc, ParseType.searchKeyword),
        424,
      );
    });

    test('首页分页：01-09…Last(14305)，应返回 14305', () {
      final doc = parser.parse('''
        <div class="pagination" id="custom_list_videos_most_recent_videos_pagination">
          <div class="item active"><a href="https://rule34video.com/latest-updates" data-parameters="sort_by:post_date;from:01">01</a></div>
          <div class="item"><a href="https://rule34video.com/latest-updates/2/" data-parameters="sort_by:post_date;from:02">02</a></div>
          <div class="item"><a href="https://rule34video.com/latest-updates/3/" data-parameters="sort_by:post_date;from:03">03</a></div>
          <div class="item"><a href="https://rule34video.com/latest-updates/9/" data-parameters="sort_by:post_date;from:09">09</a></div>
          <div class="item"><a href="https://rule34video.com/latest-updates/10/" data-parameters="sort_by:post_date;from:10">...</a></div>
          <div class="item"><a href="https://rule34video.com/latest-updates/14305/" data-parameters="sort_by:post_date;from:14305">Last</a></div>
        </div>
      ''');
      expect(
        R34VideoListParser.parsePageCount(doc, ParseType.homepage),
        14305,
      );
    });

    test('只有当前页 01：应返回 1', () {
      final doc = parser.parse('''
        <div class="pagination" id="custom_list_videos_common_videos_pagination">
          <div class="item active"><a data-parameters="from:01">01</a></div>
        </div>
      ''');
      expect(
        R34VideoListParser.parsePageCount(doc, ParseType.searchCommon),
        1,
      );
    });

    test('没有分页容器：应返回 1', () {
      final doc = parser.parse('<html><body>empty</body></html>');
      expect(
        R34VideoListParser.parsePageCount(doc, ParseType.related),
        1,
      );
    });
  });

  group('parseDocToVideo watchHistory', () {
    test('应解析出浏览历史的两张卡片，并复用卡片字段', () {
      final videos = R34VideoListParser.parseDocToVideo(
        ParseType.watchHistory,
        body: _watchHistoryBody,
      );

      expect(videos, hasLength(2));
      expect(videos[0].title, 'Rainy');
      expect(
        videos[0].detailUrl,
        'https://rule34video.com/video/3143712/rainy/',
      );
      expect(
        videos[0].thumbImageUrl,
        'https://rule34video.com/contents/screenshots/1.webp',
      );
      expect(videos[0].duration, '1:02:03');
      expect(videos[1].title, 'Test Video');
      expect(videos[1].duration, '12:34');
    });

    test('容器不存在：应返回空列表', () {
      final videos = R34VideoListParser.parseDocToVideo(
        ParseType.watchHistory,
        body: '<html><body><div/></body></html>',
      );
      expect(videos, isEmpty);
    });
  });
}
