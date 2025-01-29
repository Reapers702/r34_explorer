import 'dart:developer';

import 'package:flutter/material.dart';

class UnderlinedTextGroup<T> extends StatefulWidget {
  final Map<String, T> nameMap;
  final ValueChanged<T> onSelect;

  const UnderlinedTextGroup(this.nameMap, {required this.onSelect, super.key});

  @override
  State<UnderlinedTextGroup<T>> createState() => _UnderlinedTextGroupState<T>();
}

class _UnderlinedTextGroupState<T> extends State<UnderlinedTextGroup<T>>
    with SingleTickerProviderStateMixin {
  late String _currName;

  @override
  void initState() {
    super.initState();
    _currName = widget.nameMap.keys.first;
  }

  void _onButtonPressed(String name) {
    log('on button pressed $name');
    setState(() {
      _currName = name;
    });
    widget.onSelect(widget.nameMap[name] as T);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 12,
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.nameMap.entries
          .map(
            (e) => UnderlinedText(
              e.key,
              textStyle: textStyle,
              underlineColor: Colors.pinkAccent,
              underlineHeight: 4,
              spacing: 6,
              isSelected: e.key == _currName,
              onPressed: () => _onButtonPressed(e.key),
            ),
          )
          .toList(),
    );
  }
}

class UnderlinedText extends StatefulWidget {
  final String text;
  final bool isSelected;
  final VoidCallback onPressed;

  final TextStyle textStyle;
  final Color underlineColor;
  final double underlineHeight;
  final double underlinePadding;
  final double spacing;

  const UnderlinedText(
    this.text, {
    required this.isSelected,
    required this.onPressed,
    this.textStyle = const TextStyle(fontSize: 16),
    this.underlineColor = Colors.pinkAccent,
    this.underlineHeight = 2,
    this.underlinePadding = 4,
    this.spacing = 4,
    super.key,
  });

  @override
  State<UnderlinedText> createState() => _UnderlinedTextState();
}

class _UnderlinedTextState extends State<UnderlinedText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late double _halfTextWidth;

  @override
  void initState() {
    super.initState();

    _halfTextWidth = _calculateTextWidth(widget.text, widget.textStyle) / 2;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(UnderlinedText oldWidget) {
    // log('did update widget ${widget.text}');
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.spacing + widget.underlineHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 文字
          GestureDetector(
            onTap: widget.onPressed,
            child: Text(
              widget.text,
              style: widget.textStyle.copyWith(
                color: widget.isSelected ? Colors.pinkAccent : Colors.grey,
              ),
            ),
          ),
          // 下划线
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) => Positioned(
              // x -> widget.underlinePadding + (_halfTextWidth - widget.underlinePadding) * (1 - x)
              left: widget.underlinePadding +
                  (_halfTextWidth - widget.underlinePadding) *
                      (1 - _animation.value), // 下划线左边距
              right: widget.underlinePadding +
                  (_halfTextWidth - widget.underlinePadding) *
                      (1 - _animation.value), // 下划线右边距
              bottom: -widget.spacing, // 控制下划线与文字的距离
              child: Container(
                height: widget.underlineHeight, // 下划线高度
                decoration: BoxDecoration(
                  color: widget.underlineColor, // 下划线颜色
                  borderRadius:
                      BorderRadius.circular(widget.underlineHeight / 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 计算文字的宽度
  double _calculateTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: style,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.width;
  }
}
