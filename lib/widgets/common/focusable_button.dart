import 'package:flutter/material.dart';
import '../tv_focusable.dart';

class FocusableButton extends StatelessWidget {
  final String id;
  final VoidCallback onSelect;
  final Widget child;
  final bool isSelected;

  const FocusableButton({
    super.key,
    required this.id,
    required this.onSelect,
    required this.child,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      id: id,
      onSelect: onSelect,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}
