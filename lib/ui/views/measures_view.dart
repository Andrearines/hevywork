import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../domain/body_metrics.dart';
import '../../domain/units.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/measure_evolution.dart';
import 'body_metric_editor_view.dart';

/// Pantalla de medidas (spec 008, RF-25/RF-37, amenda 2026-10-18): el
/// histórico «Medidas Corporales» y la «Evolución de Medidas» viven aquí
/// para que la pestaña Progreso no se alargue en exceso. El «+» de la barra
/// añade un chequeo nuevo; la edición y el borrado siguen en la tabla de
/// registros de Progreso.
class MeasuresView extends StatefulWidget {
  const MeasuresView({super.key});

  @override
  State<MeasuresView> createState() => _MeasuresViewState();
}

class _MeasuresViewState extends State<MeasuresView> {
  late final Stream<List<BodyMetric>> _records =
      bodyMetricRepository.watchRecords();

  Future<void> _addRecord() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BodyMetricEditorView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medidas'),
        actions: [
          IconButton(
            onPressed: _addRecord,
            tooltip: 'Nueva medida',
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<BodyMetric>>(
        stream: _records,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'No se pudieron cargar las medidas',
                style: TextStyle(color: kOnSurfaceVariant),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Cargando...'));
          }
          final records = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              MeasuresSection(records: records),
              MeasureEvolution(records: records),
            ],
          );
        },
      ),
    );
  }
}

/// Sección «Medidas Corporales» (spec 008, RF-25): filas con icono
/// Material Symbols, valor actual y Δ frente al chequeo anterior
/// (designer §7.10), el «último chequeo» en la cabecera y estado vacío
/// (RF-37). La edición vive en la tabla de registros de Progreso.
class MeasuresSection extends StatelessWidget {
  final List<BodyMetric> records;

  const MeasuresSection({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkpoint = latestMeasureCheckpoint(records);
    final rows = buildMeasureRows(records: records);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'Medidas Corporales',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: kOnSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (checkpoint != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'ÚLTIMO CHEQUEO: ${_checkpointLabel(checkpoint.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: kSurfaceContainer,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: rows.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                    child: Text(
                      'Añade medidas a un registro para verlas aquí',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kOnSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const SizedBox(height: 4),
                        _MeasureRowItem(row: rows[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Fila de medida del mockup: círculo con icono, nombre y subtítulo a la
/// izquierda; valor + «cm» y chip de Δ a la derecha. El chip pinta
/// positivo en `kOnSurface`, negativo en `kTertiaryContainer` y
/// sin cambio en `kOnSurfaceVariant` (designer §7.10).
class _MeasureRowItem extends StatelessWidget {
  final MeasureRow row;

  const _MeasureRowItem({required this.row});

  @override
  Widget build(BuildContext context) {
    final unitSystem = UnitSystemScope.of(context);
    final lengthUnit = lengthUnitOf(unitSystem);
    final delta = row.delta;
    final deltaColor = delta == null
        ? kOnSurfaceVariant
        : delta > 0
            ? kOnSurface
            : delta < 0
                ? kTertiaryContainer
                : kOnSurfaceVariant;
    final deltaValue = delta == null ? null : displayLengthCm(delta, unitSystem);
    final deltaText = deltaValue == null
        ? '—'
        : '${deltaValue > 0 ? '+' : ''}${deltaValue.toStringAsFixed(1)} '
            '$lengthUnit';

    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: kSurfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(_measureIcon(row.id), size: 18, color: kOnSurface),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      measureMockupLabel(row.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: kOnSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      measureSubtitle(row.id),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: kOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _fmtValue(displayLengthCm(row.value, unitSystem)),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(width: 3),
                Text(
                  lengthUnit,
                  style: textTheme.labelSmall?.copyWith(color: kSecondary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: kSurfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    deltaText,
                    style: textTheme.labelSmall?.copyWith(color: deltaColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Meses abreviados en mayúsculas para el «ÚLTIMO CHEQUEO» del mockup.
const List<String> _checkpointMonths = [
  'ENE',
  'FEB',
  'MAR',
  'ABR',
  'MAY',
  'JUN',
  'JUL',
  'AGO',
  'SEP',
  'OCT',
  'NOV',
  'DIC',
];

/// «28 FEB»: día y mes abreviado de la cabecera (RF-25).
String _checkpointLabel(DateTime date) =>
    '${date.day} ${_checkpointMonths[date.month - 1]}';

/// Icono Material Symbols de una medida según su nombre del mockup.
IconData _measureIcon(String id) => switch (measureIconName(id)) {
      'sports_gymnastics' => Icons.sports_gymnastics,
      'adjust' => Icons.adjust,
      'directions_run' => Icons.directions_run,
      'accessibility_new' => Icons.accessibility_new,
      _ => Icons.straighten,
    };

/// Formato de un valor medido: sin decimales si es entero, una cifra si no
/// y con separador de miles (mismo criterio que la tarjeta de peso).
String _fmtValue(double value) {
  final text = value % 1 == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return _thousands(text);
}

String _thousands(String digits) {
  final parts = digits.split('.');
  final buffer = StringBuffer();
  for (var i = 0; i < parts[0].length; i++) {
    if (i > 0 && (parts[0].length - i) % 3 == 0) buffer.write('.');
    buffer.write(parts[0][i]);
  }
  if (parts.length > 1) buffer.write('.${parts[1]}');
  return buffer.toString();
}
