import 'dart:convert';
import 'dart:developer' as dev;
import 'package:r34_video/repo/r34_video_detail_repo.dart';

void main() async {
  final videoInfo = await R34VideoDetailRepo.getVideoInfo(
      'https://rule34video.com/video/3460479/jenny-s-odd-adventure-5-slipperyt/');
  dev.log(jsonEncode(videoInfo!.toJson()));
}
