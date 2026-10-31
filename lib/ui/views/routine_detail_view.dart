import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../domain/routine_overview.dart';
import '../../domain/units.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/exercise_thumb.dart';
import '../widgets/section_header.dart';
import 'package:hevywork/ui/views/exercise_info_view.dart';


/// Detalle de una rutina de solo lectura (spec 008, RF-38): metadata de
/// planificación, lista completa de sus ejercicios con la musculatura que
/// trabaja y sus series programadas. Cada ejercicio abre su ficha completa
/// (instrucciones, descanso, media) y se puede entrar a editar o iniciar
/// la sesión desde aquí.
class RoutineDetailView extends StatefulWidget {
  final Routine routine;

  /// Inicia una sesión desde la rutina, igual que desde la lista.
  final Future<void> Function() onStart;

  /// Abre el editor de esta rutina; al volver se recarga el detalle.
  final Future<void> Function() onEdit;

  const RoutineDetailView({
    super.key,
    required this.routine,
    required this.onStart,
    required this.onEdit,
  });

  @override
  State<RoutineDetailView> createState() => _RoutineDetailViewState();
}

/// Ejercicio de la rutina con sus series planificadas; `exercise` es null
/// si ya no está en el catálogo local (caso límite de la 004).
typedef _RoutineEntry = ({Exercise? exercise, List<RoutineSet> sets});

class _RoutineDetailViewState extends State<RoutineDetailView> {
  List<_RoutineEntry> _entries = const [];
  Routine? _routine;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _routine = widget.routine;
    _load();
  }

  Future<void> _load() async {
    final routine =
        await routineRepository.getRoutine(widget.routine.id) ?? widget.routine;
    final rows = await routineRepository.routineExercises(routine.id);
    final entries = <_RoutineEntry>[];
    for (final row in rows) {
      final sets = await routineRepository.routineSets(row.item.id);
      entries.add((exercise: row.exercise, sets: sets));
    }
    if (!mounted) return;
    setState(() {
      _routine = routine;
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final routine = _routine ?? widget.routine;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: kOnSurface),
        title: Text(
          routine.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: kOnSurface,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('routine-detail-edit'),
            tooltip: 'Editar rutina',
            onPressed: () async {
              await widget.onEdit();
              if (!mounted) return;
              await _load();
            },
            icon: const Icon(Icons.tune, size: 20, color: kOnSurface),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: Text(
                'Cargando rutina...',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (routine.description != null) ...[
                  Text(
                    routine.description!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: kOnSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _PlanningMeta(routine: routine),
                SectionHeader(
                  title: 'EJERCICIOS (${_entries.length})',
                  trailing: _setsPill(_totalSets, textTheme),
                ),
                if (_entries.isEmpty)
                  const _EmptyDetail()
                else
                  for (final entry in _entries) _ExerciseCard(entry: entry),
              ],
            ),
      bottomNavigationBar: _loading || _entries.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  key: const Key('routine-detail-start'),
                  onPressed: widget.onStart,
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: kOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Iniciar Hoy'),
                ),
              ),
            ),
    );
  }

  int get _totalSets {
    var total = 0;
    for (final entry in _entries) {
      total += entry.sets.length;
    }
    return total;
  }
}

Widget _setsPill(int totalSets, TextTheme textTheme) {
  final label = totalSets == 1 ? '1 serie' : '$totalSets series';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: kSurfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: textTheme.labelSmall?.copyWith(
        color: kOnSurface,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Chips de la metadata de planificación de la rutina (RF-18); sin metadata
/// no pinta nada para no dejar huecos.
class _PlanningMeta extends StatelessWidget {
  final Routine routine;

  const _PlanningMeta({required this.routine});

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      if (routine.category != null) routine.category!,
      if (routine.level != null) routine.level!,
      if (routine.goal != null) routine.goal!,
      if (routine.targetDays != null)
        routine.targetDays == 1
            ? '1 día / semana'
            : '${routine.targetDays} días / semana',
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final chip in chips) _MetaChip(label: chip)],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: kSurfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: kOnSurfaceVariant,
        ),
      ),
    );
  }
}

