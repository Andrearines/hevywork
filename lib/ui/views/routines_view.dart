import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/routine_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/routine_overview.dart';
import '../../domain/training_calendar.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../widgets/exercise_thumb.dart';
import 'live_workout_view.dart';
import 'routine_detail_view.dart';
import 'routine_editor_view.dart';
import 'templates_view.dart';

/// Lista de rutinas (spec 004 + spec 008, RF-19 a RF-21): header con CTA,
/// indicador de ciclo semanal, chips de filtro, tarjeta destacada con
/// desglose de sesiones, tarjetas secundarias y tarjeta de exploración.
class RoutinesView extends StatefulWidget {
  const RoutinesView({super.key});

  @override
  State<RoutinesView> createState() => _RoutinesViewState();
}

class _RoutinesViewState extends State<RoutinesView> {
  List<Routine> _routines = const [];
  Map<String, int> _counts = const {};
  Map<String, RoutineSetsStats> _setStats = const {};
  Map<String, DateTime> _lastUsed = const {};
  List<({RoutineExercise item, Exercise exercise})> _catalog = const [];
  Workout? _activeWorkout;
  List<WorkoutSummary> _history = const [];
  bool _ready = false;
  bool _busy = false;

  /// Clave de filtro de categoría (vacío = Todas).
  String _filter = '';

  final List<StreamSubscription<Object?>> _subs = [];

  @override
  void initState() {
    super.initState();
    _listen(routineRepository.watchRoutines(), (List<Routine> value) {
      _routines = value;
      _ready = true;
    });
    _listen(routineRepository.watchExerciseCounts(), (Map<String, int> value) {
      _counts = value;
    });
    _listen(
      routineRepository.watchRoutineSetsStats(),
      (Map<String, RoutineSetsStats> value) => _setStats = value,
    );
    _listen(routineRepository.watchLastUsed(), (Map<String, DateTime> value) {
      _lastUsed = value;
    });
    _listen(
      routineRepository.watchRoutineCatalog(),
      (List<({RoutineExercise item, Exercise exercise})> value) =>
          _catalog = value,
    );
    _listen(workoutRepository.watchActiveWorkout(), (Workout? value) {
      _activeWorkout = value;
    });
    _listen(
      workoutRepository.watchFinishedWorkouts(),
      (List<WorkoutSummary> value) => _history = value,
    );
  }

  void _listen<T>(Stream<T> stream, void Function(T) onData) {
    _subs.add(
      stream.listen((value) {
        if (!mounted) return;
        setState(() => onData(value));
      }),
    );
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }

