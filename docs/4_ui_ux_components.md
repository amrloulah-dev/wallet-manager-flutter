# 🎨 Report 4: UI/UX & Components

## 1. Theming & Design System

The application employs a comprehensive, centralized design system utilizing Flutter's `ThemeData` to ensure consistency across the UI.

### Global Theme Configuration (`app_theme.dart` & `app_colors.dart`)
*   **Color Palette**: The primary brand color is a distinct Blue (`#2196F3`), which shifts to a lighter shade (`#64B5F6`) in dark mode for better contrast. Semantic colors are strictly defined: Success (Green `#4CAF50`), Error (Red `#F44336`), and Warning (Amber `#xFFFF9800`).
*   **Typography**: The app universally uses the `Cairo` font family, mapped via a robust `AppTextStyles` configuration that sets font weights and sizes across `headlineMedium`, `bodyLarge`, `labelLarge`, etc.
*   **Dark/Light Mode**: Handled via `Theme.of(context).brightness`. The app defines explicit `LightColors` and `DarkColors` palettes. Helper methods (e.g., `AppColors.surface(context)`) dynamically return the correct shade.
*   **Global Widget Styling**: 
    *   **Input Fields (`InputDecorationTheme`)**: Uniformly styled with a filled background, an outline border with a 12px border radius, and dynamic border colors depending on focus/error state.
    *   **Buttons (`ElevatedButtonThemeData`, etc.)**: Globally configured to have a 12px border radius, consistent internal padding (`vertical: 14, horizontal: 24`), and specific text styles.
    *   **Cards (`CardThemeData`)**: Uniform 12px border radius and adaptive shadows depending on the current brightness.

## 2. Bilingual Support & RTL Strategy

The app supports English (`en`) and Arabic (`ar`) via standard `.arb` files and `flutter_localizations` (`AppLocalizations.of(context)`). Because Arabic relies on Right-To-Left (RTL) layout rendering, the app faces significant programmatic challenges when rendering numeric data.

### RTL / LTR Rendering Challenges
Mixing Arabic characters (RTL) with numbers, phone numbers, or mathematical formulas (LTR) often causes the Flutter rendering engine to flip text sequences unexpectedly (e.g., placing currency symbols on the wrong side or jumbling phone number spacing).

**Specific Programmatic Solutions:**
1.  **Digit Normalization**: Inside `number_formatter.dart`, the `_convertArabicToEnglishDigits` function actively replaces Arabic numeric characters (٠, ١, ٢) with Western digits (0, 1, 2) before formatting.
2.  **Explicit LTR Wrappers**: UI widgets displaying balances or limits (like the limit bar in `WalletCard`) explicitly wrap the text elements in `Directionality(textDirection: TextDirection.ltr, child: ...)` to force consistent left-to-right calculation rendering, avoiding percentage/limit flips.
3.  **Unicode LRM Marker (CRITICAL)**: To ensure phone numbers format accurately (e.g., `0101 234 5678`) rather than flipping chunks of digits within an Arabic sentence, `NumberFormatter.formatPhoneNumber` injects the **Unicode Left-to-Right Mark (`\u200E`)** at the start and end of the string.
    ```dart
    // Example from number_formatter.dart
    return '\u200E${normalized.substring(0, 4)} ${normalized.substring(4, 7)} ${normalized.substring(7)}\u200E';
    ```

## 3. Exhaustive Reusable Components

The `lib/presentation/widgets/` directory encapsulates high-quality, reusable UI elements.

### Wallet Card (`wallet_card.dart`)
This is the most critical financial component.
*   **Structure**: It renders the wallet type, phone number, real-time limits (Daily send/receive progress bars), and the current balance.
*   **Visual Scaling**: The entire card is wrapped in a `Transform.scale(scale: 0.90)`. This allows the element to shrink visually, providing a margin-like spacing without increasing the bounding box of the parent layout, making grid/list spacing tighter.
*   **Status Badges**: Evaluates `wallet.walletStatus == WalletStatus.suspended`. If suspended, the badge background dynamically shifts to `Colors.red.shade900.withOpacity(0.3)` with red text.
*   **Frozen State Logic**: A boolean `isFrozen` (driven by subscription logic) dynamically overrides the provider's brand color to grey, disables the `onEdit` and `onDelete` actions, and re-routes the entire card's `onTap` to the Paywall (`RouteConstants.upgradeScreen`).

### Custom Dropdown (`custom_dropdown.dart`)
A highly customized wrapper over `DropdownButtonFormField<T>`.
*   **Data Binding**: Takes a raw `itemsList<T>` and an `itemLabelBuilder` function to extract the display string.
*   **Overflow Prevention**: Explicitly sets `itemHeight: null` to prevent text-clipping overflow issues if the text is long.
*   **UI Tweaks**: Open dropdown items are styled as heavily padded inner boxes (using `AppColors.primary.withAlpha(13)` backgrounds). Once selected, the closed view overrides the display with `selectedItemBuilder` to right-align (`AlignmentDirectional.centerEnd`) the text.

### Other Core Widgets
*   **Custom Button (`custom_button.dart`)**: 
    *   Implements an animated `ScaleTransition` using `Listener` (`onPointerDown` / `onPointerUp`) to shrink the button scale to `0.95`, providing physical, tactile UI feedback.
    *   Takes an `isLoading` flag; if true, it replaces the text with a tightly bound, colored `CircularProgressIndicator`.
*   **Empty State Widget (`empty_state_widget.dart`)**: Used to handle empty data arrays (like "No Wallets Found"). Utilizes an `AnimationController` to orchestrate staggered `SlideTransition`, `ScaleTransition`, and `FadeTransition` animations for the illustration, title, description, and CTA button, making empty screens feel dynamic.

## 4. User Feedback & View States

The app provides rich, contextual visual feedback outside of standard UI views.

### Toast Notifications (`toast_utils.dart`)
*   The app uses the `bot_toast` package to present notifications. This decouples the toasts from the specific `BuildContext` of the widget tree.
*   It exposes static methods: `showSuccess`, `showError`, `showInfo`, and `showWarning`.
*   **Adaptive Design**: The builder dynamically checks `Theme.of(context).brightness`. If dark mode is active, it renders a specialized `_buildDarkToast` which utilizes `AppColors.dark.surface` and places a thin colored border (`Radius.circular(12)`) on the leading edge.

### View States
*   **Loading**: Shimmer effects or `CircularProgressIndicator` elements are used while waiting on Firebase queries.
*   **Empty States**: Handled robustly by the aforementioned `EmptyStateWidget`.
*   **Dialogs**: `dialog_utils.dart` wraps `awesome_dialog` to present destructive confirmations (e.g., deleting a wallet) or informational popups, preventing accidental data loss.
