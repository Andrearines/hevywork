import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Barra horizontal de chips de filtro de selección única (RF-1): píldoras
/// autoajustadas con `surfaceContainerLow`, seleccionado en
/// `surfaceContainerHighest` con texto `primary` (designer §7.5). El padre es
/// dueño del estado; sin lógica de negocio dentro.
class FilterChipBar<T> extends StatelessWidget {
  final List<({T value, String label})> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const FilterChipBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final option = options[index];
          final active = option.value == selected;
          return Semantics(
            button: true,
            selected: active,
            label: option.label,
            child: Material(
              color: active ? kSurfaceContainerHighest : kSurfaceContainerLow,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(option.value),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Center(
                    child: Text(
                      option.label,
                      style: textTheme.labelMedium?.copyWith(
                        color: active ? kPrimary : kOnSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}