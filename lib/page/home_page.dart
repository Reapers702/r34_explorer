import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:r34_video/page/component/page_search_bottom_sheet.dart';
import 'package:r34_video/page/component/video_thumb.dart';
import 'package:r34_video/repo/entity/r34_page.dart';
import 'package:r34_video/repo/entity/r34_search_option.dart';
import 'package:r34_video/repo/r34_repo.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<R34Video> _r34Videos = [];
  PersistentBottomSheetController? _bottomSheetController;
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  void _loadData(R34SearchOption option) async {
    try {
      final newR34Page = await R34Repo.getPage(option);
      setState(() {
        _r34Videos = newR34Page.videos;
      });
    } catch (e) {
      log('Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData(R34SearchOption());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Rule 34 Video'),
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
          itemCount: (_r34Videos.length / 2 + 0.5).toInt(),
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            R34Video left = _r34Videos[index * 2];
            R34Video? right = _r34Videos.elementAtOrNull(index * 2 + 1);
            final screenSize = MediaQuery.of(context).size;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                VideoThumb(left),
                SizedBox(width: screenSize.width * 0.08),
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