  Future<void> _openEditor([Routine? routine]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineEditorView(
          routine: routine,
        ),
      ),
    );
  }

  /// Detalle de solo lectura de la rutina (RF-38). Al volver de editar se
  /// recarga solo: el stream de rutinas ya refleja el cambio en la lista.
  Future<void> _openDetail(Routine routine) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoutineDetailView(
          routine: routine,
          onStart: () => _startRoutine(routine),
          onEdit: () => _openEditor(routine),
        ),
      ),
    );
  }

  Future<void> _exploreTemplates() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const TemplatesView()));
  }

  Future<void> _startRoutine(Routine routine) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await routineRepository.startWorkoutFromRoutine(
        routine.id,
      );
      if (!mounted) return;
      if (result.skippedExercises > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.skippedExercises} ejercicio(s) de la rutina no '
              'están disponibles',
            ),
          ),
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LiveWorkoutView(workoutId: result.workout.id),
        ),
      );
    } on EmptyRoutineException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteRoutine(Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kSurfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: kSurfaceContainerHighest),
        ),
        title: const Text('Borrar rutina'),
        content: Text('¿Borrar "${routine.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: kError),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await routineRepository.deleteRoutine(routine.id);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(
        child: Text(
          'Cargando rutinas...',
          style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
        ),
      );
    }

    final header = _header();
    if (_routines.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [header, const _EmptyRoutines()],
      );
    }

    final now = DateTime.now();
    final activeRoutineId = _activeWorkout?.routineId;
    final ordered = [..._routines]
      ..sort((a, b) {
        final aActive = a.id == activeRoutineId ? 0 : 1;
        final bActive = b.id == activeRoutineId ? 0 : 1;
        if (aActive != bActive) return aActive - bActive;
        final aLast = _lastUsed[a.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bLast = _lastUsed[b.id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final byLast = bLast.compareTo(aLast);
        if (byLast != 0) return byLast;
        return b.createdAt.compareTo(a.createdAt);
      });
    final filtered = _filter.isEmpty
        ? ordered
        : [
            for (final routine in ordered)
              if (normalizeCategory(routine.category) == _filter) routine,
          ];

    final week = weekStart(now);
    final sessionsThisWeek = _history
        .where((s) => !s.endedAt.isBefore(week))
        .length;
    final firstSession = _history.isEmpty
        ? null
        : _history
              .map((s) => s.endedAt)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final cycleWeek = firstSession == null
        ? 1
        : now.difference(firstSession).inDays ~/ 7 + 1;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        header,
        _CycleCard(
          week: cycleWeek,
          done: sessionsThisWeek,
          goal: ordered.first.targetDays ?? 4,
        ),
        const SizedBox(height: 12),
        _FilterChips(
          total: _routines.length,
          selected: _filter,
          onSelected: (key) => setState(() => _filter = key),
        ),
        const SizedBox(height: 4),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No hay rutinas en esta categoría',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            ),
          )
        else ...[
          _FeaturedCard(
            routine: filtered.first,
            active: filtered.first.id == activeRoutineId,
            exerciseCount: _counts[filtered.first.id] ?? 0,
            stats: _setStats[filtered.first.id],
            breakdown: _breakdownOf(filtered.first),
            exercises: _exercisesOf(filtered.first),
            onDetail: () => _openDetail(filtered.first),
            onEdit: () => _openEditor(filtered.first),
            onDelete: () => _deleteRoutine(filtered.first),
            onTrain: () => _startRoutine(filtered.first),
          ),
          for (final routine in filtered.skip(1))
            _SecondaryCard(
              routine: routine,
              exerciseCount: _counts[routine.id] ?? 0,
              stats: _setStats[routine.id],
              lastUsed: _lastUsed[routine.id],
              exercises: _exercisesOf(routine),
              onDetail: () => _openDetail(routine),
              onEdit: () => _openEditor(routine),
              onDelete: () => _deleteRoutine(routine),
            ),
        ],
        _ExploreCard(onTap: _exploreTemplates),
      ],
    );
  }

  List<SessionRow> _breakdownOf(Routine routine) {
    final exercises = [
      for (final row in _catalog)
        if (row.item.routineId == routine.id)
          (muscleGroup: row.exercise.muscleGroup, target: row.exercise.target),
    ];
    return buildSessionBreakdown(
      exercises: exercises,
      targetDays: routine.targetDays,
    );
  }

  /// Ejercicios de la rutina en su orden, para la franja de miniaturas.
  List<Exercise> _exercisesOf(Routine routine) => [
    for (final row in _catalog)
      if (row.item.routineId == routine.id) row.exercise,
  ];

  Widget _header() {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PLANIFICACIÓN',
                  style: textTheme.labelSmall?.copyWith(
                    color: kOnSurfaceVariant,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Mis Rutinas',
                  style: textTheme.headlineSmall?.copyWith(
                    color: kOnSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Organiza tus programas de entrenamiento',
                  style: textTheme.bodyMedium?.copyWith(
                    color: kOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 40,
            child: FilledButton.icon(
              onPressed: () => _openEditor(),
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: kOnPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Nueva'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invitación cuando no hay rutinas (RF-1 de la spec 004, intacta).
class _EmptyRoutines extends StatelessWidget {
  const _EmptyRoutines();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fitness_center,
              size: 40,
              color: kOnSurfaceVariant,
            ),
            const SizedBox(height: 12),
            const Text(
              'Aún no tienes rutinas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kOnSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Crea una plantilla con tus ejercicios y entrena con ella.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RoutineEditorView(),
                  ),
                ),
                child: const Text('Nueva rutina'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Indicador de ciclo semanal (RF-19): semana del ciclo, sesiones
/// completadas de la semana y un punto por sesión objetivo.
class _CycleCard extends StatelessWidget {
  final int week;
  final int done;
  final int goal;

  const _CycleCard({
    required this.week,
    required this.done,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dots = goal.clamp(1, 7);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kSurfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.calendar_today,
                size: 20,
                color: kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ciclo Activo: Semana $week',
                    style: textTheme.labelLarge?.copyWith(
                      color: kOnSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$done de $goal sesiones completadas esta semana',
                    style: textTheme.labelSmall?.copyWith(
                      color: kOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                for (var i = 0; i < dots; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i < done ? kPrimary : kSurfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chips de filtro por categoría (RF-19), desplazables en horizontal.
class _FilterChips extends StatelessWidget {
  final int total;
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChips({
    required this.total,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(context, label: 'Todas ($total)', value: ''),
          for (final filter in kRoutineCategoryFilters)
            _chip(context, label: filter.label, value: filter.key),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isSelected = selected == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        key: ValueKey('routine-filter-$value'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelected(value),
        child: Semantics(
          button: true,
          selected: isSelected,
          label: 'Filtro $label',
          child: Container(
            height: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? kSurfaceContainerHighest
                  : kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: textTheme.labelMedium?.copyWith(
                color: isSelected ? kOnSurface : kOnSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta destacada de la rutina (RF-20): franja de acento, badge
/// «En curso», matriz de métricas, desglose de sesiones y acciones.
class _FeaturedCard extends StatelessWidget {
  final Routine routine;
  final bool active;
  final int exerciseCount;
  final RoutineSetsStats? stats;
  final List<SessionRow> breakdown;
  final List<Exercise> exercises;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTrain;

  const _FeaturedCard({
    required this.routine,
    required this.active,
    required this.exerciseCount,
    required this.stats,
    required this.breakdown,
    required this.exercises,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onTrain,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final avg = stats == null
        ? 0
        : avgSetsPerSession(
            totalSets: stats!.totalSets,
            exerciseCount: exerciseCount,
          );
    final cells = <(String, String)>[
      if (routine.targetDays != null)
        ('Frecuencia', '${routine.targetDays} d/sem'),
      if (avg > 0) ('Volumen Medio', avg == 1 ? '1 serie' : '$avg series'),
      if (routine.goal != null) ('Objetivo', routine.goal!),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimary, kSecondary, Colors.transparent],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (active || routine.targetDays != null)
                      Row(
                        children: [
                          if (active) ...[
                            const _ActiveBadge(),
                            if (routine.targetDays != null)
                              const SizedBox(width: 8),
                          ],
                          if (routine.targetDays != null)
                            Text(
                              'Frecuencia ${routine.targetDays}x',
                              style: textTheme.labelSmall?.copyWith(
                                color: kOnSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    if (active || routine.targetDays != null)
                      const SizedBox(height: 8),
                    Text(
                      routine.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        color: kOnSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoutineMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          if (cells.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: kSurfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < cells.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCell(
                        label: cells[i].$1,
                        value: cells[i].$2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ExerciseThumbStrip(exercises: exercises),
          ],
          const SizedBox(height: 12),
          if (breakdown.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kSurfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sin ejercicios — ábrelos para empezar',
                style: textTheme.labelSmall?.copyWith(color: kOnSurfaceVariant),
              ),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DESGLOSE DE SESIONES',
                  style: textTheme.labelSmall?.copyWith(
                    color: kOnSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
                TextButton.icon(
                  key: const Key('featured-detail'),
                  onPressed: onDetail,
                  style: TextButton.styleFrom(
                    backgroundColor: kSurfaceContainer,
                    foregroundColor: kOnSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Ver detalle'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (var i = 0; i < breakdown.length; i++)
              _SessionRowTile(row: breakdown[i], index: i),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: breakdown.isEmpty
                    ? Tooltip(
                        message: 'Añade ejercicios a la rutina',
                        child: const _StartButton(
                          label: 'Iniciar Hoy',
                          onPressed: null,
                        ),
                      )
                    : _StartButton(
                        label: 'Iniciar Hoy (${breakdown.first.title})',
                        onPressed: onTrain,
                      ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: 'Editar rutina',
                  onPressed: onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: kSurfaceContainer,
                    foregroundColor: kOnSurface,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.tune, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Badge «En curso»: solo si hay un workout activo con esa rutina (RF-20).
class _ActiveBadge extends StatelessWidget {
  const _ActiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: kPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'EN CURSO',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: kPrimary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.labelSmall?.copyWith(color: kOnSurfaceVariant),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            color: kOnSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Fila del desglose: número, enfoque, músculos y día asignado.
class _SessionRowTile extends StatelessWidget {
  final SessionRow row;
  final int index;

  const _SessionRowTile({required this.row, required this.index});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 0 ? kSurfaceBright : kSurfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${index + 1}',
              style: textTheme.labelMedium?.copyWith(
                color: index == 0 ? kPrimary : kOnSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: kOnSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  row.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: kOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            row.dayLabel,
            style: textTheme.labelSmall?.copyWith(color: kOnSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _StartButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: kOnPrimary,
          disabledBackgroundColor: kSurfaceContainerHighest,
          disabledForegroundColor: kOnSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_arrow, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta secundaria (RF-20): etiqueta de nivel, descripción, pills de
/// métricas y footer con el último uso y «Ver detalle».
class _SecondaryCard extends StatelessWidget {
  final Routine routine;
  final int exerciseCount;
  final RoutineSetsStats? stats;
  final DateTime? lastUsed;
  final List<Exercise> exercises;
  final VoidCallback onDetail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SecondaryCard({
    required this.routine,
    required this.exerciseCount,
    required this.stats,
    required this.lastUsed,
    required this.exercises,
    required this.onDetail,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = routine.level ?? routine.goal ?? routine.category;
    final avg = stats == null
        ? 0
        : avgSetsPerSession(
            totalSets: stats!.totalSets,
            exerciseCount: exerciseCount,
          );
    final rir = stats == null
        ? null
        : rirRangeLabel(stats!.minRir, stats!.maxRir);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != null)
                      Text(
                        label.toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: kOnSurfaceVariant,
                          letterSpacing: 0.8,
                        ),
                      ),
                    if (label != null) const SizedBox(height: 3),
                    Text(
                      routine.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: kOnSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoutineMenu(onEdit: onEdit, onDelete: onDelete),
            ],
          ),
          if (routine.description != null) ...[
            const SizedBox(height: 8),
            Text(
              routine.description!,
              style: textTheme.bodyMedium?.copyWith(color: kOnSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (routine.targetDays != null)
                _MetricPill(
                  icon: Icons.event_repeat,
                  label: routine.targetDays == 1
                      ? '1 día / semana'
                      : '${routine.targetDays} días / semana',
                ),
              if (avg > 0)
                _MetricPill(
                  icon: Icons.layers,
                  label: avg == 1 ? '1 serie / sesión' : '$avg series / sesión',
                ),
              if (routine.goal != null)
                _MetricPill(icon: Icons.bolt, label: routine.goal!)
              else if (rir != null)
                _MetricPill(icon: Icons.speed, label: rir),
            ],
          ),
          if (exercises.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ExerciseThumbStrip(exercises: exercises),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.only(top: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kSurfaceContainerHighest)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (lastUsed != null)
                  Text(
                    lastUsedFooter(lastUsed!)!,
                    style: textTheme.labelSmall?.copyWith(
                      color: kOnSurfaceVariant,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                TextButton.icon(
                  key: const Key('secondary-detail'),
                  onPressed: onDetail,
                  style: TextButton.styleFrom(
                    backgroundColor: kSurfaceContainer,
                    foregroundColor: kOnSurface,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Ver detalle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Franja de miniaturas de los ejercicios de una rutina (amenda 2026-10-22):
/// muestra los primeros [_visible] y, si quedan más, un contador «+N».
/// Usa `Wrap` en vez de `Row` para no desbordar en móvil estrecho ni con
/// texto escalado; es plana, sin sombras, con el radio del resto de thumbs.
class _ExerciseThumbStrip extends StatelessWidget {
  /// Cuántas miniaturas se muestran antes del contador «+N».
  static const int _visible = 4;

  final List<Exercise> exercises;

  const _ExerciseThumbStrip({required this.exercises});

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) return const SizedBox.shrink();
    final visible = exercises.take(_visible).toList();
    final hidden = exercises.length - visible.length;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final exercise in visible)
          ExerciseThumb(exercise: exercise, size: 44),
        if (hidden > 0) _MoreThumb(count: hidden),
      ],
    );
  }
}

/// Contador «+N» con la forma de una miniatura, para el resto de ejercicios.
class _MoreThumb extends StatelessWidget {
  final int count;

  const _MoreThumb({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$count',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: kOnSurfaceVariant, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: kOnSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: kOnSurface),
          ),
        ],
      ),
    );
  }
}

/// Menú «…» de la tarjeta: editar o borrar (comportamiento de la 004).
class _RoutineMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        tooltip: 'Opciones de la rutina',
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.more_horiz, size: 20, color: kOnSurfaceVariant),
        onSelected: (value) {
          if (value == 'edit') {
            onEdit();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Editar')),
          PopupMenuItem(value: 'delete', child: Text('Borrar')),
        ],
      ),
    );
  }
}

/// Tarjeta «Explorar Biblioteca de Plantillas» (RF-21), enlaza a la spec
/// 010 que aún no existe.
class _ExploreCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ExploreCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.explore, size: 20, color: kPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explorar Biblioteca de Plantillas',
                      style: textTheme.titleSmall?.copyWith(
                        color: kOnSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Programas verificados de hipertrofia y fuerza',
                      style: textTheme.labelSmall?.copyWith(
                        color: kOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward,
                size: 20,
                color: kOnSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
