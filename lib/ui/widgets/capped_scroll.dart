import 'package:flutter/material.dart';

/// Lista con alto máximo de `visibleItems` elementos: por debajo del límite
/// se ajusta al contenido y por encima crece con scroll interno (spec 013,
/// RF-13).
class CappedScroll extends StatelessWidget {
  final int itemCount;
  final int visibleItems;
  final double itemHeight;
  final Widget child;

  const CappedScroll({
    super.key,
    required this.itemCount,
    required this.visibleItems,
    required this.itemHeight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount <= visibleItems) return child;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: visibleItems * itemHeight),
      child: SingleChildScrollView(child: child),
    );
  }
}
