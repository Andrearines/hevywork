/// Enums compartidos para el chart de progresión (spec 015).
enum ProgressMetric { e1rm, load, volume }

enum ProgressWindow { oneMonth, threeMonths, sixMonths, oneYear, all }

/// Helper puro: devuelve los días de la ventana de progreso.
int progressWindowDays(ProgressWindow window) {
  switch (window) {
    case ProgressWindow.oneMonth:
      return 30;
    case ProgressWindow.threeMonths:
      return 90;
    case ProgressWindow.sixMonths:
      return 180;
    case ProgressWindow.oneYear:
      return 365;
    case ProgressWindow.all:
      return 0;
  }
}

/// Helper puro: filtra puntos por ventana de progreso.
List<({DateTime date, double value})> filterByProgressWindow(
  List<({DateTime date, double value})> points,
  ProgressWindow window, {
  DateTime? now,
}) {
  final windowDays = progressWindowDays(window);
  if (windowDays == 0) return points;
  final nowDate = now ?? DateTime.now();
  final start = nowDate.subtract(Duration(days: windowDays));
  return points.where((point) {
    return !point.date.isBefore(start) && !point.date.isAfter(nowDate);
  }).toList();
}