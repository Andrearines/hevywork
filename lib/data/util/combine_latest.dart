import 'dart:async';

/// Combina el último valor de [a] y [b] en una emisión por actualización,
/// aplicando [select] (helper propio de la spec 014, RF-14/RNF-3: sin
/// `rxdart` ni `package:async`). Emite solo cuando ambas fuentes han emitido
/// al menos una vez; si una termina o falla, la combinación se cierra o
/// propaga el error con ese mismo resultado. Al cancelar la combinación se
/// desuscriben las dos fuentes.
Stream<R> combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) select,
) {
  return _combineLatest([a, b], (values) {
    return select(values[0] as A, values[1] as B);
  });
}

/// Combina el último valor de tres fuentes con las mismas reglas que
/// [combineLatest2].
Stream<R> combineLatest3<A, B, C, R>(
  Stream<A> a,
  Stream<B> b,
  Stream<C> c,
  R Function(A, B, C) select,
) {
  return _combineLatest([a, b, c], (values) {
    return select(values[0] as A, values[1] as B, values[2] as C);
  });
}

/// Núcleo genérico compartido: guarda el último valor de cada fuente y
/// emite la combinación cuando todas están presentes.
Stream<R> _combineLatest<R>(
  List<Stream<Object?>> sources,
  R Function(List<Object?>) combine,
) {
  late StreamController<R> controller;
  final latest = List<Object?>.filled(sources.length, null);
  final hasValue = List<bool>.filled(sources.length, false);
  final subscriptions = <StreamSubscription<Object?>>[];

  void emit() {
    if (controller.isClosed) return;
    if (hasValue.every((present) => present)) controller.add(combine(latest));
  }

  controller = StreamController<R>(
    onListen: () {
      for (var i = 0; i < sources.length; i++) {
        subscriptions.add(
          sources[i].listen(
            (value) {
              latest[i] = value;
              hasValue[i] = true;
              emit();
            },
            onError: controller.addError,
            onDone: () {
              // Una fuente termina: se cierra la combinación y se desusan
              // las demás para no dejar suscripciones huérfanas.
              if (!controller.isClosed) controller.close();
              for (final subscription in subscriptions) {
                subscription.cancel();
              }
            },
          ),
        );
      }
    },
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
  return controller.stream;
}
