import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../theme/colors.dart';

/// Chips de músculo y texto de equipo de un ejercicio (mockup de registro en
/// vivo): musculatura objetivo y grupo como chips en mayúsculas y equipo con
/// bullet delante. Widget compartido por la tarjeta de la sesión en vivo y
/// por las tarjetas del editor de rutinas (spec 014, RF-1).
class ExerciseChips extends StatelessWidget {
  final Exercise exercise;

  const ExerciseChips({super.key, required this.exercise});

  Widget _badge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: kOnSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targets = <String>[
      exercise.target,
      if (exercise.muscleGroup != exercise.target) exercise.muscleGroup,
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final target in targets) _badge(target),
        Text(
          '• ${exercise.equipment}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: kOnSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
