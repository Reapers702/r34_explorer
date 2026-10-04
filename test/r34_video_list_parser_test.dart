import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as parser;
import 'package:r34_video/util/r34_video_list_parser.dart';

/// [R34VideoListParser.parsePageCount] 的单元测试。
///
/// 站点每个分页链接都带 `data-parameters`（如 `from_videos+from_albums:02`），
/// 且结果页的链接顺序是 01、02、03…、Last。早期实现遇到第二个链接
/// （数字 02 > 1）就提前 break，导致任何搜索都只显示 2 页 —— 这里用
/// 真实抓到的 DOM 形态做回归。
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
}
