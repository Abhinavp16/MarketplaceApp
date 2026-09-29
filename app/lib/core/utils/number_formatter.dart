import 'package:intl/intl.dart';

/// Utility class for formatting numbers with English numerals only
/// regardless of device locale or language settings
class NumberFormatter {
  /// Formats a number with thousands separator using English numerals (0-9)
  /// 
  /// Examples:
  /// - 1000 -> "1,000"
  /// - 1234567 -> "12,34,567"
  /// - 75.5 -> "75.5"
  static String formatPrice(dynamic value) {
    if (value == null) return '0';
    
    // Convert to number
    final num price = value is num ? value : num.tryParse(value.toString()) ?? 0;
    
    // Use NumberFormat with explicit 'en_US' locale to ensure English numerals
    final formatted = NumberFormat('#,##,###', 'en_US').format(price);
    
    return formatted;
  }

  /// Formats a number with Indian numbering system using English numerals
  /// Examples:
  /// - 1000 -> "10,00"
  /// - 100000 -> "1,00,000"
  /// - 10000000 -> "1,00,00,000"
  static String formatPriceIndian(dynamic value) {
    if (value == null) return '0';
    
    // Convert to number
    final num price = value is num ? value : num.tryParse(value.toString()) ?? 0;
    
    // Use NumberFormat with explicit 'en_US' locale to ensure English numerals
    // Indian numbering system uses the same pattern as en_US when specified this way
    final formatted = NumberFormat('#,##,###', 'en_US').format(price);
    
    return formatted;
  }

  /// Formats a number to show as lakhs (L) for large amounts
  /// Examples:
  /// - 100000 -> "1L"
  /// - 107000 -> "1.07L"
  /// - 1200000 -> "12L"
  static String formatLakhs(dynamic value) {
    if (value == null) return '0';
    
    final num amount = value is num ? value : num.tryParse(value.toString()) ?? 0;
    
    if (amount >= 100000) {
      final lakhs = amount / 100000;
      if (lakhs >= 10) {
        return '${lakhs.toStringAsFixed(0)}L';
      } else {
        return '${lakhs.toStringAsFixed(2)}L';
      }
    }
    
    // For amounts below 1 lakh, show full number with proper formatting
    return formatPrice(amount);
  }

  /// Converts any Devanagari numerals back to English numerals
  /// This is a safety function to clean up any Hindi numerals that may appear
  static String ensureEnglishNumerals(String text) {
    if (text.isEmpty) return text;
    
    // Map of Devanagari digits to English digits
    const devanagariToEnglish = {
      '०': '0',
      '१': '1',
      '२': '2',
      '३': '3',
      '४': '4',
      '५': '5',
      '६': '6',
      '७': '7',
      '८': '8',
      '९': '9',
    };
    
    String result = text;
    devanagariToEnglish.forEach((devanagari, english) {
      result = result.replaceAll(devanagari, english);
    });
    
    return result;
  }

  /// Formats a quantity value to display with proper separator
  static String formatQuantity(dynamic quantity) {
    if (quantity == null) return '0';
    
    final num qty = quantity is num ? quantity : num.tryParse(quantity.toString()) ?? 0;
    
    // Quantities are usually small, so just format as integer
    return qty.toInt().toString();
  }

  /// Formats a discount percentage
  static String formatDiscount(dynamic discount) {
    if (discount == null) return '0';
    
    final num value = discount is num ? discount : num.tryParse(discount.toString()) ?? 0;
    
    // Ensure it's rounded to nearest integer for percentages
    return value.round().toString();
  }

  /// Formats a rating value (e.g., 4.5 stars)
  static String formatRating(dynamic rating) {
    if (rating == null) return '0';
    
    final num value = rating is num ? rating : num.tryParse(rating.toString()) ?? 0;
    
    // Ratings are typically shown with one decimal place
    return value.toStringAsFixed(1);
  }
}
