# Spec: Fix UI Overflow in StatItemWidget (BUG-05)

## Overview

The `StatItemWidget` in `general_statistics_screen.dart` causes a `RenderFlex overflowed` error on the Balance stat card. The widget uses a `Row` with two children: a `Column` (label + optional subtitle) and a `Text` (value). Neither child constrains its width, so when the label text is long (common in Arabic locale), the `Row` overflows horizontally.

## Root Cause

**File:** `lib/presentation/screens/statistics/general_statistics_screen.dart` (Lines 426-468)

In `StatItemWidget.build()` (Line 441-466):
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Column(  // <-- NOT wrapped in Flexible/Expanded
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyLarge),  // <-- No overflow handling
        ...
      ],
    ),
    Text(value, ...),  // Value text
  ],
)
```

The `Column` takes unbounded width from the `Row`, and the label `Text` has no `overflow` property, causing pixel overflow when `label` + `value` exceed the available width.

## Functional Requirements

### FR-1: Wrap `Column` in `Flexible`
- Wrap the `Column` containing label and subtitle in a `Flexible(fit: FlexFit.loose, ...)` widget.
- This constrains the `Column` to fill only available space, yielding to the value `Text`.

### FR-2: Add `TextOverflow.ellipsis` to label and subtitle
- Add `overflow: TextOverflow.ellipsis` and `maxLines: 1` to both the label `Text` and subtitle `Text` widgets.

### FR-3: Add horizontal spacing buffer
- Add `const SizedBox(width: 12)` between the `Flexible` column and the value `Text` to prevent text overlap.

### FR-4: Preserve existing styling and behavior
- No changes to colors, text styles, padding, or vertical spacing.

## Exact Code Change

**Current (Lines 444-464):**
```dart
child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.bodyLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary(context))),
        ],
      ],
    ),
    Text(
      value,
      style: AppTextStyles.h3
          .copyWith(color: valueColor ?? AppColors.textPrimary(context)),
    ),
  ],
),
```

**Proposed:**
```dart
child: Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Flexible(
      fit: FlexFit.loose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyLarge,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary(context)),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ],
      ),
    ),
    const SizedBox(width: 12),
    Text(
      value,
      style: AppTextStyles.h3.copyWith(color: valueColor ?? AppColors.textPrimary(context)),
    ),
  ],
),
```

## Acceptance Criteria

- [ ] `StatItemWidget` label text truncates with ellipsis when too long.
- [ ] No `RenderFlex overflowed` error on Balance card.
- [ ] Value text remains visible and right-aligned.
- [ ] Layout works correctly in both Arabic (RTL) and English (LTR) locales.
- [ ] Subtitle text (when present) displays correctly with ellipsis fallback.
- [ ] Horizontal spacing buffer prevents text overlap.
- [ ] No visual regression on other stat cards.

## Out of Scope

- Changes to any other widget or screen.
- Changes to `AppTextStyles` or `AppColors`.
- Responsive layout changes.
