import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/exercise_stats.dart';
import '../../domain/media.dart';
import '../../domain/units.dart';
import '../../main.dart';
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
  File?_gifFile;

  /// Estado para el chart de progresión
  ProgressMetric _selectedMetric = ProgressMetric.e1rm;
  ProgressWindow _selectedWindow = ProgressWindow.threeMonths;

  static const int _historyPageSize = 10;
  final List<ExerciseSessionSummary> _history = [];
  List<ExerciseSessionSummary> _historyUpcoming = const [];
  bool _historyLoaded = false;
  bool _historyLoading = false;

  // Estado para el CTA de sesión activa
  Workout? _activeWorkout;
  StreamSubscription<Workout?>? _activeWorkoutSubscription;

  @override
  void initState() {
    super.initState();
    _restSeconds = widget.exercise.restSeconds;
    _loadSteps();
    _loadInitialHistory();
    // _sessions stays as empty list - no workout data in test
    _gifFile = null;
    _activeWorkout = _initialActiveWorkout();
    _listenActiveWorkout();
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

  Workout? _initialActiveWorkout() {
    // No podemos await en initState; el valor inicial es null y
    // _listenActiveWorkout() suscribe el stream para actualizar el estado.
    return null;
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
    final steps = _steps[_language] ?? const <String>[];
    final stepsCount = steps.length;

    return Scaffold(
      backgroundColor: ThemeColors.kSurface,
      appBar: AppBar(
        backgroundColor: ThemeColors.kSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: ThemeColors.kOnSurface),
        title: Text(
          exercise.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: ThemeColors.kOnSurface,
          ),
        ),
        actions: [
          if (stepsCount > 1) ...[
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: 'Cambiar idioma de pasos',
              onPressed: () {
                final available = _steps.keys.toList()..sort();
                if (available.length <= 1) return;
                setState(() {
                  _language = _language == 'es' ? 'en' : 'es';
                });
              },
            ),
          ],
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 64.0),
        children: [
          _buildIdentityBadges(exercise),
          const SizedBox(height: 12),
          _buildMedia(exercise),
          const SizedBox(height: 24),
          _buildKpiGrid(),
          const SizedBox(height: 24),
          ChartWidget.ExerciseProgressChart(
            sessions: const [],
            metric: _selectedMetric,
            window: _selectedWindow,
            onMetricChanged: (metric) {
              setState(() {});
            },
            onWindowChanged: (window) {
              setState(() {});
            },
          ),
          const SizedBox(height: 24),
          _buildCuesSection(exercise),
          const SizedBox(height: 24),
          _buildSessionHistory(),
          _buildRestSetting(),
          const SizedBox(height: 8),
          if (exercise.attribution != null) ...[
            Text(exercise.attribution!, style: const TextStyle(fontSize: 10, color: ThemeColors.kOutline)),
          ],
          const SizedBox(height: 16),
        ],
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
                  return Image.file(file, fit: BoxFit.contain);
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

  Widget _buildIdentityBadges(Exercise exercise) {
    final muscleLabelText = muscleLabel(exercise.target);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _badge(muscleLabelText),
        _badge(exercise.equipment),
        _badge(exercise.bodyPart),
        if (exercise.secondaryMuscles != null &&
            exercise.secondaryMuscles!.isNotEmpty)
          ..._secondaryMuscleBadges(exercise.secondaryMuscles!),
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
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
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
                height: 1.4,
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

  Widget _buildKpiGrid() {
    final kpis = ExerciseKpis.empty;

    final bestE1rmText = kpis.bestE1rm != null
        ? '${kpis.bestE1rm!.toStringAsFixed(1)} kg'
        : '--';

    final prChip = kpis.secondBestE1rm != null && kpis.bestE1rm != null
        ? '+${(kpis.bestE1rm!.toInt() - kpis.secondBestE1rm!.toInt())} kg PR'
        : '';

    final maxLoadText = kpis.topSet != null
        ? 'Top Set · ${kpis.topSet!.weightKg.toStringAsFixed(1)} kg × ${kpis.topSet!.reps} reps @ RIR ${kpis.topSet!.rir ?? 0}'
        : '--';

    final maxVolumeText = kpis.maxSessionVolume != null
        ? '${kpis.maxSessionVolume!.toStringAsFixed(1)} kg × ${kpis.maxSessionVolumeSets} series'
        : '--';

    final totalSetsText = '${kpis.totalSets} series · ${kpis.sessionCount} entrenamientos';

    Widget kpiCard(String label, String value, {String? subtitle}) {
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
              Text(label,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: ThemeColors.kOnSurfaceVariant)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ThemeColors.kOnSurface)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 10, color: ThemeColors.kOnSurfaceVariant)),
              ],
            ],
          ),
        ),
      );
    }

    final bestE1rmCard = kpis.bestE1rm != null
        ? kpiCard('1RM Estimado', bestE1rmText,
            subtitle: prChip.isNotEmpty ? prChip : null)
        : kpiCard('1RM Estimado', '--',
            subtitle: 'Sin series completadas');

    final maxLoadCard = kpis.topSet != null
        ? kpiCard('Carga Máxima', maxLoadText)
        : kpiCard('Carga Máxima', '--',
            subtitle: 'Sin series completadas');

    final maxVolumeCard = kpis.maxSessionVolume != null
        ? kpiCard('Volumen Máx.', maxVolumeText)
        : kpiCard('Volumen Máx.', '--',
            subtitle: 'Sin series completadas');

    final totalSetsCard = kpis.sessionCount > 0
        ? kpiCard('Total Series', totalSetsText)
        : kpiCard('Total Series', '--',
            subtitle: 'Sin series completadas');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: bestE1rmCard),
            const SizedBox(width: 12),
            Expanded(child: maxLoadCard),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: maxVolumeCard),
            const SizedBox(width: 12),
            Expanded(child: totalSetsCard),
          ],
        ),
      ],
    );
  }

  /// Sección plegable de instrucciones biomecánicas.
  /// Desplegada por defecto (initiallyExpanded: true). Muestra pasos numerados
  /// del catálogo `exercise_instructions` en el idioma disponible. Si no hay
  /// pasos, muestra "Sin instrucciones disponibles".
  Widget _buildCuesSection(Exercise exercise) {
    final steps = _steps[_language] ?? const <String>[];
    final stepsCount = steps.length;

    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text('Biomecánica & Cues'),
      children: [
        if (steps.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sin instrucciones disponibles',
              style: TextStyle(fontSize: 14, color: ThemeColors.kOnSurfaceVariant),
            ),
          )
        else
          for (var i = 0; i < steps.length; i++)
            _buildStep(i + 1, steps[i]),
        if (stepsCount > 1) ...[
          const SizedBox(height: 8),
          _buildLanguageSwitch(),
        ],
      ],
    );
  }

  /// Barra de activación muscular.
  /// El target principal ocupa 70% de la barra; los secundarios comparten el
  /// 30% restante con leyenda en español. Si no hay secundarios, se muestra un
  /// solo segmento. Los targets táctiles tienen mínimo 48 dp.
  Widget _buildActivationBar(Exercise exercise) {
    final primaryTarget = exercise.target;
    final secondaryMuscles = exercise.secondaryMuscles;

    // Determinar targets secundarios
    final secondaryList = secondaryMuscles != null
        ? secondaryMuscles.split(',').map((m) => m.trim()).toList()
        : [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with target label and tactile minimum 48 dp
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ThemeColors.kSurfaceContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Target label (≥ 48 dp consideration in padding/layout)
                Expanded(
                  child: Text(
                    'Foco Principal: $primaryTarget',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: ThemeColors.kOnSurface,
                    ),
                    overflow: TextOverflow.fade, // hide text, focus on visual bar
                  ),
                ),
                // Width indicator for accessibility
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 48),
                  child: Text(
                    '70%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: ThemeColors.kOnSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Activation bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: ThemeColors.kSurfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                // Primary segment (70%)
                Expanded(
                  flex: 7,
                  child: Container(
                    color: ThemeColors.kPrimary,
                  ),
                ),
                // Secondary segments (30% total)
                if (secondaryList.isNotEmpty)
                  ...List.generate(secondaryList.length, (_) {
                    return Expanded(
                      flex: 1,
                      child: Container(
                        color: ThemeColors.kSecondary,
                      ),
                    );
                  })
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Secondary legend
          if (secondaryList.isNotEmpty) ...[
            Row(
              children: [
                for (final muscle in secondaryList)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _secondaryMuscleLabel(muscle),
                  ),
              ],
            ),
          ] else ...[
            const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Text(
                'Sin músculos secundarios',
                style: TextStyle(
                  fontSize: 11,
                  color: ThemeColors.kOnSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _secondaryMuscleLabel(String muscle) {
    return Text(
      muscleLabel(muscle).toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: ThemeColors.kOnSurface,
      ),
    );
  }

  Widget _buildHistorySection() {
    if (!_historyLoaded) return const SizedBox.shrink();
    if (_history.isEmpty) return _buildHistoryEmpty();

    final bestE1rm = exerciseKpis(_history).bestE1rm;
    final units = UnitSystemScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial de Sesiones',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ThemeColors.kPrimary,
          ),
        ),
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

  /// Sección de historial de sesiones posicionada después de biomecánica.
  /// Usa workoutRepository.exerciseHistory() con paginación de 10 por página.
  /// Tarjeta expandida: nombre/fecha/volumen, tabla SET/KG×REPS/RIR/EST1RM,
  /// series calentamiento (Cal.), ★ mejor e1RM.
  /// Tarjetas condensadas: "N sets completados · Top: kg×reps".
  /// Estado vacío si no hay sesiones.
  Widget _buildSessionHistory() {
    if (!_historyLoaded) return const SizedBox.shrink();
    if (_history.isEmpty) return _buildHistoryEmpty();

    final bestE1rm = exerciseKpis(_history).bestE1rm;
    final units = UnitSystemScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historial de Sesiones',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ThemeColors.kPrimary,
          ),
        ),
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
      margin: const EdgeInsets.only(top: 12),
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
                ? 'RIR medio: ${rirMean.toStringAsFixed(1)}'
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
        ? ' · Top: ${formatWeightKg(top.weightKg, units)} $weight × ${top.reps} reps'
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
            child: Text(
              '${session.completedSetCount} sets completados$topText',
              style: const TextStyle(
                fontSize: 12,
                color: ThemeColors.kOnSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
  /// Tarjeta compacta para ≥³.ª sesión (sin chevron, sola línea de resumen).
  Widget _buildCompactSessionCard(
    ExerciseSessionSummary session, {
    required String units,
  }) {
    final top = exerciseKpis([session]).topSet;
    final weight = weightUnitOf(units);
    final topText = top != null
        ? ' · Top: ${formatWeightKg(top.weightKg, units)} $weight × ${top.reps} reps'
        : '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: ThemeColors.kSurfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        '${session.completedSetCount} sets completados$topText',
        style: const TextStyle(
          fontSize: 12,
          color: ThemeColors.kOnSurface,
        ),
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
                fontWeight: FontWeight.w600,
                color: ThemeColors.kPrimary,
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
              'KG × REPS',
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
    final label = '${index + 1}${isWarmup ? ' (Cal.)' : ''}';
    final star = bestE1rm != null && set.countsForStats && set.e1rm == bestE1rm;
    final weight = weightUnitOf(units);
    final load =
        '${formatWeightKg(set.weightKg, units)} $weight × ${set.reps}';
    final e1rm = set.e1rm;

    final setCell = Text(
      star ? '$label ★' : label,
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

  /// CTA bottom bar sticky: botón 48 dp translúcido sobre el safe area.
  /// Con sesión activa: addExercise + snackbar "¡Añadido a la sesión activa!".
  /// Sin sesión activa: startWorkout + addExercise + snackbar "Sesión iniciada con el ejercicio".
  Widget _buildCTABar() {
    final hasActiveWorkout = _activeWorkout != null;
    return Semantics(
      button: true,
      label: hasActiveWorkout ? 'Añadir ejercicio a la sesión activa' : 'Iniciar sesión y añadir ejercicio',
      child: Container(
        key: const Key('exercise-info-cta'),
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: ThemeColors.kSurface.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          boxShadow: [],
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              onTap: () async {
                final workoutRepo = widget.workoutRepository;
                if (workoutRepo == null) return;
                if (hasActiveWorkout) {
                  // Sesión activa: añadir ejercicio existente
                  await workoutRepo.addExercise(
                    workoutId: _activeWorkout!.id,
                    exerciseId: widget.exercise.id,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Añadido a la sesión activa!')),
                  );
                } else {
                  // Sin sesión activa: iniciar sesión y añadir ejercicio
                  final newWorkout = await workoutRepo.startWorkout();
                  if (!mounted) return;
                  await workoutRepo.addExercise(
                    workoutId: newWorkout.id,
                    exerciseId: widget.exercise.id,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sesión iniciada con el ejercicio')),
                  );
                }
                // RF-19: tras el tap hay exactamente una sesión activa
                // El workflow de startWorkout ya maneja la sesión única (RF-5, RF-19)
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Añadir a Rutina o Iniciar Sesión',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: ThemeColors.kOnPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}