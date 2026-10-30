import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Cluster de métricas (RF-1): fila única de tarjetas o rejilla de
/// [columns] columnas cuando hay más de tres (mockup Entrenar: 2×2).
/// Solo presenta texto; sin lógica de negocio.
class MetricCluster extends StatelessWidget {
  final List<({String label, String value})> metrics;

  /// Columnas de la rejilla; si es `null` las métricas van en una sola fila.
  final int? columns;

  /// Barras de progreso opcionales (0–1) alineadas con [metrics]; `null`
  /// deja la celda sin barra.
  final List<double?>? progresses;

  const MetricCluster({
    super.key,
    required this.metrics,
    this.columns,
    this.progresses,
  });

  @override
  Widget build(BuildContext context) {
    final perRow = columns ?? metrics.length;
    final rows = <List<({String label, String value})>>[];
    for (var i = 0; i < metrics.length; i += perRow) {
      rows.add(metrics.sublist(
        i,
        i + perRow > metrics.length ? metrics.length : i + perRow,
      ));
    }

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < rows[r].length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: rows[r][i].label,
                    value: rows[r][i].value,
                    progress: progresses == null
                        ? null
                        : progresses![r * perRow + i],
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final double? progress;

  const _MetricTile({
    required this.label,
    required this.value,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: textTheme.headlineSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: kOnSurfaceVariant),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            _ProgressBar(value: progress!),
          ],
        ],
      ),
    );
  }
}

/// Barra de progreso (designer §7.8, alto 4 dp según el mockup): track
/// `surfaceContainerHighest` y fill `primary`, animada 500 ms.
class _ProgressBar extends StatelessWidget {
  final double value;

  const _ProgressBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      builder: (context, fraction, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 4,
          color: kSurfaceContainerHighest,
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            heightFactor: 1,
            child: Container(color: kPrimary),
          ),
        ),
      ),
    );
  }
}