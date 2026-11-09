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
  final nowDate = now ?? DateTime.now();
  return points.where((point) {
    if (windowDays == 0) return true;
    final pointDate = point.date;
    return pointDate.difference(nowDate).inDays <= windowDays;
  }).toList();
}