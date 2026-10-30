import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/training_calendar.dart';

void main() {
  group('dayOf', () {
    test('descarta la hora para agrupar por día', () {
      expect(dayOf(DateTime(2026, 10, 9, 23, 59)), DateTime(2026, 10, 9));
    });
  });

  group('monthGrid', () {
    test('empieza en lunes y completa semanas con días vecinos', () {
      final grid = monthGrid(DateTime(2026, 10));

      expect(grid.length % 7, 0);
      expect(grid.first.date.weekday, DateTime.monday);
      // Octubre 2026: el día 1 cae en jueves, así que la rejilla arranca el
      // lunes 28/9 y termina el domingo 1/11.
      expect(grid.first.date, DateTime(2026, 9, 28));
      expect(grid.last.date, DateTime(2026, 11, 1));
      expect(grid.length, 35);
    });

    test('marca solo los días del mes como inMonth', () {
      final grid = monthGrid(DateTime(2026, 10));

      expect(grid.where((d) => d.inMonth).length, 31);
      for (final day in grid.where((d) => d.inMonth)) {
        expect(day.date.month, 10);
        expect(day.date.year, 2026);
      }
    });

    test('marca hoy y los días entrenados', () {
      final grid = monthGrid(
        DateTime(2026, 10),
        markers: {DateTime(2026, 10, 9): 'P'},
        today: DateTime(2026, 10, 9, 15, 30),
      );

      final today = grid.firstWhere((d) => d.date == DateTime(2026, 10, 9));
      expect(today.isToday, isTrue);
      expect(today.trained, isTrue);
      expect(today.marker, 'P');

      final other = grid.firstWhere((d) => d.date == DateTime(2026, 10, 8));
      expect(other.isToday, isFalse);
      expect(other.trained, isFalse);
    });
  });

  group('trainedDayMarkers', () {
    test('agrupa por día y usa la inicial mayúscula de la rutina', () {
      final markers = trainedDayMarkers([
        (endedAt: DateTime(2026, 10, 9, 8), routineName: 'push day'),
        (endedAt: DateTime(2026, 10, 9, 20), routineName: 'Pull'),
        (endedAt: DateTime(2026, 10, 10, 8), routineName: null),
        (endedAt: DateTime(2026, 10, 10, 9), routineName: '   '),
      ]);

      // El último marcador del mismo día gana; sin nombre → punto.
      expect(markers[DateTime(2026, 10, 9)], 'P');
      expect(markers[DateTime(2026, 10, 10)], '•');
      expect(markers, hasLength(2));
    });
  });

  group('sessionsInMonth', () {
    test('cuenta solo las sesiones del mes y año indicados', () {
      final count = sessionsInMonth([
        DateTime(2026, 10, 1),
        DateTime(2026, 9, 30, 23, 59),
        DateTime(2026, 10, 31),
        DateTime(2026, 11, 1),
      ], DateTime(2026, 10));

      expect(count, 2);
    });
  });

  group('volumeInMonth', () {
    test('suma solo el volumen del mes indicado', () {
      final volume = volumeInMonth([
        (date: DateTime(2026, 10, 1), volumeKg: 1000),
        (date: DateTime(2026, 9, 30, 23, 59), volumeKg: 500),
        (date: DateTime(2026, 10, 31), volumeKg: 250.5),
      ], DateTime(2026, 10));

      expect(volume, closeTo(1250.5, 0.001));
    });
  });

  group('adherenceRate', () {
    final now = DateTime(2026, 10, 9); // viernes; la semana corre del lunes 5.

    test('las cuatro semanas entrenadas dan 1', () {
      final rate = adherenceRate([
        DateTime(2026, 10, 9),
        DateTime(2026, 9, 30),
        DateTime(2026, 9, 22),
        DateTime(2026, 9, 15),
      ], now);

      expect(rate, 1);
    });

    test('una semana entrenada de cuatro da 0.25', () {
      expect(adherenceRate([DateTime(2026, 10, 9)], now), 0.25);
      // La semana pasada cuenta aunque la actual esté vacía.
      expect(adherenceRate([DateTime(2026, 9, 30)], now), 0.25);
    });

    test('sin sesiones devuelve cero', () {
      expect(adherenceRate(const <DateTime>[], now), 0);
    });

    test('respeta la ventana configurable', () {
      expect(adherenceRate([DateTime(2026, 10, 9)], now, weeks: 1), 1);
      expect(adherenceRate([DateTime(2026, 9, 30)], now, weeks: 1), 0);
    });
  });

  group('monthLabel', () {
    test('combina mes en español y año', () {
      expect(monthLabel(DateTime(2026, 10, 1)), 'Octubre 2026');
      expect(monthLabel(DateTime(2026, 1, 15)), 'Enero 2026');
      expect(monthLabel(DateTime(2026, 12, 31)), 'Diciembre 2026');
    });
  });
}