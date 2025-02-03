import 'dart:convert';
import 'dart:developer';

import 'package:r34_video/page/search_edit_page.dart';
import 'package:r34_video/repo/r34_search_edit_repo.dart';

void main() async {
  final trendingData = await R34SearchEditRepo.getTrendingData();
  final jsonObj = {
    'item1': trendingData.item1.map((e) => e.toJson()).toList(),
    'item2': trendingData.item2.map((e) => e.toJson()).toList(),
    'item3': trendingData.item3.map((e) => e.toJson()).toList(),
  };
  log(jsonEncode(jsonObj));
}
