import 'dart:collection';

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
  final LinkedHashMap<String, T> values;
  final String? defaultSelect;
  final double fontSize;

  const SingleRadioText({
    super.key,
    this.controller,
    required this.values,
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
      nameSelect = name;
      widget.controller?._currVal = widget.values[name];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.values.keys
          .map((e) => GestureDetector(
                onTap: () => _onSelect(e),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 4,
                  ),
                  color: nameSelect == e ? Colors.amber : Colors.grey,
                  child: Text(
                    e,
                    style: TextStyle(
                      fontSize: widget.fontSize,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}
