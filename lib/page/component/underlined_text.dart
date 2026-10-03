import 'package:flutter/material.dart';

/// 一排带下划线动效的单选文本。
///
/// 早期版本内部自己记选中项，父级改条件（比如「重置筛选」）时 UI 不会跟着变；
/// 现在支持受控：传了 [selected] 就以父级为准。
class UnderlinedTextGroup<T> extends StatefulWidget {
  final Map<String, T> nameMap;
  final ValueChanged<T> onSelect;

  /// 受控选中值。为空时组件自己维护选中项。
  final T? selected;

  final double fontSize;
  final Color underlineColor;
  final EdgeInsetsGeometry padding;

  const UnderlinedTextGroup(
    this.nameMap, {
    required this.onSelect,
    this.selected,
    this.fontSize = 12,
    this.underlineColor = Colors.pinkAccent,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  @override
  State<UnderlinedTextGroup<T>> createState() => _UnderlinedTextGroupState<T>();
}

class _UnderlinedTextGroupState<T> extends State<UnderlinedTextGroup<T>> {
  String? _internalName;

  @override
  void initState() {
    super.initState();
    _internalName = _selectedNameFromWidget();
  }

  @override
  void didUpdateWidget(covariant UnderlinedTextGroup<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _internalName = _selectedNameFromWidget();
    }
  }

  String? _selectedNameFromWidget() {
    if (widget.selected == null) {
      return widget.nameMap.keys.firstOrNull;
    }
    for (final entry in widget.nameMap.entries) {
      if (entry.value == widget.selected) {
        return entry.key;
      }
    }
    return widget.nameMap.keys.firstOrNull;
  }

  void _onButtonPressed(String name) {
    setState(() {
      _internalName = name;
    });
    widget.onSelect(widget.nameMap[name] as T);
  }

  @override
  Widget build(BuildContext context) {
    final currentName = widget.selected == null
        ? _internalName
        : _selectedNameFromWidget();

    return Padding(
      padding: widget.padding,
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: widget.nameMap.entries
            .map(
              (entry) => UnderlinedText(
                entry.key,
                textStyle: TextStyle(fontSize: widget.fontSize),
                underlineColor: widget.underlineColor,
                underlineHeight: 3,
                spacing: 5,
                isSelected: entry.key == currentName,
                onPressed: () => _onButtonPressed(entry.key),
              ),
            )
            .toList(),
      ),
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
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 260),
    vsync: this,
  );
  late final Animation<double> _animation =
      Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

  @override
  void initState() {
    super.initState();
    if (widget.isSelected) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(UnderlinedText oldWidget) {
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: widget.spacing + widget.underlineHeight,
      ),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              widget.text,
              maxLines: 1,
              style: widget.textStyle.copyWith(
                color: widget.isSelected ? widget.underlineColor : Colors.grey,
                fontWeight:
                    widget.isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    widthFactor: _animation.value,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: -widget.spacing,
                        left: widget.underlinePadding,
                        right: widget.underlinePadding,
                      ),
                      child: Container(
                        height: widget.underlineHeight,
                        decoration: BoxDecoration(
                          color: widget.underlineColor,
                          borderRadius: BorderRadius.circular(
                            widget.underlineHeight / 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
