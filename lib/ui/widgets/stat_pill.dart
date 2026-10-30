import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Píldora de una estadística con icono opcional (RF-1): fondo
/// `surfaceContainerLow`, radio 8 dp, texto de etiqueta en `onSurfaceVariant`
/// y valor destacado en `primary` (mockup «Sesión previa: X kg × Y»). Sin
/// lógica de negocio dentro.
class StatPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final String? detail;

  const StatPill({
    super.key,
    this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: kSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: kOnSurfaceVariant),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: kPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(width: 4),
            Text(
              detail!,
              style: textTheme.labelSmall?.copyWith(color: kSecondary),
            ),
          ],
        ],
      ),
    );
  }
}