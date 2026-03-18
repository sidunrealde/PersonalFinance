abstract final class AppConstants {
  static const int paiseMultiplier = 100;
  static const int syncIntervalSeconds = 30;
  static const int inviteExpiryDays = 7;
  static const int maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  static const List<String> defaultCategories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Health',
    'Entertainment',
    'Education',
    'Miscellaneous',
  ];
}
