import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/routine_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/previous_sets.dart';
import '../../domain/rest_timer.dart';
import '../../domain/services/rest_notifier.dart';
import '../../domain/units.dart';
import '../../domain/use_cases/workout_manager.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/exercise_thumb.dart';
import '../widgets/live_fatigue_section.dart';

typedef LogSetCallback = Future<void> Function(
  double weightKg,
  int reps,
  int rir,
  String setType,
);

typedef UpdateSetCallback = Future<void> Function(
  String setId, {
  required double weightKg,
  required int reps,
  required int rir,
  required String setType,
});

typedef DeleteSetCallback = Future<void> Function(String setId);

typedef UnconfirmSetCallback = Future<void> Function(String setId);

const _setTypeLabels = {
  'warmup': 'CALENTAMIENTO',
  'normal': 'NORMAL',
  'failure': 'FALLO',
  'drop': 'DROP',
};

class LiveWorkoutView extends StatefulWidget {
  final String workoutId;

  const LiveWorkoutView({super.key, required this.workoutId});

  @override
  State<LiveWorkoutView> createState() => _LiveWorkoutViewState();
}

class _LiveWorkoutViewState extends State<LiveWorkoutView>
    with WidgetsBindingObserver {
  final WorkoutManager _manager = WorkoutManager();
  final RestNotifier _restNotifier = RestNotifier();
  late final Stream<Workout?> _workout;
  late final Stream<List<({WorkoutExercise item, Exercise exercise})>>
      _exercises;
  late final Stream<List<WorkoutSet>> _sets;
  late final Stream<FatiguePanel> _fatiguePanel;
  late final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());
  Timer? _clockTimer;
  DateTime? _startedAt;
  bool _busy = false;
  Workout? _currentWorkout;
  List<ProgressionSuggestion> _liveSuggestions = const [];
  final Set<String> _dismissedProgression = {};
  bool _suggestionsScheduled = false;
  Map<String, List<PreviousSet>> _previousByExercise =
      const <String, List<PreviousSet>>{};
  bool _previousLoaded = false;
  final Set<String> _expandedExerciseIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _workout = workoutRepository.watchWorkout(widget.workoutId);
    _exercises = workoutRepository.watchExercises(widget.workoutId);
    _sets = workoutRepository.watchSets(widget.workoutId);
    _fatiguePanel = fatigueRepository.watchFatiguePanel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _now.value = DateTime.now();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _scheduleRestNotification();
    } else if (state == AppLifecycleState.resumed) {
      _restNotifier.cancel();
    }
  }

  Future<void> _scheduleRestNotification() async {
    final endsAt = _currentWorkout?.restEndsAt;
    if (endsAt == null || !endsAt.isAfter(DateTime.now())) return;
    await _restNotifier.scheduleAt(endsAt);
  }

  RestTimer _restOf(Workout workout) => RestTimer(
        endsAt: workout.restEndsAt,
        pausedRemaining: workout.restPausedSeconds == null
            ? null
            : Duration(seconds: workout.restPausedSeconds!),
      );

  /// Arranca el descanso tras una serie normal/failure/drop (RF-5 de la 002).
  /// Con [restSeconds] usa el descanso planificado de esa serie (RF-1 de la
  /// 004); si no, el del ejercicio.
  Future<void> _startRest(Exercise exercise, {int? restSeconds}) async {
    final now = DateTime.now();
    final seconds = (restSeconds ?? exercise.restSeconds).clamp(15, 300);
    final timer = const RestTimer().start(now, Duration(seconds: seconds));
    await workoutRepository.saveRestTimer(widget.workoutId, endsAt: timer.endsAt);
  }

  /// Series de la última sesión terminada, por ejercicio (RF-13/RF-14 de la
  /// 008). No cambian mientras la sesión está activa: se cargan una vez.
  Future<void> _loadPrevious() async {
    final map = await workoutRepository.previousSets(before: _startedAt!);
    if (!mounted) return;
    setState(() => _previousByExercise = map);
  }

  Future<void> _applyRest(
    DateTime now,
    RestTimer Function(RestTimer rest, DateTime now) transform,
  ) async {
    final workout = _currentWorkout;
    if (workout == null) return;
    final timer = transform(_restOf(workout), now);
    await workoutRepository.saveRestTimer(
      widget.workoutId,
      endsAt: timer.endsAt,
      pausedRemaining: timer.pausedRemaining,
    );
  }

  void _toggleRest() {
    _applyRest(
      DateTime.now(),
      (rest, now) => rest.phaseAt(now) == RestTimerPhase.paused
          ? rest.resume(now)
          : rest.pause(now),
    );
  }

  void _adjustRest(int deltaSeconds) {
    _applyRest(
      DateTime.now(),
      (rest, now) => rest.adjust(Duration(seconds: deltaSeconds), now),
    );
  }

  void _skipRest() {
    _applyRest(DateTime.now(), (rest, _) => rest.skip());
  }

  /// Recalcula las sugerencias de progresión para el aviso en vivo (RF-3 de
  /// la 004): solo en sesiones nacidas de una rutina. Descarta las que el
  /// usuario ya ocultó en esta sesión.
  Future<void> _refreshSuggestions() async {
    final workout = _currentWorkout;
    if (workout == null || workout.routineId == null) {
      if (_liveSuggestions.isNotEmpty && mounted) {
        setState(() => _liveSuggestions = const []);
      }
      return;
    }
    final suggestions =
        await routineRepository.progressionSuggestions(widget.workoutId);
    if (!mounted) return;
    setState(() {
      _liveSuggestions = [
        for (final suggestion in suggestions)
          if (!_dismissedProgression.contains(suggestion.routineExerciseId))
            suggestion,
      ];
    });
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restNotifier.cancel();
    _clockTimer?.cancel();
    _now.dispose();
    super.dispose();
  }

  String _formatTime(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  String _formatRest(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Workout?>(
      stream: _workout,
      builder: (context, workoutSnapshot) {
        if (workoutSnapshot.connectionState == ConnectionState.waiting ||
            workoutSnapshot.connectionState == ConnectionState.none) {
          return const Scaffold(
            backgroundColor: kSurface,
            body: Center(
              child: Text(
                'Cargando sesión...',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            ),
          );
        }
        final workout = workoutSnapshot.data;
        if (workout == null) {
          return const Scaffold(
            backgroundColor: kSurface,
            body: Center(
              child: Text(
                'Sesión no encontrada',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            ),
          );
        }
        _startedAt = workout.startedAt;
        _currentWorkout = workout;
        if (!_previousLoaded) {
          _previousLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrevious());
        }
        if (!_suggestionsScheduled) {
          _suggestionsScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refreshSuggestions();
          });
        }

        return Scaffold(
          backgroundColor: kSurface,
          appBar: AppBar(
            backgroundColor: kSurface,
            title: const Text('Entrenar'),
          ),
          body: StreamBuilder<List<({WorkoutExercise item, Exercise exercise})>>(
            stream: _exercises,
            builder: (context, exercisesSnapshot) {
              if (!exercisesSnapshot.hasData) {
                return const Center(
                  child: Text(
                    'Cargando sesión...',
                    style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
                  ),
                );
              }
              final entries = exercisesSnapshot.data!;

              return StreamBuilder<List<WorkoutSet>>(
                stream: _sets,
                builder: (context, setsSnapshot) {
                  if (!setsSnapshot.hasData) {
                    return const Center(
                      child: Text(
                        'Cargando sesión...',
                        style:
                            TextStyle(color: kOnSurfaceVariant, fontSize: 14),
                      ),
                    );
                  }
                  final sets = setsSnapshot.data!;

                  // Pre-group sets by workoutExerciseId to avoid filtering in builder
                  final setsByExercise = <String, List<WorkoutSet>>{};
                  for (final set in sets) {
                    setsByExercise
                        .putIfAbsent(set.workoutExerciseId, () => [])
                        .add(set);
                  }

                  return Stack(
                    children: [
                      CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _summaryStrip(workout, sets),
                          ),
                          SliverToBoxAdapter(
                            child: _progressionStrip(),
                          ),
                          // Nueva sección de fatiga después del strip de progresión (T-006)
                          StreamBuilder<FatiguePanel>(
                            stream: _fatiguePanel,
                            builder: (context, fatigueSnap) {
                              if (!fatigueSnap.hasData) {
                                return const SliverToBoxAdapter(
                                  child: SizedBox.shrink(),
                                );
                              }
                              return SliverToBoxAdapter(
                                child: LiveFatigueSection(
                                  panel: fatigueSnap.data!,
                                  onPanelChanged: (panel) {
                                    // Actualizar el stream si es necesario
                                  },
                                  showBack: false, // vista frontal por defecto en vivo
                                ),
                              );
                            },
                          ),
                          if (entries.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Text(
                                  'Añade tu primer ejercicio para empezar',
                                  style: TextStyle(
                                    color: kOnSurfaceVariant,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(0, 16, 0, 80),
                              sliver: SliverList.builder(
                                itemCount: entries.length,
                                itemBuilder: (context, index) {
                                  final entry = entries[index];
                                  final isFirst = index == 0;
                                  final isExpanded = isFirst ||
                                      _expandedExerciseIds.contains(
                                          entry.item.id);
                                  final exerciseSets = setsByExercise[entry.item.id] ?? const <WorkoutSet>[];
                                  if (isExpanded) {
                                    return _ExerciseCard(
                                      key: ValueKey(entry.item.id),
                                      item: entry.item,
                                      exercise: entry.exercise,
                                      sets: exerciseSets,
                                      manager: _manager,
                                      onLogSet: (weightKg, reps, rir,
                                          setType) async {
                                        await workoutRepository.logSet(
                                          workoutExerciseId: entry.item.id,
                                          weightKg: weightKg,
                                          reps: reps,
                                          rir: rir,
                                          setType: setType,
                                        );
                                        if (setType != 'warmup') {
                                          await _startRest(entry.exercise);
                                        }
                                        await _refreshSuggestions();
                                      },
                                      onUpdateSet: (
                                        setId, {
                                        required weightKg,
                                        required reps,
                                        required rir,
                                        required setType,
                                      }) async {
                                        final updated =
                                            await workoutRepository.updateSet(
                                          setId: setId,
                                          weightKg: weightKg,
                                          reps: reps,
                                          rir: rir,
                                          setType: setType,
                                        );
                                        if (setType != 'warmup') {
                                          await _startRest(
                                            entry.exercise,
                                            restSeconds: updated.restSeconds,
                                          );
                                        }
                                        await _refreshSuggestions();
                                      },
                                      onUnconfirmSet: (setId) async {
                                        await workoutRepository.setSetCompleted(
                                            setId, false);
                                        await _refreshSuggestions();
                                      },
                                      onDeleteSet: (setId) async {
                                        final confirmed =
                                            await _confirmDeleteSet();
                                        if (!confirmed) return;
                                        await workoutRepository.deleteSet(setId);
                                        await _refreshSuggestions();
                                      },
                                      onReplaceExercise: () =>
                                          _replaceExercise(entry.item.id),
                                      onDeleteExercise: () =>
                                          _removeExercise(entry.item.id),
                                      previous:
                                          _previousByExercise[entry.item
                                                  .exerciseId] ??
                                              const <PreviousSet>[],
                                      onCollapse: isFirst
                                          ? null
                                          : () => setState(
                                                () =>
                                                    _expandedExerciseIds
                                                        .remove(entry.item.id),
                                              ),
                                    );
                                  } else {
                                    return _CollapsedExerciseCard(
                                      key: ValueKey(
                                          'collapsed-${entry.item.id}'),
                                      item: entry.item,
                                      exercise: entry.exercise,
                                      sets: exerciseSets,
                                      onTap: () => setState(
                                        () =>
                                            _expandedExerciseIds
                                                .add(entry.item.id),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _restPill(),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Tarjeta de sesión (RF-12/RF-16 de la 008): label, título, cronómetro en
  /// píldora, métricas, módulo de descanso cuando está activo y acciones.
  Widget _summaryStrip(Workout workout, List<WorkoutSet> sets) {
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    final weightUnit = weightUnitOf(unitSystem);
    final volume = _manager.computeVolume(sets);
    final completed =
        sets.where((set) => set.completed).length;

    double? topE1RM;
    for (final set in sets.where((set) => set.completed)) {
      final e1RM =
          _manager.calculateE1RM(set.weightKg, set.reps, set.rir ?? 0);
      if (e1RM != null && (topE1RM == null || e1RM > topE1RM)) {
        topE1RM = e1RM;
      }
    }

    final rest = _restOf(workout);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SESIÓN EN CURSO',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: kOnSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workout.name ?? 'Sesión libre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: kOnSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ValueListenableBuilder<DateTime>(
                valueListenable: _now,
                builder: (context, now, _) => _timerPill(theme, now),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metric(
                theme,
                'VOLUMEN',
                formatWeightKg(volume, unitSystem),
                weightUnit,
              ),
              _metric(theme, 'SERIES', '$completed', null),
              _metric(
                theme,
                '1RM MAX',
                topE1RM == null
                    ? '—'
                    : formatWeightKg(topE1RM, unitSystem),
                topE1RM == null ? null : weightUnit,
              ),
            ],
          ),
          ValueListenableBuilder<DateTime>(
            valueListenable: _now,
            builder: (context, now, _) {
              final restPhase = rest.phaseAt(now);
              final showRestModule = restPhase == RestTimerPhase.running ||
                  restPhase == RestTimerPhase.paused;
              if (!showRestModule) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _restModule(rest, theme, now),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _sessionActions(sets),
        ],
      ),
    );
  }

  /// Cronómetro de la sesión en píldora con icono pulsante (mockup de
  /// registro en vivo).
  Widget _timerPill(ThemeData theme, DateTime now) {
    final pingOn = now.millisecondsSinceEpoch ~/ 1000 % 2 == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: kSurfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 450),
            opacity: pingOn ? 1 : 0.35,
            child: const Icon(
              Icons.timer_outlined,
              size: 16,
              color: kOnSurface,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatTime(_elapsedAt(now)),
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              color: kOnSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Duration _elapsedAt(DateTime now) => _startedAt == null
      ? Duration.zero
      : now.difference(_startedAt!);

  /// Módulo de descanso dentro de la tarjeta de sesión (RF-16 de la 008):
  /// contador con ajuste ±15 s, +30 s, pausa y salto.
  Widget _restModule(RestTimer rest, ThemeData theme, DateTime now) {
    final paused = rest.phaseAt(now) == RestTimerPhase.paused;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.hourglass_bottom_rounded,
            size: 20,
            color: kSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DESCANSO',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  _formatRest(rest.remainingAt(now)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    color: kOnSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          _restAction(
            icon: Icons.remove_rounded,
            tooltip: 'Ajustar −15 s',
            key: const Key('rest-minus'),
            onTap: () => _adjustRest(-15),
          ),
          const SizedBox(width: 4),
          _restAction(
            icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
            tooltip: paused ? 'Reanudar descanso' : 'Pausar descanso',
            key: const Key('rest-pause'),
            onTap: _toggleRest,
          ),
          const SizedBox(width: 4),
          _restAction(
            icon: Icons.add_rounded,
            tooltip: 'Ajustar +15 s',
            key: const Key('rest-plus'),
            onTap: () => _adjustRest(15),
          ),
          const SizedBox(width: 6),
          Material(
            color: kSurfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('rest-card-add30'),
              onTap: () => _adjustRest(30),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  '+30 s',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 12,
                    color: kOnSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _restAction(
            icon: Icons.skip_next_rounded,
            tooltip: 'Saltar descanso',
            key: const Key('rest-skip'),
            onTap: _skipRest,
          ),
        ],
      ),
    );
  }

  /// Píldora flotante del descanso (RF-16 de la 008): sticky sobre el
  /// contenido con indicador pulsante y +30 s, manteniendo las claves de test
  /// y los textos de la 002 (RF-17).
  Widget _restPill() {
    final workout = _currentWorkout;
    if (workout == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final rest = _restOf(workout);

    return ValueListenableBuilder<DateTime>(
      valueListenable: _now,
      builder: (context, now, _) {
        final phase = rest.phaseAt(now);
        if (phase == RestTimerPhase.idle) return const SizedBox.shrink();

        final done = phase == RestTimerPhase.done;
        final paused = phase == RestTimerPhase.paused;
        final label = done ? 'LISTO' : paused ? 'EN PAUSA' : 'DESCANSO ACTIVO';
        final pingOn = now.millisecondsSinceEpoch ~/ 1000 % 2 == 0;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: kSurfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kSurfaceContainerLowest),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 450),
                opacity: pingOn ? 1 : 0.35,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: kPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: SizedBox(width: 10, height: 10),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: kSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatRest(rest.remainingAt(now)),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  color: done ? kPrimary : kOnSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              if (done)
                _restAction(
                  icon: Icons.close_rounded,
                  tooltip: 'Quitar aviso',
                  key: const Key('rest-clear'),
                  onTap: _skipRest,
                )
              else
                Material(
                  color: kSurfaceBright,
                  shape: const StadiumBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const Key('rest-add30'),
                    onTap: () => _adjustRest(30),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '+30 s',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(fontSize: 12, color: kPrimary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Aviso en vivo de progresión (RF-3 de la 004): aparece al cumplirse las
  /// series objetivo de un ejercicio de la rutina en la sesión en curso.
  /// Muestra un único banner resumen con contador; «Entendido» descarta todos.
  Widget _progressionStrip() {
    final unitSystem = UnitSystemScope.of(context);
    if (_liveSuggestions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final count = _liveSuggestions.length;
    final first = _liveSuggestions.first;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        color: kSurfaceContainer,
        border: Border(bottom: BorderSide(color: kSurfaceContainerHighest)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.trending_up,
            size: 18,
            color: kPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? '${first.exerciseName}: objetivo cumplido, '
                      'podrás subir a '
                      '${formatWeightKg(first.sets.last.suggestedWeightKg, unitSystem)} '
                      '${weightUnitOf(unitSystem)} '
                      'al terminar la sesión'
                  : '$count ejercicios cumplieron el objetivo. '
                      'Podrás subir el peso al terminar.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: kOnSurface),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _dismissAllLiveProgression,
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _dismissAllLiveProgression() {
    setState(() {
      for (final suggestion in _liveSuggestions) {
        _dismissedProgression.add(suggestion.routineExerciseId);
      }
      _liveSuggestions = const [];
    });
  }

  Widget _restAction({
    required IconData icon,
    required String tooltip,
    required Key key,
    required VoidCallback onTap,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, size: 20, color: kOnSurfaceVariant),
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      style: IconButton.styleFrom(
        backgroundColor: kSurfaceContainerHighest,
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _metric(
    ThemeData theme,
    String label,
    String value,
    String? unit,
  ) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: kPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: kSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Lista de ejercicios: el primero va expandido (ejercicio activo) y los
  /// siguientes colapsados con su objetivo, expansibles al tocar (mockup de
  /// registro en vivo).

  /// Acciones de la sesión dentro de la tarjeta (mockup de registro en vivo):
  /// deshacer, añadir ejercicio y terminar.
  Widget _sessionActions(List<WorkoutSet> sets) {
    final canUndo = sets.any((set) => set.completed);
    final outlinedStyle = OutlinedButton.styleFrom(
      backgroundColor: kSurfaceContainerHigh,
      foregroundColor: kOnSurface,
      disabledBackgroundColor: kSurfaceContainerHigh,
      disabledForegroundColor: kOnSurfaceVariant,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        fontFamily: 'Geist',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );

    final undoButton = SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: canUndo ? _undoLastSet : null,
        style: outlinedStyle,
        icon: const Icon(Icons.undo, size: 20),
        label: const Text('Deshacer'),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: canUndo
                  ? undoButton
                  : Tooltip(
                      message: 'Nada que deshacer',
                      child: undoButton,
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: _openPicker,
                  style: outlinedStyle,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Añadir ejercicio'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _busy ? null : () => _finish(sets),
            icon: const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('Terminar'),
          ),
        ),
      ],
    );
  }

  Future<void> _undoLastSet() async {
    try {
      await workoutRepository.undoLastSet(widget.workoutId);
      await _refreshSuggestions();
    } on SessionNotEditableException catch (error) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<Exercise?> _pickExercise() {
    return showModalBottomSheet<Exercise>(
      context: context,
      backgroundColor: kSurfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: kSurfaceContainerHighest),
      ),
      builder: (context) => const ExercisePicker(),
    );
  }

  Future<void> _openPicker() async {
    final selected = await _pickExercise();
    if (selected == null || !mounted) return;
    await workoutRepository.addExercise(
      workoutId: widget.workoutId,
      exerciseId: selected.id,
    );
  }

  /// Reemplaza un ejercicio en curso: se descartan sus series y se empieza de
  /// cero con el nuevo (RF-3 de la 002).
  Future<void> _replaceExercise(String workoutExerciseId) async {
    final selected = await _pickExercise();
    if (selected == null || !mounted) return;
    await workoutRepository.replaceExercise(
      workoutExerciseId: workoutExerciseId,
      exerciseId: selected.id,
    );
    if (!mounted) return;
    await _refreshSuggestions();
  }

  /// Quita un ejercicio en curso con sus series (RF-2 de la 002).
  Future<void> _removeExercise(String workoutExerciseId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: kSurfaceContainer,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              side: BorderSide(color: kSurfaceContainerHighest),
            ),
            title: const Text(
              'Quitar ejercicio',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: kOnSurface,
              ),
            ),
            content: const Text(
              'Se borrarán sus series de esta sesión.',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                height: 1.4,
                color: kOnSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: kError),
                child: const Text('Quitar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await workoutRepository.removeExercise(workoutExerciseId);
    if (!mounted) return;
    await _refreshSuggestions();
  }

  /// Confirma el borrado de una serie en vivo (RF-1 de la 002).
  Future<bool> _confirmDeleteSet() async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: kSurfaceContainer,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
              side: BorderSide(color: kSurfaceContainerHighest),
            ),
            title: const Text(
              'Eliminar serie',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: kOnSurface,
              ),
            ),
            content: const Text(
              'Se quitará esta serie de la sesión.',
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 14,
                height: 1.4,
                color: kOnSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: kError),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _finish(List<WorkoutSet> sets) async {
    final completed = sets.where((set) => set.completed).length;
    if (completed == 0) {
      final discard = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: kSurfaceContainer,
              surfaceTintColor: Colors.transparent,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                side: BorderSide(color: kSurfaceContainerHighest),
              ),
              title: const Text(
                'Sesión sin series',
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: kOnSurface,
                ),
              ),
              content: const Text(
                'No has completado ninguna serie. La sesión se eliminará.',
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 14,
                  height: 1.4,
                  color: kOnSurfaceVariant,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: TextButton.styleFrom(foregroundColor: kError),
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ) ??
          false;
      if (!discard || !mounted) return;
    }

    setState(() => _busy = true);
    final saved = await workoutRepository.finishWorkout(widget.workoutId);
    if (!mounted) return;

    final discarded = completed == 0;
    var achievedCount = 0;
    if (saved) {
      // RF-6 de la 007: al cerrar la sesión el mapa de fatiga se recalcula.
      if (mounted) await fatigueRepository.recalculate();
      if (mounted) achievedCount = (await goalRepository.recalculate()).length;
      if (!mounted) return;
      // RF-3/RF-4 de la 004: al cerrar una sesión nacida de una rutina se
      // evalúan los objetivos y se sugieren los pesos de la próxima instancia.
      final suggestions =
          await routineRepository.progressionSuggestions(widget.workoutId);
      // La rutina adopta lo que de verdad se registró, serie a serie.
      await routineRepository.persistSessionValues(widget.workoutId);
      if (suggestions.isNotEmpty && mounted) {
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: kSurfaceContainer,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(color: kSurfaceContainerHighest),
          ),
          builder: (context) => _ProgressionSheet(
            suggestions: suggestions,
            onApply: (routineSetId, weightKg) => routineRepository
                .applyProgressedWeight(routineSetId, weightKg),
          ),
        );
      }
      if (!mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    String finishMessage;
    if (discarded) {
      finishMessage = 'Sesión vacía descartada';
    } else if (achievedCount == 0) {
      finishMessage = 'Sesión terminada';
    } else if (achievedCount == 1) {
      finishMessage = 'Sesión terminada · ¡Meta lograda!';
    } else {
      finishMessage = 'Sesión terminada · ¡$achievedCount metas logradas!';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(finishMessage)));
  }
}

class _ExerciseCard extends StatefulWidget {
  final WorkoutExercise item;
  final Exercise exercise;
  final List<WorkoutSet> sets;
  final WorkoutManager manager;
  final LogSetCallback onLogSet;
  final UpdateSetCallback onUpdateSet;
  final UnconfirmSetCallback onUnconfirmSet;
  final DeleteSetCallback onDeleteSet;
  final Future<void> Function() onReplaceExercise;
  final Future<void> Function() onDeleteExercise;
  final List<PreviousSet> previous;
  final VoidCallback? onCollapse;

  const _ExerciseCard({
    super.key,
    required this.item,
    required this.exercise,
    required this.sets,
    required this.manager,
    required this.onLogSet,
    required this.onUpdateSet,
    required this.onUnconfirmSet,
    required this.onDeleteSet,
    required this.onReplaceExercise,
    required this.onDeleteExercise,
    required this.previous,
    this.onCollapse,
  });

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard>
    with AutomaticKeepAliveClientMixin {
  String _setType = 'normal';

  @override
  bool get wantKeepAlive => true;

  double? get _bestE1RM {
    double? best;
    for (final set in widget.sets.where((set) => set.completed)) {
      final e1RM =
          widget.manager.calculateE1RM(set.weightKg, set.reps, set.rir ?? 0);
      if (e1RM != null && (best == null || e1RM > best)) {
        best = e1RM;
      }
    }
    return best;
  }

  /// Última serie de la sesión anterior para el número de serie dado: la
  /// fila 1 se compara con la serie 1, la 2 con la 2 y el resto con la
  /// última disponible (RF-14 de la 008).
  PreviousSet? _prevAt(int index) {
    final previous = widget.previous;
    if (previous.isEmpty) return null;
    if (index <= previous.length) return previous[index - 1];
    return previous.last;
  }

  Widget _previousPill(PreviousSet prev) {
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.history, size: 16, color: kSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Sesión previa: ',
                    style: TextStyle(color: kOnSurfaceVariant),
                  ),
                  TextSpan(
                    text:
                        '${formatWeightKg(prev.weightKg, unitSystem)} '
                        '${weightUnitOf(unitSystem)} × ${prev.reps} reps',
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: ' (@ RIR ${prev.rir})',
                    style: const TextStyle(color: kSecondary, fontSize: 12),
                  ),
                ],
              ),
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: kOnSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    final bestE1RM = _bestE1RM;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseThumb(
                exercise: widget.exercise,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ExerciseChips(exercise: widget.exercise),
                    const SizedBox(height: 8),
                    Text(
                      widget.exercise.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: kOnSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                      Text(
                        '1RM ESTIMADO ${bestE1RM == null ? '—' : '${formatWeightKg(bestE1RM, unitSystem)} ${weightUnitOf(unitSystem)}'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: kOnSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (widget.onCollapse != null)
                IconButton(
                  key: Key('collapse-${widget.item.id}'),
                  tooltip: 'Colapsar ejercicio',
                  onPressed: widget.onCollapse,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(
                    Icons.expand_less,
                    size: 22,
                    color: kOnSurfaceVariant,
                  ),
                ),
              PopupMenuButton<String>(
                key: Key('exercise-menu-${widget.item.id}'),
                tooltip: 'Opciones del ejercicio',
                icon: const Icon(
                  Icons.more_vert,
                  size: 20,
                  color: kOnSurfaceVariant,
                ),
                onSelected: (value) {
                  if (value == 'replace') {
                    widget.onReplaceExercise();
                  } else if (value == 'delete') {
                    widget.onDeleteExercise();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'replace', child: Text('Reemplazar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
          if (widget.previous.isNotEmpty) ...[
            const SizedBox(height: 8),
            _previousPill(widget.previous.last),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final type in _setTypeLabels.keys)
                ChoiceChip(
                  label: Text(_setTypeLabels[type]!),
                  selected: _setType == type,
                  onSelected: (_) => setState(() => _setType = type),
                  showCheckmark: false,
                  selectedColor: kSurfaceContainerHighest,
                  backgroundColor: kSurfaceContainerLow,
                  side: BorderSide.none,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    color: _setType == type ? kPrimary : kOnSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _setTable(),
        ],
      ),
    );
  }

  Widget _setTable() {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      color: kOnSurfaceVariant,
      letterSpacing: 0.66,
    );

    return Column(
      children: [
        SizedBox(
          height: 28,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('SET', style: headerStyle),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text(
                  'PREVIO',
                  style: headerStyle,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text(
                  weightUnitOf(UnitSystemScope.of(context)).toUpperCase(),
                  style: headerStyle, textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Text('REPS',
                    style: headerStyle, textAlign: TextAlign.center),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: Text('RIR',
                    style: headerStyle, textAlign: TextAlign.center),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 32,
                child: Text('OK',
                    style: headerStyle, textAlign: TextAlign.center),
              ),
              const SizedBox(width: 32),
            ],
          ),
        ),
        for (final set in widget.sets)
          _EditableSetRow(
            key: ValueKey('set-${set.id}'),
            rowId: set.id,
            set: set,
            number: set.orderIndex,
            previous: _prevAt(set.orderIndex),
            onConfirm: (weightKg, reps, rir) async {
              await widget.onUpdateSet(
                set.id,
                weightKg: weightKg,
                reps: reps,
                rir: rir,
                setType: set.setType,
              );
            },
            onUnconfirm: () => widget.onUnconfirmSet(set.id),
            onDelete: () => widget.onDeleteSet(set.id),
          ),
        _EditableSetRow(
          key: ValueKey('new-${widget.item.id}'),
          rowId: widget.item.id,
          set: null,
          number: widget.sets.length + 1,
          previous: _prevAt(widget.sets.length + 1),
          onConfirm: (weightKg, reps, rir) =>
              widget.onLogSet(weightKg, reps, rir, _setType),
          onUnconfirm: () async {},
        ),
      ],
    );
  }

}

/// Chips de músculo y texto de equipo de un ejercicio (mockup de registro en
/// vivo): musculatura objetivo y grupo como chips en mayúsculas y equipo con
/// bullet delante.
class _ExerciseChips extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseChips({required this.exercise});

  Widget _badge(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: kOnSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targets = <String>[
      exercise.target,
      if (exercise.muscleGroup != exercise.target) exercise.muscleGroup,
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final target in targets) _badge(target),
        Text(
          '• ${exercise.equipment}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: kOnSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Ejercicio colapsado (mockup de registro en vivo): chips, título y píldora
/// con las series programadas y el objetivo RIR; al tocar se expande.
class _CollapsedExerciseCard extends StatelessWidget {
  final WorkoutExercise item;
  final Exercise exercise;
  final List<WorkoutSet> sets;
  final VoidCallback onTap;

  const _CollapsedExerciseCard({
    super.key,
    required this.item,
    required this.exercise,
    required this.sets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap in RepaintBoundary to isolate repaints
    return RepaintBoundary(
      child: _CollapsedExerciseCardContent(
        item: item,
        exercise: exercise,
        sets: sets,
        onTap: onTap,
      ),
    );
  }
}

class _CollapsedExerciseCardContent extends StatelessWidget {
  final WorkoutExercise item;
  final Exercise exercise;
  final List<WorkoutSet> sets;
  final VoidCallback onTap;

  const _CollapsedExerciseCardContent({
    required this.item,
    required this.exercise,
    required this.sets,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planned = item.targetSets ?? sets.length;

    // Objetivo RIR: el planificado del ejercicio o, si no lo trae, el rango
    // de las series pendientes.
    int? minRir;
    int? maxRir;
    if (item.targetRir != null) {
      minRir = item.targetRir;
      maxRir = item.targetRir;
    } else {
      for (final set in sets) {
        if (set.completed || set.rir == null) continue;
        minRir = (minRir == null || set.rir! < minRir) ? set.rir : minRir;
        maxRir = (maxRir == null || set.rir! > maxRir) ? set.rir : maxRir;
      }
    }
    final objetivo = minRir == null
        ? null
        : minRir == maxRir
            ? 'RIR $minRir'
            : 'RIR $minRir-$maxRir';

    return GestureDetector(
      key: Key('expand-${item.id}'),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kSurfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kSurfaceContainerHighest),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExerciseThumb(
                  exercise: exercise,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ExerciseChips(exercise: exercise),
                      const SizedBox(height: 8),
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: kOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.expand_more,
                  size: 22,
                  color: kOnSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.checklist_rounded,
                    size: 16,
                    color: kOnSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      planned == 0
                          ? 'Sin series todavía'
                          : planned == 1
                              ? '1 serie programada'
                              : '$planned series programadas',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: kOnSurfaceVariant),
                    ),
                  ),
                  if (objetivo != null) ...[
                    Text(
                      'OBJETIVO',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 10,
                        color: kOnSurfaceVariant,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      objetivo,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: kPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila editable de la tabla de series en vivo (RF-1 de la 002): KG, REPS y
/// RIR se editan en línea y un checklist confirma la serie. Desmarcarla la
/// deja pendiente; la fila nueva añade una serie al marcar el check.
class _EditableSetRow extends StatefulWidget {
  final String rowId;
  final WorkoutSet? set;
  final int number;
  final PreviousSet? previous;
  final Future<void> Function(double weightKg, int reps, int rir) onConfirm;
  final Future<void> Function() onUnconfirm;
  final Future<void> Function()? onDelete;

  const _EditableSetRow({
    super.key,
    required this.rowId,
    required this.set,
    required this.number,
    required this.previous,
    required this.onConfirm,
    required this.onUnconfirm,
    this.onDelete,
  });

  @override
  State<_EditableSetRow> createState() => _EditableSetRowState();
}

class _EditableSetRowState extends State<_EditableSetRow>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _kgCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _rirCtrl;
  bool _busy = false;
  String _unitSystem = 'metric';
  double? _rawKg;

  @override
  bool get wantKeepAlive => true;

  bool get _done => widget.set?.completed ?? false;

  @override
  void initState() {
    super.initState();
    final set = widget.set;
    _rawKg = set?.weightKg;
    _kgCtrl = TextEditingController(
      text: set == null ? '' : formatWeightKg(set.weightKg, 'metric'),
    );
    _repsCtrl = TextEditingController(text: set == null ? '' : '${set.reps}');
    _rirCtrl = TextEditingController(
      text: set == null ? '' : '${set.rir ?? 0}',
    );
    _rirCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final units = UnitSystemScope.of(context);
    if (_unitSystem == units) return;
    _unitSystem = units;
    final set = widget.set;
    if (set != null) {
      _rawKg = set.weightKg;
      _kgCtrl.text = formatWeightKg(set.weightKg, units);
    }
  }

  @override
  void dispose() {
    _kgCtrl.dispose();
    _repsCtrl.dispose();
    _rirCtrl.dispose();
    super.dispose();
  }

  /// Marca o desmarca la serie desde el checklist: desmarcar la deja
  /// pendiente; marcar exige peso, repeticiones y RIR y la confirma.
  Future<void> _toggle() async {
    if (_busy) return;
    if (_done) {
      setState(() => _busy = true);
      try {
        await widget.onUnconfirm();
      } on SessionNotEditableException catch (error) {
        _showError(error.message);
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final displayWeight = _rawKg != null
        ? displayWeightKg(_rawKg!, _unitSystem)
        : double.tryParse(_kgCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final weight = toKg(displayWeight, _unitSystem);
    final reps = int.tryParse(_repsCtrl.text.trim());
    if (reps == null) {
      _showError('Indica las repeticiones');
      return;
    }
    final rir = int.tryParse(_rirCtrl.text.trim());
    if (rir == null) {
      _showError('Indica el RIR');
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.onConfirm(weight, reps, rir);
      if (widget.set == null) {
        _kgCtrl.clear();
        _repsCtrl.clear();
        _rirCtrl.clear();
        _rawKg = null;
      } else {
        _rawKg = weight;
        _kgCtrl.text = formatWeightKg(weight, _unitSystem);
      }
    } on SetValidationException catch (error) {
      _showError(error.message);
    } on SessionNotEditableException catch (error) {
      _showError(error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _done ? null : kSurfaceContainerHigh,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '${widget.number}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _done ? kOnSurfaceVariant : kPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: Text(
                  widget.previous == null
                      ? '—'
                      : '${formatWeightKg(widget.previous!.weightKg, _unitSystem)} × '
                          '${widget.previous!.reps}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kOnSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: _field(
                  key: Key('set-weight-${widget.rowId}'),
                  controller: _kgCtrl,
                  onChanged: (_) => setState(() => _rawKg = null),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _field(
                  key: Key('set-reps-${widget.rowId}'),
                  controller: _repsCtrl,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _field(
                  key: Key('set-rir-${widget.rowId}'),
                  controller: _rirCtrl,
                ),
              ),
              const SizedBox(width: 6),
              _checkButton(),
              if (widget.onDelete != null)
                _deleteButton()
              else
                const SizedBox(width: 32),
            ],
          ),
          if (widget.set == null) _quickAdjust(),
        ],
      ),
    );
  }

  /// Ajuste rápido del peso y RIR cíclico para la fila nueva (RF-15 de la
  /// 008): steppers de ±1,25 kg y ±2,5 kg (±2,5 lb y ±5 lb en imperial); el
  /// chip RIR sube al tocar y baja con una pulsación larga; «Añadir serie»
  /// confirma la fila.
  Widget _quickAdjust() {
    final weightUnit = weightUnitOf(_unitSystem);
    final step = weightStepOf(_unitSystem);
    final doubleStep = step * 2;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Ajuste Rápido:',
                  style: TextStyle(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                _stepChip('−${formatDisplay(doubleStep)} $weightUnit',
                    () => _adjustKg(-doubleStep)),
                _stepChip('−${formatDisplay(step)} $weightUnit',
                    () => _adjustKg(-step)),
                _stepChip('+${formatDisplay(step)} $weightUnit',
                    () => _adjustKg(step)),
                _stepChip('+${formatDisplay(doubleStep)} $weightUnit',
                    () => _adjustKg(doubleStep)),
                _rirChip(),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _toggle,
              style: OutlinedButton.styleFrom(
                backgroundColor: kSurfaceContainerHighest,
                foregroundColor: kOnSurface,
                disabledForegroundColor: kOnSurfaceVariant,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir serie'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepChip(String label, VoidCallback onTap) {
    return Material(
      color: kSurfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: kOnSurface,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rirChip() {
    return GestureDetector(
      key: Key('rir-cycle-${widget.rowId}'),
      onTap: _cycleRir,
      onLongPress: _unCycleRir,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kSurfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'RIR ${_rirCtrl.text}',
          style: const TextStyle(
            fontSize: 12,
            color: kPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _adjustKg(double delta) {
    final currentDisplay = _rawKg != null
        ? displayWeightKg(_rawKg!, _unitSystem)
        : double.tryParse(_kgCtrl.text.trim().replaceAll(',', '.')) ?? 0;
    final nextDisplay = (currentDisplay + delta).clamp(0.0, 9999.0);
    final nextRaw = toKg(nextDisplay, _unitSystem);
    setState(() {
      _rawKg = nextRaw;
      _kgCtrl.text = formatDisplay(nextDisplay);
    });
  }

  void _cycleRir() {
    final current = int.tryParse(_rirCtrl.text.trim()) ?? 0;
    setState(() => _rirCtrl.text = '${(current + 1) % 11}');
  }

  void _unCycleRir() {
    final current = int.tryParse(_rirCtrl.text.trim()) ?? 0;
    setState(() => _rirCtrl.text = '${(current + 10) % 11}');
  }

  Widget _checkButton() {
    return Semantics(
      button: true,
      label: _done ? 'Desmarcar serie' : 'Confirmar serie',
      child: GestureDetector(
        key: Key('set-check-${widget.rowId}'),
        onTap: _busy ? null : _toggle,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _done ? kSecondary : kSurfaceContainerHighest,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: _done
                ? null
                : Border.all(color: kOnSurfaceVariant),
          ),
          child: Icon(
            _done ? Icons.check : Icons.check_outlined,
            size: 18,
            color: _done ? kSurface : kOnSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _deleteButton() {
    return IconButton(
      key: Key('set-delete-${widget.rowId}'),
      onPressed: _busy ? null : widget.onDelete,
      tooltip: 'Eliminar serie',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: const Icon(Icons.close, size: 16, color: kOnSurfaceVariant),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    void Function(String)? onChanged,
  }) {
    return TextField(
      key: key,
      controller: controller,
      enabled: !_done,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: TextStyle(
        fontFamily: 'Geist',
        fontSize: 14,
        color: _done ? kOnSurfaceVariant : kPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        filled: true,
        fillColor: kSurfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: kOnSurface),
        ),
      ),
    );
  }

}
  enum _SuggestionOutcome { none, applied, ignored }

/// Hoja de sugerencias de progresión al cerrar una sesión nacida de una
/// rutina (RF-3 y RF-4 de la 004): por ejercicio, Aceptar, Ignorar o
/// Sobrescribir el peso **serie a serie** de la próxima instancia.
class _ProgressionSheet extends StatefulWidget {
  final List<ProgressionSuggestion> suggestions;
  final Future<void> Function(String routineSetId, double weightKg) onApply;

  const _ProgressionSheet({
    required this.suggestions,
    required this.onApply,
  });

  @override
  State<_ProgressionSheet> createState() => _ProgressionSheetState();
}

class _ProgressionSheetState extends State<_ProgressionSheet> {
  final Map<String, _SuggestionOutcome> _outcome = {};
  final Map<String, double> _weight = {};

  Future<void> _apply(ProgressionSuggestion suggestion) async {
    for (final set in suggestion.sets) {
      await widget.onApply(set.routineSetId, set.suggestedWeightKg);
      _weight[set.routineSetId] = set.suggestedWeightKg;
    }
    _mark(suggestion, _SuggestionOutcome.applied);
  }

  Future<void> _ignore(ProgressionSuggestion suggestion) async {
    _mark(suggestion, _SuggestionOutcome.ignored);
  }

  void _mark(ProgressionSuggestion suggestion, _SuggestionOutcome outcome) {
    if (!mounted) return;
    setState(() => _outcome[suggestion.routineExerciseId] = outcome);
  }

  Future<void> _overrideSet(
    ProgressionSuggestion suggestion,
    SetProgressionSuggestion set,
  ) async {
    final unitSystem = UnitSystemScope.of(context);
    final controller = TextEditingController(
      text: formatDisplay(
        displayWeightKg(
          _weight[set.routineSetId] ?? set.suggestedWeightKg,
          unitSystem,
        ),
      ),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kSurfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: kSurfaceContainerHighest),
        ),
        title: Text('Serie ${set.orderIndex} · nuevo peso'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: weightUnitOf(unitSystem).toUpperCase(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final weight = double.tryParse(controller.text.trim());
              if (weight != null) {
                Navigator.pop(dialogContext, toKg(weight, unitSystem));
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    await widget.onApply(set.routineSetId, value);
    if (!mounted) return;
    setState(() => _weight[set.routineSetId] = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: const BoxDecoration(
                  color: kSurfaceContainerHighest,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Progresión sugerida',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: kOnSurface,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cumpliste tus series objetivo. ¿Subimos el peso?',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: kOnSurfaceVariant),
            ),
            const SizedBox(height: 12),
            for (final suggestion in widget.suggestions) _row(suggestion),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Listo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ProgressionSuggestion suggestion) {
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    final outcome =
        _outcome[suggestion.routineExerciseId] ?? _SuggestionOutcome.none;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            suggestion.exerciseName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: kOnSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          for (final set in suggestion.sets)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${set.orderIndex}',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: kOnSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${formatWeightKg(set.currentWeightKg, unitSystem)} → '
                      '${formatWeightKg(_weight[set.routineSetId] ?? set.suggestedWeightKg, unitSystem)} '
                      '${weightUnitOf(unitSystem)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: kPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (outcome == _SuggestionOutcome.none)
                    IconButton(
                      onPressed: () => _overrideSet(suggestion, set),
                      tooltip: 'Sobrescribir la serie',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 16,
                        color: kOnSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          if (outcome == _SuggestionOutcome.none)
            Row(
              children: [
                TextButton(
                  onPressed: () => _ignore(suggestion),
                  child: const Text('Ignorar'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => _apply(suggestion),
                  child: const Text('Aceptar'),
                ),
              ],
            )
          else
            Text(
              outcome == _SuggestionOutcome.applied
                  ? 'Pesos guardados'
                  : 'Sin cambios',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: outcome == _SuggestionOutcome.applied
                    ? kPrimary
                    : kOnSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
