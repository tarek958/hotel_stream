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
  final bool isCategory; // Flag to identify category buttons
  final FocusNode? focusNode; // Optional external focus node

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
    this.isCategory = false, // Default to false
    this.focusNode, // Optional external focus node
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
    print('TVFocusable[${widget.id}]: Initializing');

    // Use provided focus node or register a new one
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      print('TVFocusable[${widget.id}]: Using provided focus node');
    } else {
      _focusNode = _service.registerFocusable(widget.id);
      print('TVFocusable[${widget.id}]: Registered new focus node');
    }

    _focusNode.addListener(() {
      print(
          'TVFocusable[${widget.id}]: Focus changed to ${_focusNode.hasFocus}');
    });

    if (widget.autofocus) {
      print('TVFocusable[${widget.id}]: Requesting autofocus');
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    print('TVFocusable[${widget.id}]: Disposing');
    // Only unregister if we created the focus node ourselves
    if (widget.focusNode == null) {
      _service.unregisterFocusable(widget.id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (hasFocus) {
        print(
            'TVFocusable[${widget.id}]: onFocusChange called with hasFocus=$hasFocus');
        if (mounted) {
          setState(() {});
        }
      },
      onKey: (node, event) {
        print('TVFocusable[${widget.id}]: Key event: ${event.logicalKey}');

        if (event is RawKeyDownEvent) {
          // Handle select/enter key
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            print(
                'TVFocusable[${widget.id}]: Select/Enter key pressed, calling onSelect');
            widget.onSelect?.call();
            return KeyEventResult.handled;
          }

          // For category buttons, let arrow keys be handled by parent
          if (widget.isCategory) {
            print(
                'TVFocusable[${widget.id}]: Category button ignoring arrow key for parent');
            return KeyEventResult.ignored;
          }
        }

        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          print('TVFocusable[${widget.id}]: Tapped');
          widget.onSelect?.call();
        },
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
