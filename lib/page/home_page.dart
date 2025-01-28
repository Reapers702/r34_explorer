import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:r34_video/constant/search_option.dart';
import 'package:r34_video/page/component/page_search_bottom_sheet.dart';
import 'package:r34_video/page/component/underlined_text.dart';
import 'package:r34_video/page/component/video_thumb.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/r34_repo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  PersistentBottomSheetController? _bottomSheetController;
  final ScrollController _scrollController = ScrollController();

  List<R34Video> _r34Videos = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {});
    _loadData(R34SearchOption());
  }

  Future<void> _loadData(R34SearchOption option) async {
    try {
      final newR34Page = await R34Repo.getPage(option);
      setState(() {
        _r34Videos = newR34Page.videos;
      });
    } catch (e) {
      log('Error: $e');
    }
  }

  void _showBottomSheet() {
    if (_bottomSheetController == null) {
      _bottomSheetController = scaffoldKey.currentState?.showBottomSheet(
        (context) => PageSearchBottomSheet(
          onSearch: (p0) => _loadData(p0),
        ),
        backgroundColor: Colors.purple.shade50,
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
    final screenSize = MediaQuery.of(context).size;

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
                        SizedBox(height: contextPadding.top),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Spacer(flex: 1),
                            Flexible(
                              flex: 2,
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
                                icon: Icon(Icons.filter_list_alt),
                                onPressed: () => _showBottomSheet(),
                              ),
                            ),
                            Spacer(flex: 1),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverAppBar(
                title: UnderlinedTextGroup<HomeSortEnum>(
                  HomeSortEnum.descriptionMap,
                  onSelect: (p0) {},
                ),
                pinned: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                automaticallyImplyLeading: false,
                toolbarHeight: 30,
              ),
            ];
          },
          body: RefreshIndicator(
            onRefresh: () => _loadData(R34SearchOption()),
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
              padding: EdgeInsets.symmetric(
                  vertical: 10, horizontal: screenSize.width * 0.02),
              child: ListView.separated(
                itemCount: (_r34Videos.length / 2 + 0.5).toInt(),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
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
          ),
        ),
      ),
    );
  }
}
