import 'package:intl/intl.dart';
import 'package:walletmanager/l10n/arb/app_localizations.dart';

class DateHelper {

  // ===========================
  // Format DateTime to String
  // ===========================
  /// Formats a DateTime object into a string.
  static String formatDateTime(DateTime dateTime,
      {String format = 'dd/MM/yyyy'}) {
    return DateFormat(format).format(dateTime);
  }

  // ===========================
  // Get Start of Day
  // ===========================
  /// Returns a DateTime representing the start of the given day (00:00:00).
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // ===========================
  // Get End of Day
  // ===========================
  /// Returns a DateTime representing the end of the given day (23:59:59.999).
  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  // ===========================
  // Get Start of Week (Saturday)
  // ===========================
  /// Returns the start of the week (Saturday, 00:00:00) for a given date.
  /// In Egypt, the week starts on Saturday.
  static DateTime getStartOfWeek(DateTime date) {
    // DateTime.saturday is 6. We adjust to find the last Saturday.
    int daysToSubtract = (date.weekday % 7) - (DateTime.saturday % 7);
    if (daysToSubtract < 0) {
      daysToSubtract += 7;
    }
    final startOfWeek = date.subtract(Duration(days: daysToSubtract));
    return getStartOfDay(startOfWeek);
  }

  // ===========================
  // Get End of Week (Friday)
  // ===========================
  /// Returns the end of the week (Friday, 23:59:59) for a given date.
  /// In Egypt, the week ends on Friday.
  static DateTime getEndOfWeek(DateTime date) {
    final startOfWeek = getStartOfWeek(date);
    // Friday is 6 days after Saturday.
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return getEndOfDay(endOfWeek);
  }

  // ===========================
  // Get Start of Month
  // ===========================
  /// Returns the first day of the month at 00:00:00.
  static DateTime getStartOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  // ===========================
  // Get End of Month
  // ===========================
  /// Returns the last day of the month at 23:59:59.999.
  static DateTime getEndOfMonth(DateTime date) {
    final nextMonth = DateTime(date.year, date.month + 1, 1);
    final endOfMonth = nextMonth.subtract(const Duration(days: 1));
    return getEndOfDay(endOfMonth);
  }

  // ===========================
  // Check if Date is Today
  // ===========================
  /// Checks if the given date is today.
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }



  // ===========================
  // Get Relative Time (Localized)
  // ===========================
  /// Returns a user-friendly relative time string.
  /// Needs AppLocalizations to support multi-language.
  static String getRelativeTime(DateTime date, {AppLocalizations? l10n}) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // Fallback if l10n is not provided (e.g. background tasks, though context is usually available in UI)
    // If l10n is null, we might use a default or just return a simple formatted date.
    if (l10n == null) {
       return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }

    final isAr = l10n.localeName == 'ar';

    if (difference.inSeconds < 60) {
      return isAr ? 'الآن' : 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      if (isAr) {
        if (minutes == 1) return 'منذ دقيقة';
        if (minutes == 2) return 'منذ دقيقتين';
        if (minutes <= 10) return 'منذ $minutes دقائق';
        return 'منذ $minutes دقيقة';
      }
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      if (isAr) {
        if (hours == 1) return 'منذ ساعة';
        if (hours == 2) return 'منذ ساعتين';
        if (hours <= 10) return 'منذ $hours ساعات';
        return 'منذ $hours ساعة';
      }
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      if (isAr) {
        if (days == 1) return 'أمس';
        if (days == 2) return 'منذ يومين';
        return 'منذ $days أيام';
      }
      if (days == 1) return 'Yesterday';
      return '$days days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      if (isAr) {
        if (weeks == 1) return 'منذ أسبوع';
        if (weeks == 2) return 'منذ أسبوعين';
        return 'منذ $weeks أسابيع';
      }
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      if (isAr) {
        if (months == 1) return 'منذ شهر';
        if (months == 2) return 'منذ شهرين';
        return 'منذ $months أشهر';
      }
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      if (isAr) {
        if (years == 1) return 'منذ سنة';
        if (years == 2) return 'منذ سنتين';
        return 'منذ $years سنوات';
      }
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }

  // ===========================
  // Check if two dates are the same day
  // ===========================
  /// Checks if two DateTime objects are on the same day.
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // ===========================
  // Check if two dates are in the same month
  // ===========================
  /// Checks if two DateTime objects are in the same month of the same year.
  static bool isSameMonth(DateTime date1, DateTime date2) {
    return date1.year == date2.year && date1.month == date2.month;
  }



  // ===========================
  // Get Current Date String (yyyy-MM-dd)
  // ===========================
  /// Returns the current date formatted as 'yyyy-MM-dd'.
  static String getCurrentDateString() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}
