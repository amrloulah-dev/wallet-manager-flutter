import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? Function(T?)? validator;
  final Color? fillColor;
  final Color? borderColor;
  final double borderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final List<Widget> Function(BuildContext)? selectedItemBuilder;
  final bool isExpanded;
  final Widget? prefixIcon;
  final String? labelText;

  const CustomDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.hint,
    this.validator,
    this.fillColor,
    this.borderColor,
    this.borderRadius = 12.0,
    this.contentPadding,
    this.selectedItemBuilder,
    this.isExpanded = true,
    this.prefixIcon,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          selectedItemBuilder: selectedItemBuilder,
          isExpanded: isExpanded,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: fillColor ?? Theme.of(context).cardColor,
            hintText: hint,
            labelText: labelText,
            prefixIcon: prefixIcon,
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: borderColor ?? AppColors.primary,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: borderColor ?? AppColors.primary,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: BorderSide(
                color: borderColor ?? AppColors.primary,
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
          ),
          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.primary,
          ),
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          elevation: 2,
        ),
      ],
    );
  }
}
