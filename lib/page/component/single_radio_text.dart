import 'dart:collection';
import 'dart:developer';

import 'package:flutter/material.dart';

class SingleRadioTextController<T> {
  T? _currVal;
  SingleRadioTextController();

  T? get currVal {
    return _currVal;
  }
}

class SingleRadioText<T> extends StatefulWidget {
  final SingleRadioTextController<T>? controller;
  final void Function(T)? onSelect;

  final LinkedHashMap<String, T> values;
  final String? defaultSelect;
  final double fontSize;

  const SingleRadioText({
    super.key,
    required this.values,
    this.controller,
    this.onSelect,
    this.defaultSelect,
    this.fontSize = 12,
  });

  @override
  State<SingleRadioText> createState() => _SingleRadioTextState();
}

class _SingleRadioTextState extends State<SingleRadioText> {
  String? nameSelect;

  @override
  void initState() {
    super.initState();
    nameSelect = widget.defaultSelect ?? widget.values.keys.first;
  }

  void _onSelect(String name) {
    setState(() {
      log('_onSelect $name');
      nameSelect = name;
      widget.controller?._currVal = widget.values[name];
      widget.onSelect?.call(widget.values[name]!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.values.keys
          .map(
            (e) => ElevatedButton(
              onPressed: () => _onSelect(e),
              style: ElevatedButton.styleFrom(
                backgroundColor: nameSelect == e
                    ? Colors.orangeAccent
                    : Colors.blue, // 按钮背景颜色
                foregroundColor: Colors.white, // 文字颜色
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // 圆角
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ), // 内边距
                elevation: 3, // 阴影高度
              ),
              child: Text(
                e,
                style: TextStyle(
                  fontSize: widget.fontSize,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
