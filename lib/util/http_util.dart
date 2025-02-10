import 'package:http/http.dart' as http;
import 'package:r34_video/constant/r34_const.dart';
import 'package:r34_video/util/http_trace_util.dart';

class HttpUtil {
  static final client = http.Client();

  static Future<String?> redirectUrl(String url) async {
    try {
      var request = http.Request('GET', Uri.parse(url));
      for (var e in R34Const.headers.entries) {
        request.headers[e.key] = e.value;
      }
      request.followRedirects = false;

      final res = await client.send(request).timeout(Duration(seconds: 10));
      return res.isRedirect ? res.headers['location']! : null;
    } catch (e, st) {
      HttpTraceUtil.handleConnectionError(e, st: st);
      return null;
    }
  }
}
