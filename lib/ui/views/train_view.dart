import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/local/database.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/routine_repository.dart';
import '../../domain/training_calendar.dart';
import '../../domain/units.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/metric_cluster.dart';
import '../widgets/pill_toggle.dart';
import 'live_workout_view.dart';
import 'past_workout_editor_view.dart';

/// Modo del panel Entrenar (RF-5): registro de una sesión o historial con
/// calendario.
enum TrainMode { register, history }

/// Panel de Entrenar (spec 008, RF-5 a RF-11): toggle Registro/Historial,
/// tarjeta de sesión activa con «Reanudar», calendario mensual con marcadores,
/// cluster de métricas y feed de sesiones recientes. El catálogo vive en una
/// pantalla propia (RF-10), accesible desde el icono del header.
class TrainView extends StatefulWidget {
  const TrainView({super.key});

  @override
  State<TrainView> createState() => _TrainViewState();
}

class _TrainViewState extends State<TrainView> {
  late final Stream<Workout?> _activeWorkout =
      workoutRepository.watchActiveWorkout();
  late final Stream<List<WorkoutSummary>> _history =
      workoutRepository.watchFinishedWorkouts();

  TrainMode _mode = TrainMode.history;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> _openSession(String workoutId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveWorkoutView(workoutId: workoutId),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _startNewSession() async {
    final workout = await workoutRepository.startWorkout();
    if (!mounted) return;
    await _openSession(workout.id);
  }

  Future<void> _repeatSession(WorkoutSummary summary) async {
    final result = await routineRepository.startWorkoutFromRoutine(
      summary.routineId!,
    );
    if (!mounted) return;
    await _openSession(result.workout.id);
  }

  Future<void> _deleteSession(WorkoutSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kSurfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: kSurfaceContainerHighest),
        ),
        title: const Text('Borrar sesión'),
        content: Text('¿Borrar la sesión "${_dayLabel(summary.endedAt)}"?'),
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
    await workoutRepository.deleteWorkout(summary.id);
  }

  void _shiftMonth(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PillToggle<TrainMode>(
            expand: true,
            selected: _mode,
            onChanged: (mode) => setState(() => _mode = mode),
            options: const [
              (
                value: TrainMode.register,
                label: 'Registro en Vivo',
                icon: Icons.play_circle_outline,
              ),
              (
                value: TrainMode.history,
                label: 'Historial & Calendario',
                icon: Icons.calendar_month_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<Workout?>(
          stream: _activeWorkout,
          builder: (context, snapshot) {
            final active = snapshot.data;
            if (active == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ActiveSessionCard(
                workout: active,
                onResume: () => _openSession(active.id),
              ),
            );
          },
        ),
        if (_mode == TrainMode.register) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _NewSessionCard(onStart: _startNewSession),
          ),
        ] else ...[
          StreamBuilder<List<WorkoutSummary>>(
            stream: _history,
            builder: (context, snapshot) {
              final history = snapshot.data ?? const <WorkoutSummary>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MonthSelector(
                    month: _month,
                    sessionCount: sessionsInMonth(
                      [for (final s in history) s.endedAt],
                      _month,
                    ),
                    onPrevious: () => _shiftMonth(-1),
                    onNext: () => _shiftMonth(1),
                  ),
                  _TrainingCalendar(
                    month: _month,
                    markers: trainedDayMarkers([
                      for (final s in history)
                        (endedAt: s.endedAt, routineName: s.title),
                    ]),
                  ),
                  _StreakBanner(history: history),
                  _MetricsCluster(history: history),
                  _RecentSessionsHeader(count: history.length),
                  if (history.isEmpty)
                    const _EmptyHistory()
                  else
                    for (final summary in history)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _HistoryCard(
                          summary: summary,
                          onRepeat: () => _repeatSession(summary),
                          onDelete: () => _deleteSession(summary),
                        ),
                      ),
                  const _PastSessionCta(),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Tarjeta de sesión activa (RF-6): icono con ping, cronómetro en curso y
/// acción «Reanudar».
class _ActiveSessionCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onResume;

  const _ActiveSessionCard({required this.workout, required this.onResume});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final elapsed = DateTime.now().difference(workout.startedAt);
    return InkWell(
      onTap: onResume,
      borderRadius: BorderRadius.circular(12),
      highlightColor: kSurfaceContainerHigh,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kOutlineVariant.withValues(alpha: 0.3)),
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
              child: const Icon(Icons.fitness_center, size: 20, color: kPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SESIÓN EN CURSO',
                    style: textTheme.labelSmall?.copyWith(
                      color: kSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    workout.name ?? 'Entrenamiento libre',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: kPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 13, color: kPrimary),
                      const SizedBox(width: 4),
                      Text(
                        _elapsedLabel(elapsed),
                        style: textTheme.labelSmall
                            ?.copyWith(color: kPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reanudar',
                    style: textTheme.labelMedium?.copyWith(
                      color: kOnPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward,
                      size: 16, color: kOnPrimary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CTA para arrancar una sesión libre desde el modo Registro.
class _NewSessionCard extends StatelessWidget {
  final VoidCallback onStart;

  const _NewSessionCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: kPrimary,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline, size: 20, color: kOnPrimary),
              const SizedBox(width: 8),
              Text(
                'Nueva sesión',
                style: textTheme.labelLarge?.copyWith(
                  color: kOnPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Selector de mes del calendario (RF-7): flechas y título con el nº de
/// sesiones del mes.
class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final int sessionCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.month,
    required this.sessionCount,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _RoundButton(icon: Icons.chevron_left, onTap: onPrevious),
          Expanded(
            child: Column(
              children: [
                Text(
                  monthLabel(month),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: kPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  sessionCount == 1
                      ? '1 sesión'
                      : '$sessionCount sesiones',
                  style: textTheme.labelSmall
                      ?.copyWith(color: kOutline, letterSpacing: 0.4),
                ),
              ],
            ),
          ),
          _RoundButton(icon: Icons.chevron_right, onTap: onNext),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      highlightColor: kSurfaceContainerHigh,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: kOnSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

/// Calendario mensual navegable por semanas desde el lunes (RF-7), con un
/// marcador por día entrenado.
class _TrainingCalendar extends StatelessWidget {
  final DateTime month;
  final Map<DateTime, String> markers;

  const _TrainingCalendar({required this.month, required this.markers});

  static const List<String> _weekDays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = monthGrid(month, markers: markers, today: DateTime.now());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              for (final label in _weekDays)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: kOutline,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (var week = 0; week < days.length ~/ 7; week++) ...[
            if (week > 0) const SizedBox(height: 4),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(child: _DayCell(day: days[week * 7 + i])),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Completado',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(color: kOutline),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  'P · T · L · U',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: kOnSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final CalendarDay day;

  const _DayCell({required this.day});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isToday = day.isToday;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: day.inMonth
            ? (isToday ? kSurfaceContainerHigh : kSurfaceContainer)
            : kSurfaceContainerLowest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: isToday ? Border.all(color: kPrimary) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.date.day}',
            style: textTheme.labelSmall?.copyWith(
              color: !day.inMonth
                  ? kOutline.withValues(alpha: 0.6)
                  : isToday
                      ? kPrimary
                      : kOnSurface,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          if (day.trained && day.marker != null)
            Container(
              width: 16,
              height: 12,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? kPrimary : kSurfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                day.marker!,
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 9,
                  height: 1,
                  color: isToday ? kSurface : kPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (isToday)
            Text(
              'HOY',
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9,
                height: 1,
                color: kPrimary,
                letterSpacing: 0.6,
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Banner de racha (mockup Entrenar): icono de fuego, semanas consecutivas
/// de adherencia y el avance de la semana en curso frente al objetivo
/// semanal por defecto (4 sesiones).
class _StreakBanner extends StatelessWidget {
  static const int weeklyGoal = 4;

  final List<WorkoutSummary> history;

  const _StreakBanner({required this.history});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final ends = [for (final s in history) s.endedAt];
    final streak = weekStreak(ends, now);
    final week = weekStart(now);
    final thisWeek = ends.where((date) => !date.isBefore(week)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
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
                Icons.local_fire_department,
                size: 24,
                color: kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    textBaseline: TextBaseline.alphabetic,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    children: [
                      Text(
                        '$streak',
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          streak == 1 ? 'semana' : 'semanas',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: kOnSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'RACHA CONTINUA DE ADHERENCIA',
                    style: textTheme.labelSmall?.copyWith(
                      color: kOutline,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kSurfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$thisWeek/$weeklyGoal esta semana',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(color: kOnSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cluster de métricas del panel (RF-8): sesiones totales, adherencia,
/// volumen del mes y descanso activo (días desde la última sesión).
class _MetricsCluster extends StatelessWidget {
  final List<WorkoutSummary> history;

  const _MetricsCluster({required this.history});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ends = [for (final s in history) s.endedAt];
    final volume = volumeInMonth(
      [for (final s in history) (date: s.endedAt, volumeKg: s.volumeKg)],
      DateTime(now.year, now.month),
    );
    final adherence = adherenceRate(ends, now);
    final latest =
        ends.isEmpty ? null : ends.reduce((a, b) => a.isAfter(b) ? a : b);
    final restDays = latest == null ? null : now.difference(latest).inDays;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: MetricCluster(
        columns: 2,
        metrics: [
          (
            label: 'Sesiones',
            value: '${history.length}',
          ),
          (
            label: 'Adherencia',
            value: '${(adherence * 100).round()}%',
          ),
          (
            label: 'Descanso activo',
            value: restDays == null ? '—' : '$restDays d',
          ),
          (
            label: 'Volumen mes',
            value: _thousands(
              displayWeightKg(volume, UnitSystemScope.of(context)),
            ),
          ),
        ],
        progresses: [null, adherence, null, null],
      ),
    );
  }
}

/// Tarjeta del feed de historial (RF-9): duración, series, tonelaje y
/// ejercicios destacados.
class _HistoryCard extends StatelessWidget {
  final WorkoutSummary summary;
  final VoidCallback onRepeat;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.summary,
    required this.onRepeat,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unitSystem = UnitSystemScope.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _dayLabel(summary.endedAt),
            style: textTheme.labelSmall?.copyWith(
              color: kOutline,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            summary.title ?? 'Entrenamiento libre',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: kPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: kSurfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _FeedMetric(
                  label: 'DURACIÓN',
                  value: '${summary.duration.inMinutes} min',
                ),
                _FeedMetric(
                  label: 'SERIES',
                  value: summary.setCount == 1
                      ? '1 serie'
                      : '${summary.setCount} series',
                ),
                _FeedMetric(
                  label: 'TONELAJE',
                  value: _thousands(
                    displayWeightKg(summary.volumeKg, unitSystem),
                  ),
                ),
              ],
            ),
          ),
          if (summary.highlights.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final highlight in summary.highlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.done, size: 16, color: kOutline),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        highlight.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_weight(displayWeightKg(highlight.weightKg, unitSystem))} '
                      '${weightUnitOf(unitSystem)} × '
                      '${highlight.reps}'
                      '${highlight.rir == null ? '' : ' (RIR ${highlight.rir})'}',
                      style: textTheme.bodyMedium?.copyWith(
                        color: kPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: kSurfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delete_outline,
                            size: 14,
                            color: kError,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Borrar',
                            style: textTheme.labelMedium?.copyWith(
                              color: kError,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: kSurfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onRepeat,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.replay, size: 14, color: kPrimary),
                          const SizedBox(width: 4),
                          Text(
                            'Repetir',
                            style: textTheme.labelMedium?.copyWith(
                              color: kPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _FeedMetric extends StatelessWidget {
  final String label;
  final String value;

  const _FeedMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(color: kOutline),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyLarge?.copyWith(
              color: kPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.history, size: 28, color: kOutline),
            const SizedBox(height: 8),
            Text(
              'Sin sesiones todavía',
              style: textTheme.titleSmall?.copyWith(color: kOnSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              'Termina tu primera sesión y aparecerá aquí.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: kOutline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cabecera «Sesiones Recientes» (mockup): título con contador de sesiones a
/// la izquierda y el botón «Exportar CSV» a la derecha (spec 006, dominio
/// `data_export.dart`).
class _RecentSessionsHeader extends StatelessWidget {
  final int count;

  const _RecentSessionsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'Sesiones Recientes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kSurfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$count', style: textTheme.labelSmall),
                ),
              ],
            ),
          ),
          const _ExportCsvButton(),
        ],
      ),
    );
  }
}

/// Botón «Exportar CSV» del feed: copia la exportación completa al
/// portapapeles y lo confirma con un snackbar.
class _ExportCsvButton extends StatefulWidget {
  const _ExportCsvButton();

  @override
  State<_ExportCsvButton> createState() => _ExportCsvButtonState();
}

class _ExportCsvButtonState extends State<_ExportCsvButton> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextButton.icon(
      onPressed: _export,
      icon: const Icon(Icons.file_download, size: 14),
      label: Text('Exportar CSV', style: textTheme.labelSmall),
      style: TextButton.styleFrom(
        foregroundColor: kOutline,
        iconColor: kOnSurfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Future<void> _export() async {
    final csv = await profileRepository.exportCsv();
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datos copiados al portapapeles')),
    );
  }
}

/// CTA «Registrar entrenamiento pasado» (spec 012): abre el editor de sesión
/// pasada desde el modo historial.
class _PastSessionCta extends StatelessWidget {
  const _PastSessionCta();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Material(
        color: kPrimary,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const PastWorkoutEditorView(),
            ),
          ),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: kOnPrimary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Registrar entrenamiento pasado',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: kOnPrimary,
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

String _elapsedLabel(Duration elapsed) {
  final hours = elapsed.inHours;
  final minutes = elapsed.inMinutes % 60;
  final seconds = elapsed.inSeconds % 60;
  final hh = hours > 0 ? '$hours:' : '';
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return '$hh$mm:$ss';
}

String _dayLabel(DateTime endedAt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(endedAt.year, endedAt.month, endedAt.day);
  final diff = today.difference(day).inDays;
  const months = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
  ];
  final date = '${day.day} ${months[day.month - 1]}';
  if (diff <= 0) return 'HOY · $date';
  if (diff == 1) return 'AYER · $date';
  return 'HACE $diff DÍAS · $date';
}

String _weight(double kg) =>
    kg == kg.roundToDouble() ? '${kg.round()}' : kg.toStringAsFixed(1);

String _thousands(double value) {
  final digits = value.round().toString();
  return digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => '.',
  );
}