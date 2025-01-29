import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:r34_video/constant/search_option.dart';
import 'package:r34_video/page/component/home_page_bottom_sheet.dart';
import 'package:r34_video/page/component/underlined_text.dart';
import 'package:r34_video/page/component/video_thumb.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/r34_repo.dart';
import 'package:r34_video/util/toast_util.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  PersistentBottomSheetController? _bottomSheetController;
  final ScrollController _scrollController = ScrollController();

  R34SearchOption currSearchOption = R34SearchOption();
  R34SearchOption? lastSearchOption;

  R34Page _r34page = R34Page(videos: [], pageCount: 0);
  List<R34Video> _r34Videos = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool force = false}) async {
    if (lastSearchOption == currSearchOption && !force) {
      ToastUtil.showToast('搜索条件没有变化噢');
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      lastSearchOption = currSearchOption.duplicate();
      log(currSearchOption.toString());
      _r34page = await R34Repo.getPage(currSearchOption);
      setState(() {
        _loading = false;
        _r34Videos = _r34page.videos;
        log('loading finish');
      });
    } catch (e) {
      log('Error: $e');
      setState(() {
        _loading = false;
      });
      log('loading finish with error');
    }
  }

  void _showBottomSheet() {
    if (_bottomSheetController == null) {
      _bottomSheetController = scaffoldKey.currentState?.showBottomSheet(
        (context) => HomePageBottomSheet(
          onOptionConfirm: (dateAdded, duration) {
            currSearchOption.dateAdded = dateAdded;
            currSearchOption.duration = duration;
          },
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

  @override
  Widget build(BuildContext context) {
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
                                Spacer(flex: 20),
                                Flexible(
                                  flex: 4,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.last_page),
                                    onPressed: () {
                                      showDialog(
                                        barrierDismissible: false,
                                        context: context,
                                        builder: (context) {
                                          TextEditingController textController =
                                              TextEditingController();
                                          return AlertDialog(
                                            title: Text('请输入页数'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize
                                                  .min, // 使对话框高度适应内容
                                              children: <Widget>[
                                                SizedBox(height: 10), // 添加一些间距
                                                TextField(
                                                  controller: textController,
                                                  keyboardType: TextInputType
                                                      .number, // 限制输入为数字
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        '0 - ${_r34page.pageCount}',
                                                    border:
                                                        OutlineInputBorder(),
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
                                                  final newPageNum =
                                                      num.tryParse(
                                                          textController.text);
                                                  if (newPageNum != null &&
                                                      newPageNum > 0 &&
                                                      newPageNum <=
                                                          _r34page.pageCount) {
                                                    Navigator.of(context).pop();
                                                    currSearchOption.page =
                                                        newPageNum.toInt();
                                                    _loadData();
                                                  } else {
                                                    ToastUtil.showToast(
                                                        '请输入有效页码');
                                                  }
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
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
                      _loadData();
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
    if (_loading) {
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
      onRefresh: () => _loadData(),
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
          itemCount: (_r34Videos.length / 2 + 0.5).toInt(),
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            R34Video left = _r34Videos[index * 2];
            R34Video? right = _r34Videos.elementAtOrNull(index * 2 + 1);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VideoThumb(left),
                SizedBox(width: screenSize.width * 0.02),
                right == null
                    ? SizedBox(width: screenSize.width * 0.4)
                    : VideoThumb(right),
              ],
            );
          },
        ),
      ),
    );
  }
}
