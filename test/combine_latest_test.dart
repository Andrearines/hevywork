import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hevywork/data/util/combine_latest.dart';

void main() {
  group('combineLatest2', () {
    test('emite cuando ambas fuentes han emitido y luego con cada valor',
        () async {
      final a = StreamController<int>();
      final b = StreamController<String>();
      addTearDown(() async {
        await a.close();
        await b.close();
      });

      final events = <String>[];
      final sub = combineLatest2(a.stream, b.stream, (x, y) => '$x$y')
          .listen(events.add);
      addTearDown(sub.cancel);

      a.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty, reason: 'falta el valor de b');

      b.add('a');
      await Future<void>.delayed(Duration.zero);
      expect(events, ['1a']);

      a.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(events, ['1a', '2a'], reason: 'usa el último valor de b');
    });

    test('al cancelar la combinación se desusan las fuentes', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      addTearDown(() async {
        await a.close();
        await b.close();
      });

      final sub = combineLatest2(a.stream, b.stream, (x, y) => x + y).listen(
        (_) {},
      );
      await sub.cancel();

      expect(a.hasListener, isFalse);
      expect(b.hasListener, isFalse);
    });

    test('si una fuente termina la combinación se cierra', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      addTearDown(() async {
        await a.close();
        await b.close();
      });

      final events = <int>[];
      var done = false;
      final sub = combineLatest2(a.stream, b.stream, (x, y) => x + y).listen(
        events.add,
        onDone: () => done = true,
      );
      addTearDown(sub.cancel);

      a.add(1);
      b.add(2);
      await a.close();
      await Future<void>.delayed(Duration.zero);

      expect(events, [3]);
      expect(done, isTrue);
    });

    test('un error de una fuente se propaga a la combinación', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      addTearDown(() async {
        await a.close();
        await b.close();
      });

      Object? error;
      final sub = combineLatest2(a.stream, b.stream, (x, y) => x + y).listen(
        (_) {},
        onError: (Object e) => error = e,
      );
      addTearDown(sub.cancel);

      a.addError(StateError('roto'));
      await Future<void>.delayed(Duration.zero);

      expect(error, isA<StateError>());
    });
  });

  group('combineLatest3', () {
    test('emite la terna cuando las tres fuentes han emitido', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      addTearDown(() async {
        await a.close();
        await b.close();
        await c.close();
      });

      final events = <int>[];
      final sub = combineLatest3(
        a.stream,
        b.stream,
        c.stream,
        (x, y, z) => x + y + z,
      ).listen(events.add);
      addTearDown(sub.cancel);

      a.add(1);
      b.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      c.add(3);
      await Future<void>.delayed(Duration.zero);
      expect(events, [6]);

      b.add(10);
      await Future<void>.delayed(Duration.zero);
      expect(events, [6, 14]);
    });
  });
}
