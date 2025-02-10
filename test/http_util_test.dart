import 'dart:developer';

import 'package:r34_video/util/http_util.dart';

void main() async {
  final redirect = await HttpUtil.redirectUrl(
      'https://rule34video.com/get_file/51/fae8e5f0c6385d8081af964734e6b6e144c71a2c8f/3063000/3063695/3063695_720p.mp4/?br=1117');
  log(redirect ?? 'null');
}
