import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../domain/media.dart';
import '../theme/colors.dart';

/// Miniatura local del ejercicio (constitución §9: JPG empaquetados).
class ExerciseThumb extends StatelessWidget {
  final Exercise exercise;
  final double size;
  final double radius;

  const ExerciseThumb({
    super.key,
    required this.exercise,
    this.size = 48,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = exercise.imagePath;
    final cacheSize = (size * MediaQuery.of(context).devicePixelRatio).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: imagePath == null
            ? const ThumbFallback()
            : Image.asset(
                thumbAsset(imagePath),
                fit: BoxFit.cover,
                cacheWidth: cacheSize,
                cacheHeight: cacheSize,
                errorBuilder: (_, _, _) => const ThumbFallback(),
              ),
      ),
    );
  }
}

class ThumbFallback extends StatelessWidget {
  final double radius;

  const ThumbFallback({super.key, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.fitness_center,
        size: 20,
        color: kOnSurfaceVariant,
      ),
    );
  }
}
