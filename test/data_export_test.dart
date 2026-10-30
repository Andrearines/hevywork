import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/domain/data_export.dart';

void main() {
  test('construye un CSV con cabeceras y escapa comas', () {
    final csv = buildExportCsv(
      workouts: [
        (
          id: 'w1',
          name: 'Empuje, fuerza',
          status: 'finished',
          startedAt: DateTime(2026, 10, 1, 18),
          endedAt: DateTime(2026, 10, 1, 19),
        ),
      ],
      metrics: [
        (
          date: DateTime(2026, 10, 1),
          weightKg: 80.5,
          measuresJson: '{"chest":102.5}',
          notes: null,
        ),
      ],
    );

    expect(csv, contains('workouts'));
    expect(csv, contains('id,name,status,started_at,ended_at'));
    expect(csv, contains('"Empuje, fuerza"'));
    expect(csv, contains('body_metrics'));
    expect(csv, contains('2026-10-01T00:00:00.000'));
    expect(csv, contains('80.5'));
  });

  test('sin datos deja las cabeceras', () {
    final csv = buildExportCsv(workouts: const [], metrics: const []);
    expect(csv, contains('workouts'));
    expect(csv, contains('body_metrics'));
  });
}
