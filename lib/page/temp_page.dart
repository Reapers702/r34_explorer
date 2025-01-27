import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:r34_video/page/component/underlined_text.dart';

class TempPage extends StatefulWidget {
  const TempPage({super.key});

  @override
  State<TempPage> createState() => _TempPageState();
}

class _TempPageState extends State<TempPage> {
  final PageController _pageController = PageController();
  final List<Widget?> _pages = List.generate(5, (index) => null); // 初始化为空

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                title: Text('吸顶菜单',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                    )),
                pinned: false,
                floating: false,
                snap: false,
                backgroundColor: Colors.red,
                automaticallyImplyLeading: false,
                toolbarHeight: 30,
              ),
              SliverAppBar(
                title: UnderlinedTextGroup<String>(
                  {
                    '播放最多': '播放最多',
                    '最新上传': '最新上传',
                    '评分最高': '评分最高',
                    '哈哈哈哈': '哈哈哈哈'
                  },
                  onSelect: (p0) {},
                ),
                pinned: true,
                floating: true,
                snap: true,
                backgroundColor: Colors.transparent,
                automaticallyImplyLeading: false,
              ),
              // AppBar()
            ];
          },
          body: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {});
            },
            itemBuilder: (context, index) {
              // 只有在滑动到该页面时才构建页面内容
              if (_pages[index] == null) {
                _pages[index] = _buildPage(index);
              }
              return _pages[index];
            },
            itemCount: _pages.length,
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    log('_buildPage $index');
    return Center(
      child: Text(
        '页面 ${index + 1}',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
