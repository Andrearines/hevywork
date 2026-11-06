import 'package:flutter/material.dart';

/// Colores de la UI del toggle Frente/Espalda (RF-24).
const Color kToggleSurfaceContainerHigh = Color(0xFFEDEAEA);
const Color kToggleKPrimary = Color(0xFF0061A8);
const Color kToggleKOnSurface = Color(0xFF18181B);
const Color kToggleKOnSurfaceVariant = Color(0xFF86868B);

/// Segmento individual del toggle Frente/Espalda (RF-24).
class _ToggleSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? kToggleKOnSurfaceVariant : kToggleKOnSurface;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggle pill Frente/Espalda del mockup (RF-24), sin sombras.
/// Extraído de `progress_view.dart` de forma neutra: los targets táctiles
/// cumplen ≥ 48 dp y no hay `BoxShadow`/`elevation`.
class ViewToggle extends StatelessWidget {
  final bool showBack;
  final ValueChanged<bool> onChanged;

  const ViewToggle({
    required this.showBack,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: kToggleSurfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            label: 'Frente',
            selected: !showBack,
            onTap: () => onChanged(false),
          ),
          _ToggleSegment(
            label: 'Espalda',
            selected: showBack,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}