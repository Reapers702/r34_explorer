import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/constant/search_option.dart';
import 'package:r34_video/page/component/home_page_bottom_sheet.dart';
import 'package:r34_video/page/component/underlined_text.dart';
import 'package:r34_video/page/component/video_thumb.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/r34_home_page_repo.dart';
import 'package:r34_video/util/toast_util.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  final PageController _pageController = PageController();
  PersistentBottomSheetController? _bottomSheetController;
  final ScrollController _scrollController = ScrollController();

  R34HomeFilterOption currSearchOption = R34HomeFilterOption();
  R34HomeFilterOption? lastSearchOption;

  R34Page _r34page = R34Page(videos: [], pageCount: 0);
  Map<int, List<R34Video>> _r34VideoPageMap = {};
  int _pageCount = 1;
  int _currPage = 1;
  bool _loading = true;

  Future<void> _onOptionUpdate() async {
    if (currSearchOption.filterEquals(lastSearchOption)) {
      ToastUtil.showToast('筛选条件没有变化噢');
      return;
    }

    if (_r34VideoPageMap.isNotEmpty) {
      setState(() {
        _currPage = 1;
        _pageCount = 1;
        _r34VideoPageMap = {};
        currSearchOption.page = 1;
      });
    } else {
      _currPage = 1;
      _pageCount = 1;
      _r34VideoPageMap = {};
      currSearchOption.page = 1;
    }

    final page = await _loadData(force: true);
    if (page != null) {
      setState(() {
        _pageCount = page.pageCount;
      });
    }
  }

  void _onPageUpdate(int newPageNum) {
    log('currOption: $currSearchOption');
    log('lastOption: $lastSearchOption');
    if (_r34VideoPageMap.containsKey(newPageNum)) {
      setState(() {});
    }
    if (_currPage == newPageNum &&
        currSearchOption.filterEquals(lastSearchOption)) {
      ToastUtil.showToast('页码没变 怎么回事呢');
      return;
    }

    _currPage = newPageNum;
    currSearchOption.page = _currPage;
    _loadData(force: false).then((page) {
      if (page != null) {
        setState(() {});
      }
    });
  }

  Future<R34Page?> _loadData({bool force = false}) async {
    if (currSearchOption.equals(lastSearchOption) && !force) {
      ToastUtil.showToast('搜索条件没有变化噢');
      return null;
    }

    try {
      _loading = true;

      lastSearchOption = currSearchOption.duplicate();
      log(currSearchOption.toString());
      _r34page = await R34HomePageRepo.getPage(currSearchOption);

      _loading = false;
      _r34VideoPageMap[currSearchOption.page] = _r34page.videos;
      return _r34page;
    } catch (e) {
      log('Error: $e');
      _loading = false;
      ToastUtil.showToast('Search failed, please contact the developer');
      return null;
    }
  }

  void _showBottomSheet() {
    if (_bottomSheetController == null) {
      _bottomSheetController = scaffoldKey.currentState?.showBottomSheet(
        (context) => HomePageBottomSheet(
          onOptionConfirm: (dateAdded, duration) {
            currSearchOption.dateAdded = dateAdded;
            currSearchOption.duration = duration;
            _onOptionUpdate();
          },
          defaultDateAdded: currSearchOption.dateAdded,
          defaultDuration: currSearchOption.duration,
        ),
        backgroundColor: Colors.transparent,
        enableDrag: false,
      );
      _bottomSheetController!.closed
          .then((value) => _bottomSheetController = null);
    } else {
      _bottomSheetController!.close();
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
                  _pageController.jumpToPage(newPageNum.toInt());
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
  void initState() {
    super.initState();

    // _pageController.addListener(() {
    //   final newPageNum = _pageController.page!.toInt();
    //   _onPageUpdate(newPageNum);
    // });
    _onOptionUpdate();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final contextPadding = MediaQuery.of(context).viewPadding;

    return Scaffold(
      key: scaffoldKey,
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  toolbarHeight: contextPadding.top,
                  expandedHeight: contextPadding.top + 50,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          Container(
                            height: contextPadding.top,
                            color: Colors.white,
                          ),
                          SizedBox(
                            height: 40,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Spacer(flex: 1),
                                Flexible(
                                  flex: 4,
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl:
                                          'https://pic.ibaotu.com/21/05/25/paixin/pki80515.jpg!ww7002',
                                      fit: BoxFit.cover,
                                      width: 30,
                                      height: 30,
                                    ),
                                  ),
                                ),
                                Spacer(flex: 2),
                                Expanded(
                                    flex: 14,
                                    child: GestureDetector(
                                      onTap: () {
                                        log('come to search something');
                                        Navigator.of(context).pushNamed(
                                            PageRoutes.searchEditPage);
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          '来搜点什么吧',
                                          style: TextStyle(
                                            color: Colors.black54,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    )),
                                Spacer(flex: 2),
                                Flexible(
                                  flex: 4,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.last_page),
                                    onPressed: _showPageSwitcher,
                                  ),
                                ),
                                Flexible(
                                  flex: 4,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.filter_list_alt),
                                    onPressed: () => _showBottomSheet(),
                                  ),
                                ),
                                Spacer(flex: 1),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverAppBar(
                  title: UnderlinedTextGroup<HomeSortEnum>(
                    HomeSortEnum.descriptionMap,
                    onSelect: (sortEnum) {
                      log('try to update? $sortEnum');
                      currSearchOption.sortType = sortEnum;
                      _onOptionUpdate();
                    },
                  ),
                  pinned: true,
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  automaticallyImplyLeading: false,
                  toolbarHeight: 30,
                ),
              ];
            },
            body: _buildVideoContent(context)),
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
        log('page change $index');

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

  @override
  bool get wantKeepAlive => true;
}
