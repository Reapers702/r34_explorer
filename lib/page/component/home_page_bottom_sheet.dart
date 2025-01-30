import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:r34_video/constant/search_option.dart';
import 'package:r34_video/page/component/single_radio_text.dart';

enum MoveDirection {
  up,
  down,
  quiet,
}

class HomePageBottomSheet extends StatefulWidget {
  static const bgColor = Color(0xFFF2F2F2);
  static const dragColor = Color(0xFFD4D4D4);
  static const List<double> magnetPoint = [0, 0.3, 0.8];

  final VideoDateAdded defaultDateAdded;
  final VideoDuration defaultDuration;
  final void Function(VideoDateAdded dateAdded, VideoDuration duration)?
      onOptionConfirm;

  const HomePageBottomSheet({
    super.key,
    this.onOptionConfirm,
    this.defaultDateAdded = VideoDateAdded.all,
    this.defaultDuration = VideoDuration.all,
  });

  @override
  State<HomePageBottomSheet> createState() => _HomePageBottomSheetState();
}

class _HomePageBottomSheetState extends State<HomePageBottomSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  late final SingleRadioTextController<VideoDateAdded> _dateAddedController;
  late final SingleRadioTextController<VideoDuration> _durationController;

  MoveDirection _moveDirection = MoveDirection.quiet;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.3,
      lowerBound: 0.2,
      upperBound: 1,
    );

    _dateAddedController = SingleRadioTextController(
        currVal: widget.defaultDateAdded,
        nameMap: VideoDateAdded.descriptionMap);
    _durationController = SingleRadioTextController(
        currVal: widget.defaultDuration, nameMap: VideoDuration.descriptionMap);
  }

  _onDragFinish() {
    log('_onDragFinish $_moveDirection ${_animationController.value}');
    double? targetAnimationValue;
    if (_moveDirection == MoveDirection.quiet) {
      targetAnimationValue = 0.2;
    } else {
      if (_animationController.value <= HomePageBottomSheet.magnetPoint.first) {
        targetAnimationValue = HomePageBottomSheet.magnetPoint.first;
      } else if (_animationController.value >=
          HomePageBottomSheet.magnetPoint.last) {
        targetAnimationValue = HomePageBottomSheet.magnetPoint.last;
      } else {
        for (int i = 0; i < HomePageBottomSheet.magnetPoint.length - 1; i++) {
          if (_animationController.value >=
                  HomePageBottomSheet.magnetPoint[i] &&
              _animationController.value <
                  HomePageBottomSheet.magnetPoint[i + 1]) {
            targetAnimationValue = _moveDirection == MoveDirection.down
                ? HomePageBottomSheet.magnetPoint[i]
                : HomePageBottomSheet.magnetPoint[i + 1];
          }
        }
      }
    }
    if (targetAnimationValue == null || targetAnimationValue == 0) {
      Navigator.pop(context);
    } else {
      _animationController.animateTo(targetAnimationValue,
          curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final sheetMaxHeight = screenSize.height * 0.8;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => Container(
        height: sheetMaxHeight * _animationController.value,
        color: HomePageBottomSheet.bgColor,
        child: Column(
          children: [
            GestureDetector(
              onVerticalDragUpdate: (details) {
                final delta = details.delta.dy / sheetMaxHeight;
                _animationController.value -= delta;

                _moveDirection = delta > 0
                    ? MoveDirection.down
                    : (delta < 0 ? MoveDirection.up : MoveDirection.quiet);
              },
              onVerticalDragEnd: (details) {
                _onDragFinish();
                log('drag end details: $details');
              },
              child: Container(
                height: sheetMaxHeight * 0.05,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 50,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 确定按钮
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(
                          top: 4,
                          right: 40,
                        ),
                        width: 80,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onOptionConfirm?.call(
                              _dateAddedController.currVal ??
                                  VideoDateAdded.all,
                              _durationController.currVal ?? VideoDuration.all,
                            );
                          },
                          child: Text('确定'),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(
                              left: 10, right: 10, top: 10),
                          child: Text(
                            '上传时间',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        Expanded(
                            child: SingleRadioText(
                          values: VideoDateAdded.descriptionMap,
                          controller: _dateAddedController,
                        )),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.only(
                              left: 10, right: 10, top: 10),
                          child: Text(
                            '视频时长',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        Expanded(
                            child: SingleRadioText(
                          values: VideoDuration.descriptionMap,
                          controller: _durationController,
                        )),
                      ],
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
}