/// Tarjeta de un ejercicio de la rutina: miniatura, nombre, musculatura
/// objetivo y resumen de las series programadas. Al tocar se abre la ficha
/// completa del ejercicio.
class _ExerciseCard extends StatelessWidget {
  final _RoutineEntry entry;

  const _ExerciseCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final exercise = entry.exercise;
    final unitSystem = UnitSystemScope.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: exercise == null
              ? null
              : Key('routine-detail-exercise-${exercise.id}'),
          onTap: exercise == null ? null : () => _openExercise(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: kSurfaceContainerHighest),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (exercise != null) ...[
                  ExerciseThumb(exercise: exercise),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise?.name ?? 'Ejercicio no disponible',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge?.copyWith(
                          color: exercise == null
                              ? kOnSurfaceVariant
                              : kOnSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (exercise != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _chipsOf(exercise),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: kOnSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          setsSummary(entry.sets, unitSystem),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: kPrimary,
                          ),
                        ),
                      ] else
                        Text(
                          'No se incluirá al iniciar',
                          style: textTheme.labelSmall?.copyWith(
                            color: kOnSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: kOnSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openExercise(BuildContext context) {
    final exercise = entry.exercise;
    if (exercise == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExerciseInfoView(exercise: exercise),
      ),
    );
  }

  /// Objetivo muscular traducido y equipo, en la misma línea que las tarjetas
  /// de la sesión en vivo.
  String _chipsOf(Exercise exercise) {
    final parts = <String>[muscleTargetLabel(exercise.target)];
    if (exercise.equipment.isNotEmpty) parts.add(exercise.equipment);
    return parts.join(' · ');
  }
}

/// Resumen legible de las series programadas: nº de series, reps, RIR, peso
/// y descanso, colapsando los rangos variables («8-12 reps»). El peso va en
/// la unidad del perfil; las series de peso corporal no lo muestran.
String setsSummary(List<RoutineSet> sets, String unitSystem) {
  if (sets.isEmpty) return 'Sin series planificadas';
  final count = sets.length == 1 ? '1 serie' : '${sets.length} series';

  String range(List<int> values) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    return min == max ? '$min' : '$min-$max';
  }

  final parts = <String>[
    count,
    '${range([for (final set in sets) set.reps])} reps',
    'RIR ${range([for (final set in sets) set.rir])}',
  ];

  final weights = <int>{
    for (final set in sets)
      if (set.weightKg > 0) (set.weightKg * 10).round(),
  };
  if (weights.isNotEmpty) {
    final values = weights.toList();
    final min = formatWeightKg(
      values.reduce((a, b) => a < b ? a : b) / 10,
      unitSystem,
    );
    final max = formatWeightKg(
      values.reduce((a, b) => a > b ? a : b) / 10,
      unitSystem,
    );
    parts.add(
      min == max
          ? '$min ${weightUnitOf(unitSystem)}'
          : '$min-$max ${weightUnitOf(unitSystem)}',
    );
  }

  final rests = <int>{
    for (final set in sets)
      if (set.restSeconds != null) set.restSeconds!,
  };
  if (rests.isNotEmpty) {
    final values = rests.toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    parts.add(min == max ? 'Descanso $min s' : 'Descanso $min-$max s');
  }

  return parts.join(' · ');
}

/// Estado vacío de la rutina sin ejercicios (caso límite de la 004).
class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: const [
            Icon(Icons.fitness_center, size: 32, color: kOnSurfaceVariant),
            SizedBox(height: 12),
            Text(
              'Esta rutina aún no tiene ejercicios',
              textAlign: TextAlign.center,
              style: TextStyle(color: kOnSurface, fontSize: 14),
            ),
            SizedBox(height: 4),
            Text(
              'Ábrela en el editor para añadirlos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
