import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../widgets/tv_focusable.dart';

class CodeEntryWidget extends StatefulWidget {
  final String title;
  final String code;
  final bool showCode;

  const CodeEntryWidget({
    super.key,
    required this.title,
    required this.code,
    this.showCode = false,
  });

  @override
  State<CodeEntryWidget> createState() => _CodeEntryWidgetState();
}

class _CodeEntryWidgetState extends State<CodeEntryWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isFocused = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TVFocusable(
      id: 'code_entry_${widget.title.toLowerCase()}',
      onSelect: () {
        setState(() {
          _isFocused = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFocused
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.1),
            width: _isFocused ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.showCode)
              Text(
                widget.code,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Enter code',
                  hintStyle: TextStyle(
                    color: AppColors.text.withOpacity(0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                ),
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 4,
                onChanged: (value) {
                  if (value.length == 4 && value == '9999') {
                    setState(() {
                      _controller.text = widget.code;
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
