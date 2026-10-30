import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Pantalla de reserva para los destinos de navegación cuya spec aún no está
/// implementada.
class SoonView extends StatelessWidget {
  const SoonView({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(color: kOnSurface),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: kOnSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
