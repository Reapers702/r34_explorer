import 'package:r34_video/repo/cookie_store.dart';

const String kR34BaseUrl = 'https://rule34video.com';

class R34Const {
  static const host = 'rule34video.com';

  static const baseUrl = kR34BaseUrl;

  static const websiteIcon = '$kR34BaseUrl/apple-touch-icon.png';

  /// 静态请求头。
  ///
  /// 注意：这里**不再包含 cookie**。cookie 由 `CookieStore` 统一管理、
  /// 由 `R34Client` 注入 —— 早期把一份 2025 年的 cookie 写死在这里，
  /// 站点侧一失效整个 App 就全线请求失败。
  ///
  /// 也不要给这个 Map 加 cookie 键，请走 `R34Headers.build()`。
  static const Map<String, String> headers = {
    'accept': '*/*',
    'accept-language': 'zh-CN,zh;q=0.9',
    'priority': 'u=1, i',
    'referer': '$kR34BaseUrl/',
    'sec-ch-ua':
        '"Not A(Brand";v="8", "Chromium";v="132", "Microsoft Edge";v="132"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-origin',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36 Edg/132.0.0.0',
    'x-requested-with': 'XMLHttpRequest',
  };
}

/// 请求头构建。
class R34Headers {
  const R34Headers._();

  /// 合并静态头与当前 cookie。
  static Map<String, String> build() {
    final result = Map<String, String>.of(R34Const.headers);
    if (CookieStore.hasCookies) {
      result['cookie'] = CookieStore.toHeaderValue();
    }
    return result;
  }
}
