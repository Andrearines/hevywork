import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/local/database.dart';
import 'package:hevywork/domain/use_cases/fatigue_notifier.dart';

void main() {
  const shortDelay = Duration(milliseconds: 20);

  /// Notifier con [recalculate] espía y fuentes controlables por el test.
  FatigueNotifier buildNotifier(
    List<StreamController<void>> sources,
    List<int> calls, {
    Duration delay = shortDelay,
    Future<void> Function()? recalculate,
    Completer<void>? gate,
  }) {
    var seq = 0;
    return FatigueNotifier(
      sources: [for (final source in sources) source.stream],
      recalculate: recalculate ??
          () {
            calls.add(++seq);
            return gate?.future ?? Future<void>.value();
          },
      delay: delay,
    );
  }

  Future<void> settle() => Future<void>.delayed(
        const Duration(milliseconds: 60),
      );

  group('FatigueNotifier', () {
    test('una ráfaga de N eventos coalesce en un solo recálculo', () async {
      final sources = [StreamController<void>(), StreamController<void>()];
      final calls = <int>[];
      final notifier = buildNotifier(sources, calls);
      addTearDown(notifier.dispose);

      sources[0].add(null);
      sources[0].add(null);
      sources[1].add(null);
      await settle();

      expect(calls, hasLength(1));

      sources[0].add(null);
      await settle();
      expect(calls, hasLength(2), reason: 'un evento posterior reprograma');
    });

    test('flush() ejecuta ya y cancela el recálculo pendiente', () async {
      final sources = [StreamController<void>()];
      final calls = <int>[];
      final notifier = buildNotifier(sources, calls);
      addTearDown(notifier.dispose);

      sources[0].add(null);
      // Deja que drift/el controller entregue el evento: el temporizador
      // queda pendiente y flush debe cancelarlo.
      await Future<void>.delayed(Duration.zero);
      await notifier.flush();

      expect(calls, hasLength(1), reason: 'ejecuta sin esperar al debounce');

      await settle();
      expect(calls, hasLength(1), reason: 'el pendiente quedó cancelado');
    });

    test('flush() sin eventos también ejecuta (cierre de sesión)', () async {
      final sources = [StreamController<void>()];
      final calls = <int>[];
      final notifier = buildNotifier(sources, calls);
      addTearDown(notifier.dispose);

      await notifier.flush();

      expect(calls, hasLength(1));
    });

    test('flush() espera un recálculo en vuelo sin duplicarlo', () async {
      final sources = [StreamController<void>()];
      final calls = <int>[];
      final gate = Completer<void>();
      final notifier = buildNotifier(sources, calls, gate: gate);
      addTearDown(notifier.dispose);

      final first = notifier.flush();
      await Future<void>.delayed(Duration.zero);
      // El segundo flush no duplica el vuelo: se queda esperando al mismo.
      final second = notifier.flush();
      await Future<void>.delayed(Duration.zero);

      expect(calls, hasLength(1), reason: 'sin vuelos duplicados');

      gate.complete();
      await Future.wait([first, second]);
      expect(calls, hasLength(1));
    });

    test('los eventos durante un vuelo se ejecutan tras él', () async {
      final sources = [StreamController<void>()];
      final calls = <int>[];
      final gate = Completer<void>();
      final notifier = buildNotifier(sources, calls, gate: gate);
      addTearDown(notifier.dispose);

      final first = notifier.flush();
      sources[0].add(null);
      await settle();
      expect(calls, hasLength(1), reason: 'el vuelo sigue abierto');

      gate.complete();
      await first;
      await settle();
      expect(calls, hasLength(2), reason: 'el evento llegado en vuelo corre');
    });

    test('markDirty() sin dispose deja el temporizador vivo', () async {
      final sources = [StreamController<void>()];
      final calls = <int>[];
      final notifier = buildNotifier(sources, calls);
      addTearDown(notifier.dispose);

      notifier.markDirty();
      await settle();
      expect(calls, hasLength(1));
    });

    test('dispose() cancela temporizador y suscripciones (sin fugas)', () async {
      final sources = [StreamController<void>(), StreamController<void>()];
      final calls = <int>[];
      final notifier = buildNotifier(sources, calls);

      sources[0].add(null);
      notifier.dispose();

      await settle();
      expect(calls, isEmpty, reason: 'el temporizador pendiente no corre');

      sources[0].add(null);
      await settle();
      expect(calls, isEmpty, reason: 'las fuentes quedaron desuscritas');
      expect(sources[0].hasListener, isFalse);
      expect(sources[1].hasListener, isFalse);

      await notifier.flush();
      expect(calls, isEmpty, reason: 'flush tras dispose es un no-op');

      await sources[0].close();
      await sources[1].close();
    });

    test('un cambio en la tabla de series dispara el recálculo (BD en '
        'memoria)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final calls = <int>[];
      var seq = 0;
      final notifier = FatigueNotifier(
        sources: [
          db.tableUpdates(TableUpdateQuery.onTable(db.workoutSets)),
          db.tableUpdates(TableUpdateQuery.onTable(db.workouts)),
        ],
        recalculate: () async => calls.add(++seq),
        delay: shortDelay,
      );
      addTearDown(notifier.dispose);

      final profile = await (db.select(db.localProfiles).getSingle());

      await db.into(db.workouts).insert(
            WorkoutsCompanion.insert(
              id: 'w-live',
              localUserId: profile.localUserId,
              startedAt: DateTime(2026, 10, 27, 9),
            ),
          );
      await settle();

      expect(calls, hasLength(1), reason: 'workouts es una fuente');

      await db.into(db.workoutExercises).insert(
            WorkoutExercisesCompanion.insert(
              id: 'we-1',
              workoutId: 'w-live',
              exerciseId: 'ex-1',
              orderIndex: 0,
            ),
          );
      await db.into(db.workoutSets).insert(
            WorkoutSetsCompanion.insert(
              id: 'set-1',
              workoutExerciseId: 'we-1',
              orderIndex: 0,
            ),
          );
      await settle();

      expect(calls, hasLength(2), reason: 'workout_sets es una fuente');
    });
  });
}
