import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DateHelper {
  // ===========================
  // Format Timestamp to String
  // ===========================
  /// Converts a Firestore Timestamp to a formatted string.
  static String formatTimestamp(Timestamp timestamp, {String format = 'dd/MM/yyyy'}) {
    final dateTime = timestamp.toDate();
    return DateFormat(format).format(dateTime);
  }

  // ===========================
  // Format DateTime to String
  // ===========================
  /// Formats a DateTime object into a string.
  static String formatDateTime(DateTime dateTime, {String format = 'dd/MM/yyyy'}) {
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
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  // ===========================
  // Check if Timestamp is Today
  // ===========================
  /// Checks if the given Firestore Timestamp is today.
  static bool isTimestampToday(Timestamp timestamp) {
    return isToday(timestamp.toDate());
  }

  // ===========================
  // Get Relative Time in Arabic
  // ===========================
  /// Returns a user-friendly relative time string in Arabic.
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      if (minutes == 1) return 'منذ دقيقة';
      if (minutes == 2) return 'منذ دقيقتين';
      if (minutes <= 10) return 'منذ $minutes دقائق';
      return 'منذ $minutes دقيقة';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      if (hours == 1) return 'منذ ساعة';
      if (hours == 2) return 'منذ ساعتين';
      if (hours <= 10) return 'منذ $hours ساعات';
      return 'منذ $hours ساعة';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      if (days == 1) return 'أمس';
      if (days == 2) return 'منذ يومين';
      return 'منذ $days أيام';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      if (weeks == 1) return 'منذ أسبوع';
      if (weeks == 2) return 'منذ أسبوعين';
      return 'منذ $weeks أسابيع';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      if (months == 1) return 'منذ شهر';
      if (months == 2) return 'منذ شهرين';
      return 'منذ $months أشهر';
    } else {
      final years = (difference.inDays / 365).floor();
      if (years == 1) return 'منذ سنة';
      if (years == 2) return 'منذ سنتين';
      return 'منذ $years سنوات';
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
  // Convert DateTime to Timestamp
  // ===========================
  /// Converts a DateTime object to a Firestore Timestamp.
  static Timestamp dateTimeToTimestamp(DateTime dateTime) {
    return Timestamp.fromDate(dateTime);
  }

  // ===========================
  // Convert Timestamp to DateTime
  // ===========================
  /// Converts a Firestore Timestamp to a DateTime object.
  static DateTime timestampToDateTime(Timestamp timestamp) {
    return timestamp.toDate();
  }
}
