import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart'; // تأكد من مسار الاستيراد

class CustomDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> itemsList; // نمرر الداتا الأصلية هنا
  final String Function(T) itemLabelBuilder; // دالة لاستخراج النص من الـ Data
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String? Function(T?)? validator;
  final Color? fillColor;
  final Widget? prefixIcon;
  final String? labelText;

  const CustomDropdown({
    super.key,
    required this.itemsList,
    required this.itemLabelBuilder,
    this.value,
    this.onChanged,
    this.hint,
    this.validator,
    this.fillColor,
    this.prefixIcon,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<T>(
          value: value, // تم التعديل من initialValue إلى value لتعمل بشكل صحيح
          isExpanded: true,
          onChanged: onChanged,
          validator: validator,
          itemHeight: null, // مهم جداً لمنع أي قص (Overflow) في شكل الصناديق
          
          // 1. شكل الحقل من الخارج (نفس الألوان والشفافية)
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: fillColor ?? AppColors.primary.withAlpha((0.05 * 255).round()),
            hintText: hint,
            labelText: labelText,
            prefixIcon: prefixIcon,
            hintStyle: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
          
          // 2. شكل القائمة المفتوحة (تصميم الصناديق)
          items: itemsList.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha((0.05 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withAlpha((0.3 * 255).round()),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    itemLabelBuilder(item), // استدعاء النص هنا
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),

          // 3. شكل العنصر بعد اختياره والحقل مغلق (نص فقط ومحاذاة لليمين)
          selectedItemBuilder: (BuildContext context) {
            return itemsList.map((T item) {
              return Align(
                alignment: Alignment.centerRight,
                child: Text(
                  itemLabelBuilder(item),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              );
            }).toList();
          },

          icon: const Icon(
            Icons.arrow_drop_down_rounded,
            color: AppColors.primary,
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12.0),
          elevation: 2,
        ),
      ],
    );
  }
}