import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/gif_cache.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/exercise_stats.dart';
import '../../domain/media.dart';
import '../../domain/units.dart';
import '../theme/colors.dart' as ThemeColors;
import '../unit_system_scope.dart';
import '../widgets/chart_enums.dart';
import '../widgets/exercise_thumb.dart';
import '../widgets/muscle_map.dart';
import '../widgets/exercise_progress_chart.dart' as ChartWidget;

class ExerciseInfoView extends StatefulWidget {
  final Exercise exercise;
  final AppDatabase? database;
  final WorkoutRepository? workoutRepository;

  const ExerciseInfoView({
    super.key,
    required this.exercise,
    this.database,
    this.workoutRepository,
  });

  @override
  State<ExerciseInfoView> createState() => _ExerciseInfoViewState();
}

class _ExerciseInfoViewState extends State<ExerciseInfoView> {
  Map<String, List<String>> _steps = const {};
  String _language = 'es';
  late int _restSeconds;
  File? _gifFile;

  ProgressMetric _selectedMetric = ProgressMetric.e1rm;
  ProgressWindow _selectedWindow = ProgressWindow.threeMonths;

  static const int _historyPageSize = 10;
  final List<ExerciseSessionSummary> _history = [];
  List<ExerciseSessionSummary> _historyUpcoming = const [];
  bool _historyLoaded = false;
  bool _historyLoading = false;

  Workout? _activeWorkout;
  StreamSubscription<Workout?>? _activeWorkoutSubscription;

  @override
  void initState() {
    super.initState();
    _restSeconds = widget.exercise.restSeconds;
    _loadSteps();
    _loadInitialHistory();
    _gifFile = null;
    _activeWorkout = null;
    _listenActiveWorkout();
  }

  File?_loadGifFile(String gifPath) {
    // Intentar servir el GIF directamente; si falla, retorna null para fallback local.
    // Esta función podría usar el patrón de download de GifCache si estuviera disponible,
    // o simplemente retornar null para usar la miniatura local (más seguro sin nuevas deps).
    return null; // Fallback a miniatura local
  }

