import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:r34_video/constant/search_option.dart';
import 'package:r34_video/page/component/underlined_text.dart';
import 'package:r34_video/page/component/video_thumb.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_search_request.dart';
import 'package:r34_video/repo/r34_search_repo.dart';
import 'package:r34_video/util/toast_util.dart';

class SearchResultPageArg {
  final String rawText;
  late String searchText;
  late SearchKeywordType keywordType;
  SearchResultPageArg(this.rawText) {
    if (rawText.startsWith('t:')) {
      searchText = rawText.substring(2);
      keywordType = SearchKeywordType.tag;
    } else if (rawText.startsWith('c:')) {
      searchText = rawText.substring(2);
      keywordType = SearchKeywordType.category;
    } else if (rawText.startsWith('a:')) {
      searchText = rawText.substring(2);
      keywordType = SearchKeywordType.artist;
    } else {
      searchText = rawText;
      keywordType = SearchKeywordType.keyword;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'searchText': searchText,
      'keywordType': keywordType.name,
    };
  }
}

class SearchResultPage extends StatefulWidget {
  const SearchResultPage({super.key});

  @override
  State<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends State<SearchResultPage> {
  SearchResultPageArg? arg;

  final PageController _pageController = PageController();

  bool _loading = true;
  late final R34SearchRequest _currSearch;
  R34SearchRequest? _lastSearch;
  int _currPage = 1;
  int _pageCount = 1;
  Map<int, List<R34Video>> _r34VideoPageMap = {};

  Future<void> _onOptionUpdate() async {
    if (_currSearch.equals(_lastSearch, ignorePage: true)) {
      ToastUtil.showToast('筛选条件没有变化噢');
      return;
    }

    if (_r34VideoPageMap.isNotEmpty) {
      setState(() {
        _currPage = 1;
        _pageCount = 1;
        _r34VideoPageMap = {};
        _currSearch.page = 1;
      });
    } else {
      _currPage = 1;
      _pageCount = 1;
      _r34VideoPageMap = {};
      _currSearch.page = 1;
    }

    final page = await _loadData();
    if (page != null) {
      setState(() {
        _pageCount = page.pageCount;
      });
    }
  }

  void _onPageUpdate(int newPageNum) {
    log('currOption: $_currSearch');
    log('lastOption: $_lastSearch');
    if (_r34VideoPageMap.containsKey(newPageNum)) {
      return;
    }

    _currPage = newPageNum;
    _currSearch.page = _currPage;
    _loadData().then((page) {
      if (page != null) {
        setState(() {});
      }
    });
  }

  Future<R34Page?> _loadData() async {
    if (_currSearch.equals(_lastSearch)) {
      ToastUtil.showToast('搜索条件没有变化噢');
      return null;
    }

    try {
      _loading = true;
      _lastSearch = _currSearch.duplicate();
      final r34page = await R34SearchRepo.searchResult(_currSearch);
      _r34VideoPageMap[_currSearch.page] = r34page.videos;
      return r34page;
    } catch (e) {
      log('Error: $e');
      ToastUtil.showToast('Search failed, please contact the developer');
      return null;
    } finally {
      _loading = false;
    }
  }

  void _showPageSwitcher() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) {
        TextEditingController textController = TextEditingController();
        return AlertDialog(
          title: Text('请输入页数'),
          content: Column(
            mainAxisSize: MainAxisSize.min, // 使对话框高度适应内容
            children: <Widget>[
              SizedBox(height: 10), // 添加一些间距
              TextField(
                controller: textController,
                keyboardType: TextInputType.number, // 限制输入为数字
                decoration: InputDecoration(
                  hintText: '1 - $_pageCount',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('确定'),
              onPressed: () {
                final newPageNum = num.tryParse(textController.text);
                if (newPageNum != null &&
                    newPageNum > 0 &&
                    newPageNum <= _pageCount) {
                  Navigator.of(context).pop();
                  _pageController.jumpToPage(newPageNum.toInt() - 1);
                } else {
                  ToastUtil.showToast('请输入有效页码');
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (arg == null) {
      arg = ModalRoute.of(context)!.settings.arguments! as SearchResultPageArg;
      _currSearch = R34SearchRequest(
        keywordType: arg!.keywordType,
        keyword: arg!.searchText,
        sortType: HomeSortEnum.mostRelevant,
        page: 1,
      );
      _onOptionUpdate();
    }

    log('search result page arg: ${jsonEncode(arg!.toJson())}');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey,
        shadowColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    enabled: false,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    decoration: InputDecoration(
                      hintText: arg!.rawText,
                      prefixIcon: Icon(Icons.search),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding:
                          EdgeInsets.only(left: 0, right: 10, bottom: 12.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40,
              alignment: Alignment.center,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(Icons.last_page),
                onPressed: _showPageSwitcher,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: UnderlinedTextGroup<HomeSortEnum>(
              arg!.keywordType == SearchKeywordType.keyword
                  ? HomeSortEnum.descriptionMapWithSearch
                  : HomeSortEnum.descriptionMap,
              onSelect: (sortEnum) {
                log('try to update? $sortEnum');
                _currSearch.sortType = sortEnum;
                _onOptionUpdate();
              },
            ),
          ),
          Expanded(child: _buildVideoContent(context)),
        ],
      ),
    );
  }

  Widget _buildVideoContent(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return PageView.builder(
      controller: _pageController,
      itemCount: _pageCount,
      itemBuilder: (context, index) {
        index += 1;
        log('page change source: ${index - 1} target: $index');

        final r34Videos = _r34VideoPageMap[index] ?? [];
        if (r34Videos.isEmpty && !_loading) {
          _onPageUpdate(index);
        }

        if (r34Videos.isEmpty && _loading) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.shade800,
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: Offset(0, 100)),
              ],
            ),
            padding: EdgeInsets.only(
              top: 10,
              left: screenSize.width * 0.02,
              right: screenSize.width * 0.02,
            ),
            child: ListView.separated(
              itemCount: 8,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VideoThumb.fromLoading(),
                    SizedBox(width: screenSize.width * 0.02),
                    VideoThumb.fromLoading(),
                  ],
                );
              },
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            log('refresh triggered');
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade800,
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: Offset(0, 100),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              top: 10,
              left: screenSize.width * 0.02,
              right: screenSize.width * 0.02,
            ),
            child: ListView.separated(
              itemCount: (r34Videos.length / 2 + 0.5).toInt(),
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                R34Video left = r34Videos[index * 2];
                R34Video? right = r34Videos.elementAtOrNull(index * 2 + 1);

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    VideoThumb(left),
                    SizedBox(width: screenSize.width * 0.02),
                    right == null
                        ? SizedBox(width: screenSize.width * 0.47)
                        : VideoThumb(right),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
