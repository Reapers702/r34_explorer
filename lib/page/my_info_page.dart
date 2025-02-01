import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:r34_video/constant/page_routes.dart';
import 'package:r34_video/page/community_user_page.dart';
import 'package:r34_video/repo/local_repo.dart';

class MyInfoPage extends StatefulWidget {
  const MyInfoPage({super.key});

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    log('user page change life cycle $state');
    if (state == AppLifecycleState.resumed) {
      log('user page resume');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
        body: FutureBuilder<int>(
      future: LocalUserRepo.isLogin()
          .then((isLog) => isLog ? LocalUserRepo.getUserId() : -1),
      builder: (context, snapshot) {
        int? userId = snapshot.data;
        if (userId == null || userId <= 0) {
          return Column(
            children: [
              SizedBox(
                height: MediaQuery.of(context).padding.top,
              ),
              Container(
                height: screenSize.height * 0.3,
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushNamed(PageRoutes.loginPage),
                  child: Container(
                    height: screenSize.height * 0.12,
                    width: screenSize.height * 0.12,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(screenSize.height * 0.12),
                      border: Border.all(color: Colors.grey, width: 2),
                    ),
                    child: Text('去登录'),
                  ),
                ),
              ),
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      Container(
                        height: 40,
                        color: Colors.redAccent,
                        child: TabBar(
                          tabs: ['上传的视频', '喜欢的视频']
                              .map((e) => Tab(text: e))
                              .toList(),
                          indicatorSize: TabBarIndicatorSize.label,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_outline),
                              Text('登录后解锁功能'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return CommunityUserPage(userId: 44711);
      },
    ));
  }
}
