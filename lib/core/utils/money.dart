/// Immutable value object representing monetary amounts in integer paise.
/// ₹1 = 100 paise. All arithmetic is integer-based to avoid floating point errors.
class Money implements Comparable<Money> {
  const Money(this.paise);

  factory Money.fromRupees(double rupees) {
    return Money((rupees * 100).round());
  }

  final int paise;

  static const Money zero = Money(0);

  double get rupees => paise / 100;

  /// Formats as Indian currency: ₹1,23,456.78
  String format() {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupeesPart = absPaise ~/ 100;
    final paisePart = absPaise % 100;

    // Indian grouping: last 3, then groups of 2
    final rupeesStr = _indianGrouping(rupeesPart);
    final paiseStr = paisePart.toString().padLeft(2, '0');

    return '${isNegative ? '-' : ''}₹$rupeesStr.$paiseStr';
  }

  static String _indianGrouping(int value) {
    if (value < 1000) return value.toString();

    final str = value.toString();
    final lastThree = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);

    // Group remaining digits in pairs from right
    final buffer = StringBuffer();
    for (var i = remaining.length; i > 0; i -= 2) {
      final start = i - 2 < 0 ? 0 : i - 2;
      if (buffer.isNotEmpty) {
        buffer.write(',${remaining.substring(start, i)}');
      } else {
        buffer.write(remaining.substring(start, i));
      }
    }

    // Reverse the comma-separated groups
    final groups = buffer.toString().split(',').reversed.join(',');
    return '$groups,$lastThree';
  }

  Money operator +(Money other) => Money(paise + other.paise);
  Money operator -(Money other) => Money(paise - other.paise);
  Money operator -() => Money(-paise);

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Money && paise == other.paise;

  @override
  int get hashCode => paise.hashCode;

  @override
  String toString() => format();
}
