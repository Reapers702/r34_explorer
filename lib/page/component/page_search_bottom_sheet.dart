import 'package:flutter/material.dart';
import 'package:r34_video/page/component/single_radio_text.dart';
import 'package:r34_video/constant/search_option.dart';

// 这个组件是一个早期的测试组件，后面会进行重构
// 目前使用 HomePageBottomSheet 替代

class PageSearchBottomSheet extends StatefulWidget {
  final Function(R34SearchOption) onSearch;
  const PageSearchBottomSheet({super.key, required this.onSearch});

  @override
  State<PageSearchBottomSheet> createState() => _PageSearchBottomSheetState();
}

class _PageSearchBottomSheetState extends State<PageSearchBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool onTap = false;

  SingleRadioTextController<VideoDuration> optionDurationController =
      SingleRadioTextController<VideoDuration>();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 0.1,
      lowerBound: 0.1,
      upperBound: 0.8,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => SizedBox(
        height: MediaQuery.of(context).size.height * _controller.value,
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTapUp: (details) {
                setState(() {
                  onTap = false;
                });
              },
              onVerticalDragUpdate: (details) {
                // 根据拖动距离调整高度
                final delta =
                    details.delta.dy / MediaQuery.of(context).size.height;
                _controller.value -= delta;
                onTap = true;
              },
              onVerticalDragEnd: (details) {
                // 拖动结束后，吸附到最近的吸附点
                if (_controller.value < 0.2) {
                  _controller.animateTo(0.05);
                } else if (_controller.value < 0.4) {
                  _controller.animateTo(0.3);
                } else {
                  _controller.animateTo(0.8);
                }
                onTap = false;
              },
              child: Container(
                alignment: Alignment.center,
                color: Colors.transparent,
                height: 40,
                width: MediaQuery.of(context).size.width,
                child: Container(
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.grey.withOpacity(0.5),
                    boxShadow: [
                      ...(onTap
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1), // 阴影颜色
                                spreadRadius: 1.5, // 阴影扩散半径
                                blurRadius: 3, // 阴影模糊半径
                                offset: const Offset(0, 3), // 阴影偏移量（水平偏移，垂直偏移）
                              )
                            ]
                          : []),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ElevatedButton(
                        onPressed: () {
                          widget.onSearch(R34SearchOption());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // 按钮背景颜色
                          foregroundColor: Colors.white, // 文字颜色
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20), // 圆角
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12), // 内边距
                          elevation: 3, // 阴影高度
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(fontSize: 16),
                        )),
                    const SizedBox(height: 20),
                    SingleRadioText(
                      controller: optionDurationController,
                      values: VideoDuration.descriptionMap,
                      defaultSelect: 'all',
                      fontSize: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
