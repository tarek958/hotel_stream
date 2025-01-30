import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tv_focus_service.dart';

class TVFocusable extends StatefulWidget {
  final String id;
  final Widget child;
  final Color focusColor;
  final double focusBorderWidth;
  final BorderRadius? borderRadius;
  final VoidCallback? onSelect;
  final EdgeInsets padding;
  final bool autofocus;

  const TVFocusable({
    Key? key,
    required this.id,
    required this.child,
    this.focusColor = Colors.blue,
    this.focusBorderWidth = 2.0,
    this.borderRadius,
    this.onSelect,
    this.padding = const EdgeInsets.all(4.0),
    this.autofocus = false,
  }) : super(key: key);

  @override
  State<TVFocusable> createState() => _TVFocusableState();
}

class _TVFocusableState extends State<TVFocusable> {
  late final FocusNode _focusNode;
  final _service = TVFocusService();

  @override
  void initState() {
    super.initState();
    _focusNode = _service.registerFocusable(widget.id);
    if (widget.autofocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _service.unregisterFocusable(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        if (mounted) {
          setState(() {});
        }
      },
      onKey: (node, event) {
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onSelect?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            border: Border.all(
              color:
                  _focusNode.hasFocus ? widget.focusColor : Colors.transparent,
              width: widget.focusBorderWidth,
            ),
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8.0),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