  void _loadSteps() async {
    if (widget.database == null) return;
    final database = widget.database!;
    final rows = await (database.select(database.exerciseInstructions)
          ..where((t) => t.exerciseId.equals(widget.exercise.id)))
        .get();

    final grouped = <String, List>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.language, () => []).add(row);
    }

    final steps = <String, List<String>>{};
    grouped.forEach((language, list) {
      list.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
      steps[language] = [for (final step in list) step.instruction];
    });

    if (!mounted) return;
    setState(() {
      _steps = steps;
      if (!steps.containsKey(_language) && steps.isNotEmpty) {
        _language = steps.keys.first;
      }
    });
  }

  void _listenActiveWorkout() {
    if (widget.workoutRepository == null) return;
    _activeWorkoutSubscription =
        widget.workoutRepository!.watchActiveWorkout().listen((Workout? workout) {
      if (!mounted) return;
      setState(() {
        _activeWorkout = workout;
      });
    });
  }

  @override
  void dispose() {
    _activeWorkoutSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final kpis = _historyLoaded ? exerciseKpis(_history) : ExerciseKpis.empty;

    return Scaffold(
      backgroundColor: ThemeColors.kSurface,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SCR-1: Context bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                          tooltip: 'Volver',
                          onPressed: () => Navigator.pop(context),
                          color: ThemeColors.kOnSurfaceVariant,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Text(
                                'BASE DE DATOS',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: ThemeColors.kOnSurfaceVariant,
                                ),
                              ),
                              Text(
                                'Detalle de Ejercicio',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: ThemeColors.kOnSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.star_border_rounded, size: 22),
                          tooltip: 'Favorito',
                          onPressed: () {},
                          color: ThemeColors.kOnSurfaceVariant,
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 22),
                          tooltip: 'Más opciones',
                          onPressed: () {},
                          color: ThemeColors.kOnSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: ThemeColors.kSurfaceContainerHighest),
                  // SCR-2: Identidad
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildIdentityBadgesWithTitle(exercise),
                  ),
                  // SCR-3: Media / GIF
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: _buildMedia(exercise),
                  ),
                  // SCR-4: KPI 2×2
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildKpiGrid(kpis),
                  ),
                  // SCR-5: Gráfico de progresión
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildProgressChartSection(),
                  ),
                  // SCR-6: Biomecánica & Cues
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 24, 0, 0),
                    child: Divider(height: 1, color: ThemeColors.kSurfaceContainerHighest),
                  ),
                  _buildCuesSection(exercise),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: _buildActivationBar(exercise),
                  ),
                  // SCR-7: Historial de sesiones
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildSessionHistory(),
                  ),
                  // SCR-9: Descanso
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                    child: _buildRestSetting(),
                  ),
                  if (_steps.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _buildLanguageSwitch(),
                    ),
                  if (exercise.attribution != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        exercise.attribution!,
                        style: const TextStyle(fontSize: 10, color: ThemeColors.kOutline),
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCTABar(),
    );
  }

  Widget _buildMedia(Exercise exercise) {
    final local = _localMedia(exercise);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: ThemeColors.kSurfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.fromBorderSide(BorderSide(color: ThemeColors.kSurfaceContainerHighest)),
      ),
      clipBehavior: Clip.antiAlias,
      child: _gifFile != null
          ? FutureBuilder<File?>(
              future: Future.value(_gifFile),
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file != null) {
                  final dpi = (MediaQuery.of(context).devicePixelRatio * 220).round();
                  return Image.file(file, fit: BoxFit.contain, scale: 1.0,
                      cacheWidth: dpi, cacheHeight: dpi);
                }
                return local;
              },
            )
          : local,
    );
  }

  Widget _localMedia(Exercise exercise) {
    final imagePath = exercise.imagePath;
    if (imagePath == null) return const ThumbFallback(radius: 16);
    return Image.asset(
      thumbAsset(imagePath),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const ThumbFallback(radius: 16),
    );
  }

  Widget _buildIdentityBadgesWithTitle(Exercise exercise) {
    final muscleLabelText = muscleLabel(exercise.target);
    final exerciseName = Text(
      exercise.name,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: ThemeColors.kOnSurface,
        height: 1.2,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        exerciseName,
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _badge(exercise.equipment),
            _badge(exercise.bodyPart),
            _badgeHighlight(muscleLabelText),
            if (exercise.secondaryMuscles != null &&
                exercise.secondaryMuscles!.isNotEmpty)
              ..._secondaryMuscleBadges(exercise.secondaryMuscles!),
          ],
        ),
      ],
    );
  }

  List<Widget> _secondaryMuscleBadges(String secondaries) {
    final labels = secondaries.split(',').map((m) => muscleLabel(m.trim())).toList();
    return labels.map((label) => _badge(label)).toList();
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: ThemeColors.kSurfaceContainerHighest,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: ThemeColors.kOnSurfaceVariant,
        ),
      ),
    );
  }

  Widget _badgeHighlight(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ThemeColors.kSurfaceContainerHighest,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
        border: Border.all(color: ThemeColors.kOnSurface.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: ThemeColors.kOnSurface,
        ),
      ),
    );
  }

  Widget _buildLanguageSwitch() {
    final languages = _steps.keys.toList()..sort();
    return Wrap(
      spacing: 8,
      children: [
        for (final language in languages)
          ChoiceChip(
            label: Text(language.toUpperCase()),
            selected: language == _language,
            onSelected: (_) => setState(() => _language = language),
            showCheckmark: false,
            selectedColor: ThemeColors.kSurfaceContainerHighest,
            backgroundColor: ThemeColors.kSurfaceContainerLow,
            side: const BorderSide(color: ThemeColors.kSurfaceContainerHighest),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: language == _language ? ThemeColors.kPrimary : ThemeColors.kOnSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildStep(int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ThemeColors.kOutline,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
                color: ThemeColors.kOnSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestSetting() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: ThemeColors.kSurfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: ThemeColors.kOnSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Descanso por defecto',
              style: theme.textTheme.bodyLarge?.copyWith(color: ThemeColors.kOnSurface),
            ),
          ),
          Text(
            '$_restSeconds s',
            style: theme.textTheme.titleMedium?.copyWith(
              color: ThemeColors.kPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            key: const Key('rest-detail-minus'),
            tooltip: 'Reducir 15 s',
            onPressed: _restSeconds > 15 ? () => _changeRest(-15) : null,
            icon: const Icon(Icons.remove_rounded, color: ThemeColors.kOnSurfaceVariant),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              backgroundColor: ThemeColors.kSurfaceContainerHighest,
              shape: const StadiumBorder(),
            ),
          ),
          IconButton(
            key: const Key('rest-detail-plus'),
            tooltip: 'Aumentar 15 s',
            onPressed: _restSeconds < 300 ? () => _changeRest(15) : null,
            icon: const Icon(Icons.add_rounded, color: ThemeColors.kOnSurfaceVariant),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              backgroundColor: ThemeColors.kSurfaceContainerHighest,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeRest(int deltaSeconds) async {
    final next = (_restSeconds + deltaSeconds).clamp(15, 300);
    setState(() => _restSeconds = next);
  }

  Widget _buildProgressChartSection() {
    return ChartWidget.ExerciseProgressChart(
      sessions: _history,
      metric: _selectedMetric,
      window: _selectedWindow,
      onMetricChanged: (metric) => setState(() => _selectedMetric = metric),
      onWindowChanged: (window) => setState(() => _selectedWindow = window),
    );
  }

  Widget _buildKpiGrid(ExerciseKpis kpis) {
    final units = UnitSystemScope.of(context);
    final weightUnit = weightUnitOf(units);

    final bestE1rmText = kpis.bestE1rm != null
        ? '${formatWeightKg(kpis.bestE1rm!, units)} $weightUnit'
        : '--';

    final prDelta = kpis.secondBestE1rm != null && kpis.bestE1rm != null
        ? '+${(kpis.bestE1rm! - kpis.secondBestE1rm!).toStringAsFixed(1)} kg PR'
        : '';

    final bestE1rmDate = kpis.bestE1rmAt != null
        ? 'Basado en Epley · ${_sessionDateLabel(kpis.bestE1rmAt!)}'
        : 'Sin series completadas';

    final maxLoadText = kpis.topSet != null
        ? '${formatWeightKg(kpis.topSet!.weightKg, units)} $weightUnit'
        : '--';

    final maxLoadSub = kpis.topSet != null
        ? 'Top Set · ${kpis.topSet!.reps} reps @ RIR ${kpis.topSet!.rir ?? 0}'
        : 'Sin series completadas';

    final maxVolumeText = kpis.maxSessionVolume != null
        ? '${formatWeightKg(kpis.maxSessionVolume!, units)} $weightUnit'
        : '--';

    final maxVolumeSub = kpis.maxSessionVolume != null
        ? 'Récord en 1 sesión (${kpis.maxSessionVolumeSets} sets)'
        : 'Sin series completadas';

    final totalSetsText = kpis.sessionCount > 0
        ? '${kpis.totalSets} series'
        : '--';

    final totalSetsSub = kpis.sessionCount > 0
        ? '${kpis.sessionCount} entrenamientos reg.'
        : 'Sin series completadas';

    Widget kpiCard({
      required String label,
      required String value,
      String? subtitle,
      String? chip,
      IconData? actionIcon,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: ThemeColors.kSurfaceContainer,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.fromBorderSide(BorderSide(color: ThemeColors.kSurfaceContainerHighest)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: ThemeColors.kOnSurfaceVariant,
                      ),
                    ),
                  ),
                  if (chip != null && chip.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ThemeColors.kSurfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chip,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ThemeColors.kOnSurface,
                        ),
                      ),
                    ),
                  if (actionIcon != null) ...[
                    const SizedBox(width: 4),
                    Icon(actionIcon, size: 16, color: ThemeColors.kOnSurfaceVariant),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: ThemeColors.kOnSurface,
                  height: 1.1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: ThemeColors.kOnSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: kpiCard(
                label: '1RM Estimado',
                value: bestE1rmText,
                subtitle: bestE1rmDate,
                chip: prDelta.isNotEmpty ? prDelta : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: kpiCard(
                label: 'Carga Máxima',
                value: maxLoadText,
                subtitle: maxLoadSub,
                actionIcon: Icons.open_in_new_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: kpiCard(
                label: 'Volumen Máx.',
                value: maxVolumeText,
                subtitle: maxVolumeSub,
                actionIcon: Icons.trending_up_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: kpiCard(
                label: 'Total Series',
                value: totalSetsText,
                subtitle: totalSetsSub,
                actionIcon: Icons.history_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCuesSection(Exercise exercise) {
    final steps = _steps[_language] ?? const <String>[];

    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Row(
        children: const [
          Icon(Icons.tune_rounded, size: 18, color: ThemeColors.kOnSurfaceVariant),
          SizedBox(width: 10),
          Text(
            'Biomecánica & Cues Técnicos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ThemeColors.kOnSurface,
            ),
          ),
        ],
      ),
      children: [
        const SizedBox(height: 8),
        if (steps.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Sin instrucciones disponibles',
              style: TextStyle(fontSize: 14, color: ThemeColors.kOnSurfaceVariant),
            ),
          )
        else
          for (var i = 0; i < steps.length; i++)
            _buildStep(i + 1, steps[i]),
        if (_steps.length > 1) ...[
          const SizedBox(height: 8),
          _buildLanguageSwitch(),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActivationBar(Exercise exercise) {
    final primaryTarget = exercise.target;
    final secondaryMuscles = exercise.secondaryMuscles;

    final secondaryList = secondaryMuscles != null
        ? secondaryMuscles.split(',').map((m) => m.trim()).where((m) => m.isNotEmpty).toList()
        : <String>[];

    final primaryFlex = 7;
    final secondaryFlex = secondaryList.isEmpty ? 0 : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Distribución de activación',
                style: const TextStyle(
                  fontSize: 12,
                  color: ThemeColors.kOnSurfaceVariant,
                ),
              ),
            ),
            Text(
              'Foco Principal: ${muscleLabel(primaryTarget)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: ThemeColors.kOnSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                Expanded(
                  flex: primaryFlex,
                  child: Container(color: ThemeColors.kOnSurface),
                ),
                if (secondaryList.isNotEmpty)
                  Expanded(
                    flex: secondaryFlex,
                    child: Container(color: ThemeColors.kSurfaceContainerHighest),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          children: [
            _muscleChip(muscleLabel(primaryTarget), '${(primaryFlex * 100 / (primaryFlex + secondaryFlex)).round()}%', ThemeColors.kOnSurface),
            if (secondaryList.isNotEmpty)
              for (var i = 0; i < secondaryList.length; i++)
                _muscleChip(
                  muscleLabel(secondaryList[i]),
                  '${(secondaryFlex * 100 / (primaryFlex + secondaryFlex) / secondaryList.length).round()}%',
                  ThemeColors.kOnSurfaceVariant,
                ),
          ],
        ),
      ],
    );
  }

  Widget _muscleChip(String label, String percent, Color dotColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label $percent',
          style: const TextStyle(fontSize: 11, color: ThemeColors.kOnSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildSessionHistory() {
    if (!_historyLoaded) return const SizedBox.shrink();
    if (_history.isEmpty) return _buildHistoryEmpty();

    final bestE1rm = exerciseKpis(_history).bestE1rm;
    final units = UnitSystemScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Historial de Sesiones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ThemeColors.kOnSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_history.length + _historyUpcoming.length} registros',
              style: const TextStyle(fontSize: 12, color: ThemeColors.kOnSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildExpandedSessionCard(
          _history.first,
          bestE1rm: bestE1rm,
          units: units,
        ),
        for (final session in _history.skip(1))
          _buildCondensedSessionCard(session, units: units),
        if (_historyUpcoming.isNotEmpty || _historyLoading) ...[
          const SizedBox(height: 12),
          _buildLoadMoreButton(),
        ],
      ],
    );
  }

  Widget _buildHistoryEmpty() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: ThemeColors.kSurfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aún no hay sesiones con este ejercicio',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: ThemeColors.kOnSurface,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Usa «Añadir a Rutina o Iniciar Sesión» para registrar tu primera serie.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: ThemeColors.kOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSessionCard(
    ExerciseSessionSummary session, {
    required double? bestE1rm,
    required String units,
  }) {
    final rirMean = session.rirMean;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 0),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: ThemeColors.kSurfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSessionHeader(session, units: units),
          const SizedBox(height: 10),
          _buildSetTable(session, bestE1rm: bestE1rm, units: units),
          const SizedBox(height: 8),
          Text(
            rirMean != null
                ? 'RPE Promedio: ${(10 - rirMean).toStringAsFixed(1)}'
                : 'RIR medio: —',
            style: const TextStyle(
              fontSize: 11,
              color: ThemeColors.kOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCondensedSessionCard(
    ExerciseSessionSummary session, {
    required String units,
  }) {
    final top = exerciseKpis([session]).topSet;
    final weight = weightUnitOf(units);
    final topText = top != null
        ? 'Top: ${formatWeightKg(top.weightKg, units)} $weight × ${top.reps} reps'
        : '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: ThemeColors.kSurfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSessionHeader(session, units: units),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: ThemeColors.kSurfaceContainerLow,
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Icon(Icons.autorenew_rounded, size: 14, color: ThemeColors.kOnSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${session.completedSetCount} sets completados',
                    style: const TextStyle(fontSize: 12, color: ThemeColors.kOnSurface),
                  ),
                ),
                if (topText.isNotEmpty)
                  Text(
                    topText,
                    style: const TextStyle(fontSize: 11, color: ThemeColors.kOnSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionHeader(
    ExerciseSessionSummary session, {
    required String units,
  }) {
    final name = session.name;
    final title = (name == null || name.isEmpty) ? 'Sesión' : name;
    final weight = weightUnitOf(units);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: ThemeColors.kPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ThemeColors.kOnSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${_sessionDateLabel(session.endedAt)} · '
                '${_relativeLabel(session.endedAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: ThemeColors.kOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${formatWeightKg(session.volumeKg, units)} $weight',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: ThemeColors.kOnSurface,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Volumen total',
              style: TextStyle(
                fontSize: 10,
                color: ThemeColors.kOnSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSetTable(
    ExerciseSessionSummary session, {
    required double? bestE1rm,
    required String units,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      decoration: const BoxDecoration(
        color: ThemeColors.kSurfaceContainerLow,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Column(
        children: [
          _buildSetHeaderRow(),
          for (var i = 0; i < session.sets.length; i++)
            _buildSetRow(
              session.sets[i],
              index: i,
              isLast: i == session.sets.length - 1,
              bestE1rm: bestE1rm,
              units: units,
            ),
        ],
      ),
    );
  }

  Widget _buildSetHeaderRow() {
    const headerStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: ThemeColors.kOnSurfaceVariant,
    );
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ThemeColors.kSurfaceContainerHighest),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 56,
            child: Text('SET', style: headerStyle),
          ),
          Expanded(
            child: Text(
              'PESO × REPS',
              textAlign: TextAlign.center,
              style: headerStyle,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              'RIR',
              textAlign: TextAlign.center,
              style: headerStyle,
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              'EST. 1RM',
              textAlign: TextAlign.right,
              style: headerStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(
    ExerciseSetRow set, {
    required int index,
    required bool isLast,
    required double? bestE1rm,
    required String units,
  }) {
    final isWarmup = set.setType == 'warmup';
    final label = isWarmup ? '${index + 1} (Cal.)' : '${index + 1}';
    final star = bestE1rm != null && set.countsForStats && set.e1rm == bestE1rm;
    final weight = weightUnitOf(units);
    final load =
        '${formatWeightKg(set.weightKg, units)} $weight × ${set.reps}';
    final e1rm = set.e1rm;

    final setCell = Text(
      star ? '$label ☆' : label,
      maxLines: 1,
      style: TextStyle(
        fontSize: 11,
        fontWeight: star ? FontWeight.w600 : FontWeight.w500,
        color: star ? ThemeColors.kPrimary : ThemeColors.kOnSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: isLast
          ? null
          : const BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: ThemeColors.kSurfaceContainerHighest),
              ),
            ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: star
                ? Semantics(
                    label: 'Mejor e1RM histórico',
                    child: setCell,
                  )
                : setCell,
          ),
          Expanded(
            child: Text(
              load,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: star ? FontWeight.w600 : FontWeight.w500,
                color: ThemeColors.kOnSurface,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              set.rir != null ? 'RIR ${set.rir}' : '—',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: ThemeColors.kOnSurfaceVariant,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              e1rm != null ? '${formatWeightKg(e1rm, units)} $weight' : '—',
              textAlign: TextAlign.right,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                color: star ? ThemeColors.kPrimary : ThemeColors.kOnSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    final loading = _historyLoading;
    final label = loading
        ? 'Cargando…'
        : 'Cargar sesiones anteriores (${_historyUpcoming.length} más)';
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        key: const Key('history-load-more'),
        onPressed: loading ? null : _loadMoreHistory,
        style: FilledButton.styleFrom(
          backgroundColor: ThemeColors.kSurfaceContainerHighest,
          foregroundColor: ThemeColors.kOnSurface,
          disabledBackgroundColor: ThemeColors.kSurfaceContainer,
          disabledForegroundColor: ThemeColors.kOnSurfaceVariant,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history, size: 16, color: ThemeColors.kOnSurfaceVariant),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitialHistory() async {
    final repo = widget.workoutRepository;
    if (repo == null) return;
    final first = await repo.exerciseHistory(
      exerciseId: widget.exercise.id,
      limit: _historyPageSize,
      offset: 0,
    );
    var next = const <ExerciseSessionSummary>[];
    if (first.length == _historyPageSize) {
      next = await repo.exerciseHistory(
        exerciseId: widget.exercise.id,
        limit: _historyPageSize,
        offset: first.length,
      );
    }
    if (!mounted) return;
    setState(() {
      _history.addAll(first);
      _historyUpcoming = next;
      _historyLoaded = true;
    });
  }

  Future<void> _loadMoreHistory() async {
    if (_historyLoading) return;
    final repo = widget.workoutRepository;
    if (repo == null) return;
    setState(() {
      _history.addAll(_historyUpcoming);
      _historyUpcoming = const [];
      _historyLoading = true;
    });
    final next = await repo.exerciseHistory(
      exerciseId: widget.exercise.id,
      limit: _historyPageSize,
      offset: _history.length,
    );
    if (!mounted) return;
    setState(() {
      _historyUpcoming = next;
      _historyLoading = false;
    });
  }

  String _sessionDateLabel(DateTime endedAt) {
    final day = endedAt.toLocal();
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${day.day} ${months[day.month - 1]} ${day.year}';
  }

  String _relativeLabel(DateTime endedAt) {
    final date = endedAt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    if (diff < 30) return 'Hace $diff días';
    final months = (diff / 30).floor();
    if (months < 12) return 'Hace $months ${months == 1 ? 'mes' : 'meses'}';
    final years = (diff / 365).floor();
    final yearsLabel = years < 1 ? 1 : years;
    return 'Hace $yearsLabel ${yearsLabel == 1 ? 'año' : 'años'}';
  }

  Widget _buildCTABar() {
    final hasActiveWorkout = _activeWorkout != null;
    return Semantics(
      button: true,
      label: hasActiveWorkout ? 'Añadir ejercicio a la sesión activa' : 'Iniciar sesión y añadir ejercicio',
      child: Container(
        key: const Key('exercise-info-cta'),
        height: 64,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: ThemeColors.kOnSurface,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            onTap: () async {
              final workoutRepo = widget.workoutRepository;
              if (workoutRepo == null) return;
              if (hasActiveWorkout) {
                await workoutRepo.addExercise(
                  workoutId: _activeWorkout!.id,
                  exerciseId: widget.exercise.id,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Añadido a la sesión activa!')),
                );
              } else {
                final newWorkout = await workoutRepo.startWorkout();
                if (!mounted) return;
                await workoutRepo.addExercise(
                  workoutId: newWorkout.id,
                  exerciseId: widget.exercise.id,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sesión iniciada con el ejercicio')),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline_rounded, size: 20, color: ThemeColors.kSurface),
                  const SizedBox(width: 10),
                  const Text(
                    'Añadir a Rutina o Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ThemeColors.kSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
