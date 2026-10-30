import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Bottom Navigation Bar (plan_desidingIU T-1, RF-36): pill flotante
/// redondeada a 20 dp del borde inferior con margen lateral de 16 dp,
/// `surfaceContainer` al 90 % con blur 24 y borde hairline. Sin sombras
/// (constitución §7). Activo en `primary`, inactivo en `onSurfaceVariant`,
/// labels en `labelSmall` uppercase (designer.md §8.1).
class HevyBottomNav extends StatelessWidget {
  const HevyBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const List<({IconData icon, String label})> destinations = [
    (icon: Icons.fitness_center, label: 'ENTRENAR'),
    (icon: Icons.view_timeline, label: 'RUTINAS'),
    (icon: Icons.query_stats, label: 'PROGRESO'),
    (icon: Icons.person, label: 'PERFIL'),
  ];

  /// Altura de la pill (ítems de 48 dp + padding vertical de 4 dp).
  static const double height = 56;

  /// Distancia desde el borde inferior de la pantalla hasta la pill.
  static const double bottomOffset = 20;

  /// Margen lateral de la pill.
  static const double horizontalInset = 16;

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: horizontalInset,
        right: horizontalInset,
        bottom: bottomInset + bottomOffset,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kSurfaceContainer.withValues(alpha: 0.9),
              border: Border.all(color: kOutlineVariant.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: index == currentIndex,
                        excludeSemantics: true,
                        label: destinations[index].label,
                        child: InkWell(
                          onTap: () => onTap(index),
                          borderRadius: BorderRadius.circular(999),
                          highlightColor: kSurfaceContainerHigh,
                          splashColor: kSurfaceContainerHigh,
                          child: SizedBox(
                            height: 48,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  destinations[index].icon,
                                  size: 22,
                                  color: index == currentIndex
                                      ? kPrimary
                                      : kOnSurfaceVariant,
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    destinations[index].label,
                                    maxLines: 1,
                                    style: textTheme.labelSmall?.copyWith(
                                      color: index == currentIndex
                                          ? kPrimary
                                          : kOnSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
