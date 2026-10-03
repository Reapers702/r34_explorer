import 'package:http/http.dart' as http;
import 'package:r34_video/repo/r34_client.dart';
import 'package:r34_video/util/http_trace_util.dart';

class HttpUtil {
  /// 解析 `get_file` 的重定向目标。
  ///
  /// `followRedirects = false`，所以走 [R34Client.send] 直接拿 302 的 location。
  static Future<String?> redirectUrl(String url) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.followRedirects = false;

      final res = await R34Client.instance.send(request);
      final location = res.headers['location'];
      return (res.statusCode == 301 || res.statusCode == 302) &&
              location != null &&
              location.isNotEmpty
          ? location
          : null;
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return null;
    }
  }
}
