// PoC temporal del agente hacker — tzprobe.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('probe', () {
    final today = DateTime(2026, 3, 30);
    // ignore: avoid_print
    print('TZ now=${DateTime.now().timeZoneName} today=$today utc=${today.toUtc()}');
    for (var offset = 0; offset < 4; offset++) {
      final day = today.subtract(Duration(days: offset));
      final nextDay = day.add(const Duration(days: 1));
      // ignore: avoid_print
      print('offset=$offset day=$day (${day.toUtc()}) nextDay=$nextDay (${nextDay.toUtc()})');
    }
    final oct = DateTime(2026, 10, 26);
    for (var offset = 0; offset < 3; offset++) {
      final day = oct.subtract(Duration(days: offset));
      final nextDay = day.add(const Duration(days: 1));
      // ignore: avoid_print
      print('OCT offset=$offset day=$day (${day.toUtc()}) nextDay=$nextDay (${nextDay.toUtc()})');
    }
  });
}
