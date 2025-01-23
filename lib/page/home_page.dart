import 'dart:developer';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drag_bottom_sheet/entity/data.dart';
import 'package:drag_bottom_sheet/page/component/page_search_bottom_sheet.dart';
import 'package:drag_bottom_sheet/repo/data_repo.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Data> _data = [];
  PersistentBottomSheetController? _bottomSheetController;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  void _loadData(SearchOption option) async {
    try {
      final dataList = await DataRepo.getDataList(option);
      setState(() {
        _data = dataList;
      });
    } catch (e) {
      log('Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData(SearchOption());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Flutter Demo Home Page'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              onPressed: () {
                log('switch filter');
                if (_bottomSheetController == null) {
                  _bottomSheetController =
                      scaffoldKey.currentState?.showBottomSheet(
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
              },
              icon: const Icon(Icons.filter_alt))
        ],
      ),
      body: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: ListView.separated(
          itemCount: _data.length ~/ 2,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            int actualIndex = index * 2;
            Data left = _data[actualIndex];
            Data? right =
                _data.length > actualIndex + 1 ? _data[actualIndex + 1] : null;
            double maxWidth = MediaQuery.of(context).size.width / 3;
            double maxHeight = maxWidth * 9 / 16;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    CachedNetworkImage(
                        imageUrl: left.imageUrl,
                        width: maxWidth,
                        height: maxHeight,
                        fit: BoxFit.fill,
                        progressIndicatorBuilder: (context, url, progress) =>
                            Center(
                              child: CircularProgressIndicator(
                                  value: progress.progress),
                            )),
                    SizedBox(
                      width: maxWidth,
                      child: Text(left.name,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                SizedBox(width: maxWidth / 3),
                right == null
                    ? SizedBox(width: maxWidth, height: maxHeight)
                    : Column(children: [
                        CachedNetworkImage(
                            imageUrl: right.imageUrl,
                            width: maxWidth,
                            height: maxHeight,
                            fit: BoxFit.fill,
                            progressIndicatorBuilder:
                                (context, url, progress) => Center(
                                      child: CircularProgressIndicator(
                                          value: progress.progress),
                                    )),
                        SizedBox(
                            width: maxWidth,
                            child: Text(right.name,
                                maxLines: 2, overflow: TextOverflow.ellipsis)),
                      ]),
              ],
            );
          },
        ),
      ),
    );
  }
}
