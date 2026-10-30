import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Toggle segmentado tipo píldora (RF-1): contenedor `surfaceContainerLow`
/// con segmentos que se iluminan en `surfaceContainerHighest` al estar
/// seleccionados (designer §7.5). Sin lógica de negocio dentro.
class PillToggle<T> extends StatelessWidget {
  final List<({T value, String label, IconData? icon})> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Si `true` los segmentos se reparten todo el ancho disponible
  /// (RF-5: Registro / Historial); si no, se ajustan a su contenido.
  final bool expand;

  const PillToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    Widget segment(T value, String label, IconData? icon) => _Segment(
          label: label,
          icon: icon,
          selected: value == selected,
          onTap: () => onChanged(value),
          textTheme: textTheme,
        );

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      width: expand ? double.infinity : null,
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          for (final option in options)
            if (expand)
              Expanded(child: segment(option.value, option.label, option.icon))
            else
              segment(option.value, option.label, option.icon),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final TextTheme textTheme;

  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          highlightColor: kSurfaceContainerHigh,
          child: Container(
            constraints: const BoxConstraints(minHeight: 36),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? kSurfaceContainerHighest : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: selected ? kPrimary : kOnSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: selected ? kPrimary : kOnSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}