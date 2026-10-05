import 'package:r34_video/repo/r34_video_detail_repo.dart';
import 'package:flutter_test/flutter_test.dart';

/// red: 直接从 html_parser 网络解析不可测，但当前测试走内部 _parse 分支。
///
/// 通过一个可被替换的入口测试 playUrls 解析。这里用浏览器实测得到的真实
/// flashvars 形态（video_url / video_alt_url* 为完整直链）驱动解析。
void main() {
  group('R34VideoDetailRepo playUrls 解析', () {
    test('从真实 flashvars 直链解析出各清晰度（含 360.mp4 无 p 后缀）', () {
      final info = R34VideoDetailRepo.parseForTest(_fixtureHtml);
      expect(info, isNotNull);
      // 360 形如 ..._360.mp4，480/720 形如 ..._480p.mp4，键统一带 p 后缀
      expect(info!.playUrls.containsKey('360p'), isTrue, reason: '应解析出 360p');
      expect(info.playUrls.containsKey('480p'), isTrue, reason: '应解析出 480p');
      expect(info.playUrls.containsKey('720p'), isTrue, reason: '应解析出 720p');
      // 直链应保留完整（含 v-acctoken 鉴权参数），不再是 function/0/ 形态
      expect(info.playUrls['480p'],
          contains('v-acctoken'), reason: '直链应保留鉴权参数');
      expect(info.playUrls['480p'],
          startsWith('https://'), reason: '直链应是以 https 开头的完整地址');
    });

    test('下载链接仍独立解析，不混入 playUrls', () {
      final info = R34VideoDetailRepo.parseForTest(_fixtureHtml);
      expect(info!.downloadUrls.length, greaterThanOrEqualTo(2));
      expect(
        info.downloadUrls['MP4 720p'],
        isNotNull,
        reason: '下载链接仍按分辨率 key 解析',
      );
      // 下载链接带 download 标记，与播放直链（playUrls）分开
      final play720 = info.playUrls['720p'];
      final dl720 = info.downloadUrls['MP4 720p'];
      expect(play720, isNotNull);
      expect(dl720!, isNot(play720), reason: '播放直链与下载链接不应被混为一谈');
    });
  });
}

/// 精简自浏览器实测的 rule34video 详情页 HTML（仅保留解析所需节点）。
const String _fixtureHtml = '''
<html>
<body>
  <script>
    var flashvars = {
        video_id: '3143712',
        video_title: 'Rainy Day [Lewdfroggo]',
        video_url: 'https://rule34video.com/get_file/58/bcd9e49661427d1c95faa032c79d1d0a/3143000/3143712/3143712_360.mp4/?v-acctoken=x1',
        video_url_text: '360p',
        video_alt_url: 'https://rule34video.com/get_file/58/43742f3424ae334ad3b893845e7f9fec/3143000/3143712/3143712_480p.mp4/?v-acctoken=x2',
        video_alt_url_text: '480p',
        video_alt_url2: 'https://rule34video.com/get_file/58/8167e985a0311c7cd028327d4e831dee/3143000/3143712/3143712_720p.mp4/?v-acctoken=x3',
        video_alt_url2_text: '720p'
    };
  </script>
  <script>kt_player('kt_player');</script>
  <h1 class="title_video">Rainy Day [Lewdfroggo]</h1>
  <div id="tab_video_info">
    <div><div class="label">Download</div>
      <a class="tag_item" href="https://rule34video.com/get_file/58/8167e985a0311c7cd028327d4e831dee/3143000/3143712/3143712_720p.mp4/?v-acctoken=dl360&amp;download=true">MP4 720p</a>
      <a class="tag_item" href="https://rule34video.com/get_file/58/3b61f5b4c2d9974c5f60cc9cfed01d31/3143000/3143712/3143712_1080p.mp4/?v-acctoken=dl1080&amp;download=true">MP4 1080p</a>
    </div>
  </div>
</body>
</html>
''';