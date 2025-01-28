import 'package:flutter/material.dart';
import 'package:r34_video/constant/tab_enum.dart';

class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  int _currentIndex = 0;

  Widget _buildMenuItem(int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            TabConst.tabs.values.elementAt(index).value,
            color: _currentIndex == index ? Colors.blue : Colors.grey,
          ),
          Text(
            TabConst.tabs.values.elementAt(index).key,
            style: TextStyle(
              fontSize: 12,
              color: _currentIndex == index ? Colors.blue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: TabConst.pages,
      ),
      bottomNavigationBar: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(
              TabConst.tabs.length, (index) => _buildMenuItem(index)),
        ),
      ),
    );
  }
}
