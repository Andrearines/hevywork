import 'package:flutter/widgets.dart';

/// Sistema de unidades del perfil (spec 008, RF-29) inyectado sobre el
/// `Navigator` para que todas las pantallas y rutas empujadas lo lean con
/// `UnitSystemScope.of(context)`. Sin scope (tests, arranque) el sistema es
/// métrico.
class UnitSystemScope extends InheritedWidget {
  final String unitSystem;

  const UnitSystemScope({
    super.key,
    required this.unitSystem,
    required super.child,
  });

  static String of(BuildContext context) => context
          .dependOnInheritedWidgetOfExactType<UnitSystemScope>()
          ?.unitSystem ??
      'metric';

  @override
  bool updateShouldNotify(UnitSystemScope oldWidget) =>
      unitSystem != oldWidget.unitSystem;
}
