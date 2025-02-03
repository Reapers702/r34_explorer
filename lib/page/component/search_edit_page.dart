import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/page/component/video_tag_chip.dart';
import 'package:r34_video/provider/search_edit_provider.dart';
import 'package:r34_video/repo/entity/r34_video_info.dart';

class SearchEditPage extends StatefulWidget {
  const SearchEditPage({super.key});

  @override
  State<SearchEditPage> createState() => _SearchEditPageState();
}

class _SearchEditPageState extends State<SearchEditPage> {
  final TextEditingController _searchController =
      TextEditingController(text: 'hello');

  List<String> _bilibiliHotSearch = [
    "圆脸谈外网疯传假…",
    "大鱼海棠2预告",
    "樊振东获世界杯参…",
    "学生一张嘴出卖了…",
    "东契奇因加盟湖人…",
    "婚礼变葬礼美女扮…",
    "哪吒2鹿童配音回应被…",
    "SM新女团首个出…",
    "英伟达市值1周缩水超…",
    "Kanye唯一关注Taylor…"
  ];

  List<String> _searchHistory = [
    "游戏王YGO",
    "游戏王YGOPRO",
    "灰流丽",
    "咱们单位原来有…",
    "我记着咱们公司…"
  ];

  @override
  Widget build(BuildContext context) {
    final editProvider = context.watch<SearchEditProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey,
        shadowColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  decoration: InputDecoration(
                    hintText: "搜点东西试试",
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        EdgeInsets.only(left: 0, right: 10, bottom: 12.5),
                  ),
                  onSubmitted: (value) {
                    log('text field submit $value');
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              "搜索",
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "搜索历史",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: editProvider
                    .getSearchHistory()
                    .map((e) => VideoSearchHistoryChip(e))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "热搜分类",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: editProvider
                    .getTrendingCategories()
                    .map((e) => VideoCategoryChip(e, showAvatar: true))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "热搜创作者",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: editProvider
                    .getTrendingArtists()
                    .map((e) => VideoArtistChip(e, showAvatar: true))
                    .toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                "热搜 Tag",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: editProvider
                    .getTrendingTags()
                    .map((e) => VideoTagChip(e))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isHotSearch(String search) {
    List<String> hotKeywords = ["热", "新", "牧"];
    return hotKeywords.any((keyword) => search.contains(keyword));
  }
}
