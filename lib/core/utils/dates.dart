class Dates {
  Dates._();
  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - 1));

  static DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
}
