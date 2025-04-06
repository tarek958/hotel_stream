import 'package:flutter/material.dart';
import '../tv_focusable.dart';
import '../../constants/app_constants.dart';

class CustomBackButton extends StatelessWidget {
  final VoidCallback onSelect;
  final bool isSelected;

  const CustomBackButton({
    super.key,
    required this.onSelect,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      id: 'back_button',
      onSelect: onSelect,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isSelected ? AppColors.primary : Colors.white,
          ),
          onPressed: onSelect,
        ),
      ),
    );
  }
}
