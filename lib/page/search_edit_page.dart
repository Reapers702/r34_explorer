import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/component/video_tag_chip.dart';
import 'package:r34_video/page/search_result_page.dart';
import 'package:r34_video/provider/search_edit_provider.dart';
import 'package:r34_video/util/toast_util.dart';

class SearchEditPage extends StatefulWidget {
  const SearchEditPage({super.key});

  @override
  State<SearchEditPage> createState() => _SearchEditPageState();
}

class _SearchEditPageState extends State<SearchEditPage> {
  final TextEditingController _searchController = TextEditingController();

  void _submitSearch(SearchEditProvider provider) {
    final searchText = _searchController.text;
    if (searchText.isEmpty) {
      ToastUtil.showToast('请输入合法内容');
    }

    log('search text: $searchText');
    Navigator.of(context).pushNamed(
      PageRoutes.searchResultPage,
      arguments: SearchResultPageArg(searchText),
    );

    provider.addSearchHistory(searchText);
  }

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
                    _submitSearch(editProvider);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () => _submitSearch(editProvider),
                child: Text(
                  "搜索",
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
              ),
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
                    .map((e) => VideoSearchHistoryChip(
                          e,
                          onDelete: () {
                            editProvider.removeSearchHistory(e);
                          },
                        ))
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
}
