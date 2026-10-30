import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/local/database.dart';
import '../../data/repositories/body_metric_repository.dart';
import '../../domain/body_composition.dart';
import '../../domain/body_metrics.dart';
import '../../domain/goals.dart';
import '../../domain/muscle_fatigue.dart';
import '../../domain/muscle_map_adaptor.dart';
import '../../domain/progress_photos.dart';
import '../../domain/units.dart';
import '../../domain/weight_progress.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/capped_scroll.dart';
import '../widgets/fatigue_trend_chart.dart' as FTC;
import '../widgets/muscle_map.dart';
import '../widgets/zone_volume_chart.dart' as ZVC;
import '../widgets/weight_trend.dart';
import 'body_metric_editor_view.dart';
import 'goal_editor_view.dart';
import 'measures_view.dart';
import 'soon_view.dart';

const int _visibleGoalCards = 3;
const double _goalCardHeight = 132;

/// Dashboard de metas y cuerpo (spec 005 + 006 + 007): mapa de fatiga
/// muscular, listado de metas con % de cumplimiento, logros, tendencia de
/// peso (30/90/365 días) y tabla de medidas con deltas frente al registro
/// anterior.
class ProgressView extends StatefulWidget {
  const ProgressView({super.key});

  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  late final Stream<List<Goal>> _goals;
  late final Stream<List<BodyMetric>> _records;
  late final Stream<Map<String, double>> _fatigue;
  late final Stream<LocalProfile> _profile;
  Map<String, String> _exerciseNames = const {};
  int _range = 30;

  @override
  void initState() {
    super.initState();
    _goals = goalRepository.watchGoals();
    _records = bodyMetricRepository.watchRecords();
    _fatigue = fatigueRepository.watchFatigue();
    _profile = profileRepository.watchProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await goalRepository.recalculate();
      // Spec 007 (H2/RF-6): el mapa se actualiza solo al abrir el tab.
      await fatigueRepository.ensureFresh();
      final names = await catalogRepository.exerciseNames();
      if (!mounted) return;
      setState(() => _exerciseNames = names);
    });
  }

  Future<void> _openEditor([Goal? goal]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GoalEditorView(goal: goal),
      ),
    );
  }

  Future<void> _deleteGoal(Goal goal) async {
    final confirmed = await _confirm(
      title: 'Borrar meta',
      message: '¿Borrar "${_goalTitle(goal)}"?',
    );
    if (confirmed != true || !mounted) return;
    await goalRepository.deleteGoal(goal.id);
  }

  Future<void> _addRecord() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BodyMetricEditorView(),
      ),
    );
  }

  Future<void> _editRecord(BodyMetric record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BodyMetricEditorView(record: record),
      ),
    );
  }

  Future<void> _deleteRecord(BodyMetric record) async {
    final confirmed = await _confirm(
      title: 'Borrar registro',
      message: '¿Borrar el registro del '
          '${_formatDate(record.date)}?',
    );
    if (confirmed != true || !mounted) return;
    await bodyMetricRepository.delete(record.date);
    await goalRepository.recalculate();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registro borrado')),
    );
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: kSurfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: kSurfaceContainerHighest),
        ),
        title: Text(title),
        content: Text(message),
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
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _headerRow(),
        Expanded(
          child: StreamBuilder<List<Goal>>(
            stream: _goals,
            builder: (context, goalsSnap) {
              final goals = goalsSnap.hasData ? _sorted(goalsSnap.data!) : null;
              return StreamBuilder<List<BodyMetric>>(
                stream: _records,
                builder: (context, recordsSnap) {
                  if (goals == null && !recordsSnap.hasData) {
                    return const Center(
                      child: Text(
                        'Cargando...',
                        style:
                            TextStyle(color: kOnSurfaceVariant, fontSize: 14),
                      ),
                    );
                  }
                  final records = recordsSnap.data ?? const <BodyMetric>[];
                  return StreamBuilder<Map<String, double>>(
                    stream: _fatigue,
                    builder: (context, fatigueSnap) {
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        children: [
                          _rangeHeader(),
                          _MetricsSection(
                            range: _range,
                            records: records,
                            weightGoal: goals == null
                                ? null
                                : _activeWeightGoal(goals),
                            onEdit: _editRecord,
                            onDelete: _deleteRecord,
                          ),
                          StreamBuilder<LocalProfile>(
                            stream: _profile,
                            builder: (context, profileSnap) =>
                                _CompositionSection(
                              records: records,
                              onAdd: _addRecord,
                              sex: profileSnap.data?.sex,
                              heightCm: profileSnap.data?.heightCm,
                            ),
                          ),
                          _FatigueSection(fatigue: fatigueSnap.data),
                          if (goals != null) ..._goalSection(goals),
                          const _MeasuresEntry(),
                          const _PhotosSection(),
                          const _DevicesCallout(),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        _newGoalBar(),
      ],
    );
  }

  List<Goal> _sorted(List<Goal> goals) {
    const rank = {'active': 0, 'achieved': 1, 'abandoned': 2};
    final sorted = [...goals];
    sorted.sort((a, b) {
      final byStatus = rank[a.status]!.compareTo(rank[b.status]!);
      if (byStatus != 0) return byStatus;
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  /// Meta de peso activa que alimenta la línea discontinua de la tarjeta
  /// (RF-23); si no hay, la tarjeta se dibuja sin meta.
  static Goal? _activeWeightGoal(List<Goal> goals) {
    for (final goal in goals) {
      if (goal.type == 'bodyweight' && goal.status == 'active') return goal;
    }
    return null;
  }

  List<Widget> _goalSection(List<Goal> goals) {
    if (goals.isEmpty) return const [_EmptyGoals()];
    final achieved = [
      for (final goal in goals)
        if (goal.status == 'achieved') goal,
    ];
    return [
      if (achieved.isNotEmpty)
        _AchievementsBanner(goals: achieved),
      CappedScroll(
        itemCount: goals.length,
        visibleItems: _visibleGoalCards,
        itemHeight: _goalCardHeight,
        child: Column(
          children: [
            for (final goal in goals)
              _GoalCard(
                goal: goal,
                metricLabel: _metricLabel(goal),
                onEdit: () => _openEditor(goal),
                onDelete: () => _deleteGoal(goal),
              ),
          ],
        ),
      ),
    ];
  }

  String? _metricLabel(Goal goal) {
    final ref = goal.metricRef;
    if (ref == null) return null;
    return _exerciseNames[ref] ?? ref;
  }

  Widget _headerRow() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            'Mis metas',
            style:
                theme.textTheme.labelLarge?.copyWith(color: kOnSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Cabecera del mockup (spec 008, RF-22): chip de rango que alimenta la
  /// tendencia de peso y acción «Nueva Medida».
  Widget _rangeHeader() {
    final theme = Theme.of(context);
    final label = switch (_range) {
      90 => 'Últimos 90 días',
      365 => 'Último año',
      _ => 'Últimos 30 días',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Flexible(
            child: PopupMenuButton<int>(
              initialValue: _range,
              onSelected: (value) => setState(() => _range = value),
              color: kSurfaceContainerHigh,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 30, child: Text('Últimos 30 días')),
                PopupMenuItem(value: 90, child: Text('Últimos 90 días')),
                PopupMenuItem(value: 365, child: Text('Último año')),
              ],
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: kSurfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kSurfaceContainerHighest),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: kOnSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: kOnSurface),
                      ),
                    ),
                    const Icon(
                      Icons.expand_more,
                      size: 18,
                      color: kOnSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: SizedBox(
              height: 40,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _addRecord,
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: kOnPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva Medida'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _newGoalBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kSurfaceContainerHighest)),
      ),
      child: SizedBox(
        height: 48,
        child: ElevatedButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add, size: 20),
          label: const Text('Nueva meta'),
        ),
      ),
    );
  }
}
/// Sección «Distribución Muscular» (spec 007 + spec 008, RF-24): mapa
/// vectorial frente/espalda coloreado con la fatiga normalizada 0–1 por
/// músculo (RF-2/RF-3), leyenda por rango, contador de zonas, hint
/// «Interactivo» y lista scrolleable de zonas con volumen semanal y estado.
/// Lee el cache local (RF-6); el recálculo se dispara al abrir el tab,
/// cerrar sesión o sync.
class _FatigueSection extends StatefulWidget {
  final Map<String, double>? fatigue;

  const _FatigueSection({required this.fatigue});

  @override
  State<_FatigueSection> createState() => _FatigueSectionState();
}

class _FatigueSectionState extends State<_FatigueSection> {
  bool _showBack = false;
  String? _selectedMuscle;

  /// Desglose semanal por zona (RF-24); se recarga al cambiar de vista para
  /// que el orden por volumen acompañe al mapa.
  late Future<List<MuscleZoneStats>> _zones;

  @override
  void initState() {
    super.initState();
    _zones = fatigueRepository.weeklyZoneStats();
  }

  @override
  void didUpdateWidget(covariant _FatigueSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameFatigue(oldWidget.fatigue, widget.fatigue)) {
      // El cache cambió (recálculo al abrir el tab o al sincronizar): las
      // filas se releen para que su estado salga de los mismos valores que
      // el color del mapa.
      setState(() {
        _zones = fatigueRepository.weeklyZoneStats();
      });
    }
  }

  static bool _sameFatigue(Map<String, double>? a, Map<String, double>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }

  void _toggleView(bool back) {
    if (_showBack == back) return;
    setState(() {
      _showBack = back;
      _selectedMuscle = null;
    });
  }

  /// Alinea la fila resaltada con la vista actual: si la zona seleccionada no
  /// pinta en la vista, se limpia.
  void _syncSelection(Map<String, double> fatigue) {
    final selected = _selectedMuscle;
    if (selected == null) return;
    final visible = _showBack ? kBackCanonicals : kFrontCanonicals;
    if (!visible.contains(selected) || !fatigue.containsKey(selected)) {
      _selectedMuscle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 18,
                color: kOnSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Distribución Muscular',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: kOnSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Volumen semanal y estado de fatiga',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: kOnSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _ViewToggle(
                    showBack: _showBack,
                    onChanged: _toggleView,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kSurfaceContainerHighest),
            ),
            child: Builder(
              builder: (context) {
                final fatigue = widget.fatigue;
                if (fatigue == null) {
                  return const SizedBox(height: 300);
                }
                _syncSelection(fatigue);
                return FutureBuilder<List<MuscleZoneStats>>(
                  future: _zones,
                  builder: (context, zonesSnap) {
                    final zones = zonesSnap.data ?? const [];
                    final byMuscle = {
                      for (final zone in zones) zone.muscle: zone,
                    };
                    final totalZones = kCanonicalMuscles.length;
                    final rows = [
                      for (final canonical in kCanonicalMuscles)
                        (
                          muscle: canonical,
                          fatigue: fatigue[canonical] ?? 0,
                          weeklyVolume:
                              byMuscle[canonical]?.weeklyVolume ?? 0,
                          sets: byMuscle[canonical]?.sets ?? 0,
                        ),
                    ];
                    // Amenda de secundarios (2026-10-18): la lista muestra
                    // todas las zonas del mapa, entrenadas o no; sin ninguna
                    // actividad se mantiene el mensaje de bienvenida.
                    final hasActivity = rows.any(
                      (row) => row.weeklyVolume > 0 || row.fatigue > 0,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ZoneLegend(count: totalZones),
                        const SizedBox(height: 12),
                        MuscleMap(
                          fatigue: fatigue,
                          showBack: _showBack,
                          height: 300,
                          selected: _selectedMuscle,
                          onMuscleTapped: (muscle) => setState(
                            () => _selectedMuscle = _selectedMuscle == muscle
                                ? null
                                : muscle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.touch_app,
                                size: 14,
                                color: kOnSurfaceVariant,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Interactivo',
                                style: TextStyle(
                                  color: kOnSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!hasActivity)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              'Termina sesiones de entrenamiento para ver qué '
                              'músculos están fatigados y cuáles están frescos.',
                              style: TextStyle(
                                color: kOnSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          _ZoneList(
                            rows: rows,
                            selected: _selectedMuscle,
                            onSelected: (muscle) => setState(() {
                              _selectedMuscle = muscle;
                              // La fila resaltada siempre se ve en el mapa:
                              // si la zona no pinta en la vista actual, se
                              // cambia a la vista donde sí pinta.
                              if (kBackCanonicals.contains(muscle) &&
                                  !kFrontCanonicals.contains(muscle)) {
                                _showBack = true;
                              } else if (kFrontCanonicals.contains(muscle) &&
                                  !kBackCanonicals.contains(muscle)) {
                                _showBack = false;
                              }
                            }),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Leyenda por rango (Alto / Óptimo / Recuperado) + contador de zonas del
/// mockup (RF-24).
class _ZoneLegend extends StatelessWidget {
  final int count;

  const _ZoneLegend({required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _ZoneChip(label: 'Alto', range: '(16-20)', color: ZVC.kFatigueHot),
            _ZoneChip(label: 'Óptimo', range: '(12-15)', color: ZVC.kFatigueWarm),
            _ZoneChip(
              label: 'Recuperado',
              range: '(≤10)',
              color: ZVC.kFatigueCold,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$count ZONAS',
          style: const TextStyle(
            color: kOnSurfaceVariant,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ZoneChip extends StatelessWidget {
  final String label;
  final String range;
  final Color color;

  const _ZoneChip({
    required this.label,
    required this.range,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $range',
          style: const TextStyle(color: kOnSurfaceVariant, fontSize: 10),
        ),
      ],
    );
  }
}

/// Toggle pill Frente/Espalda del mockup (RF-24), sin sombras.
class _ViewToggle extends StatelessWidget {
  final bool showBack;
  final ValueChanged<bool> onChanged;

  const _ViewToggle({required this.showBack, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: kSurfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleSegment(
            label: 'Frente',
            selected: !showBack,
            onTap: () => onChanged(false),
          ),
          _ToggleSegment(
            label: 'Espalda',
            selected: showBack,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kOnSurface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? kSurface : kOnSurfaceVariant,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Lista de zonas del mockup (RF-24): las 17 filas del mapa con nombre ES,
/// series, volumen semanal y chip de estado; la seleccionada resalta.
class _ZoneList extends StatelessWidget {
  final List<({String muscle, double fatigue, double weeklyVolume, int sets})>
      rows;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ZoneList({
    required this.rows,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) {
        final byVolume = b.weeklyVolume.compareTo(a.weeklyVolume);
        if (byVolume != 0) return byVolume;
        return a.muscle.compareTo(b.muscle);
      });
    return Column(
      children: [
        for (final row in sorted)
          _ZoneRow(
            muscle: row.muscle,
            sets: row.sets,
            weeklyVolume: row.weeklyVolume,
            status: zoneStatusOf(row.fatigue),
            selected: row.muscle == selected,
            onTap: () => onSelected(row.muscle),
          ),
      ],
    );
  }
}

class _ZoneRow extends StatelessWidget {
  final String muscle;
  final int sets;
  final double weeklyVolume;
  final MuscleZoneStatus status;
  final bool selected;
  final VoidCallback onTap;

  const _ZoneRow({
    required this.muscle,
    required this.sets,
    required this.weeklyVolume,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    final color = switch (status) {
      MuscleZoneStatus.high => ZVC.kFatigueHot,
      MuscleZoneStatus.optimal => ZVC.kFatigueWarm,
      MuscleZoneStatus.recovering => ZVC.kFatigueCold,
    };
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kSurfaceContainerHigh : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    muscleLabel(muscle),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: kOnSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  sets > 0 ? '$sets series' : 'Sin series',
                  style: const TextStyle(
                    color: kOnSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${displayWeightKg(weeklyVolume, unitSystem).round()} '
                  '${weightUnitOf(unitSystem)}',
                  style: const TextStyle(
                    color: kOnSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kSurfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                zoneStatusLabel(status),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Músculos canónicos que pintan en la vista frontal (espejo de
/// `kFrontGroups` del paquete, en canónico).
const Set<String> kFrontCanonicals = {
  'pectoralis_major',
  'deltoids',
  'biceps',
  'triceps',
  'forearms',
  'hands',
  'abdominals',
  'obliques',
  'quadriceps',
  'calves',
  'feet',
};

/// Músculos canónicos que pintan en la vista trasera.
const Set<String> kBackCanonicals = {
  'deltoids',
  'triceps',
  'forearms',
  'hands',
  'hamstrings',
  'glutes',
  'calves',
  'latissimus_dorsi',
  'trapezius',
  'rhomboids',
  'lower_back',
};

/// Sección «Peso y medidas» (spec 006 + spec 008, RF-23): tarjeta de peso
/// corporal al estilo del mockup — valor grande, pill de ritmo mensual,
/// meta con línea discontinua y proyección al plazo — sobre el sparkline
/// con selector de rango (30/90/365 días), más la tabla de registros con
/// deltas frente al registro anterior (RF-3).
class _MetricsSection extends StatefulWidget {
  final List<BodyMetric> records;

  /// Rango de la tendencia elegido en la cabecera (30/90/365 días).
  final int range;

  /// Meta de peso activa; null = tarjeta sin meta (sin huecos).
  final Goal? weightGoal;
  final ValueChanged<BodyMetric> onEdit;
  final ValueChanged<BodyMetric> onDelete;

  const _MetricsSection({
    required this.records,
    required this.range,
    required this.weightGoal,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_MetricsSection> createState() => _MetricsSectionState();
}

class _MetricsSectionState extends State<_MetricsSection> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    final weightUnit = weightUnitOf(unitSystem);
    final now = DateTime.now();
    final today = BodyMetricRepository.dayOf(now);
    final inRange =
        today.subtract(Duration(days: widget.range - 1));
    final weighted = [
      for (final record in widget.records)
        if (record.weightKg != null) record,
    ]..sort((a, b) => a.date.compareTo(b.date));
    final trendPoints = [
      for (final record in weighted)
        if (!record.date.isBefore(inRange) && !record.date.isAfter(today))
          (date: record.date, weightKg: record.weightKg!),
    ];
    final latest = trendPoints.isEmpty ? null : trendPoints.last;

    final goalKg = widget.weightGoal?.targetValue;
    final deadline = widget.weightGoal?.deadline;
    final projection = latest == null ||
            goalKg == null ||
            deadline == null ||
            !deadline.isAfter(now)
        ? null
        : projectToGoal(
            points: trendPoints,
            goalKg: goalKg,
            deadline: deadline,
            now: now,
          );

    // Ritmo del mes: primer registro dentro de los últimos 30 días.
    double? monthlyDelta;
    if (weighted.length >= 2) {
      final last = weighted.last;
      final cutoff = last.date.subtract(const Duration(days: 30));
      BodyMetric? first;
      for (final record in weighted) {
        if (!record.date.isBefore(cutoff)) {
          first = record;
          break;
        }
      }
      if (first != null && !first.date.isAtSameMomentAs(last.date)) {
        monthlyDelta = last.weightKg! - first.weightKg!;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peso y medidas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceContainer,
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
                          const Text(
                            'PESO CORPORAL',
                            style: TextStyle(
                              color: kOnSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (latest != null) ...[
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    _fmtValue(
                                      displayWeightKg(
                                        latest.weightKg,
                                        unitSystem,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: kOnSurface,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.5,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    weightUnit,
                                    style: const TextStyle(
                                      color: kSecondary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (monthlyDelta != null)
                              _MonthlyDeltaChip(deltaKg: monthlyDelta),
                            if (goalKg != null) ...[
                              if (monthlyDelta != null)
                                const SizedBox(height: 4),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: kOnSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Meta: '),
                                    TextSpan(
                                      text:
                                          '${_fmtValue(displayWeightKg(goalKg, unitSystem))} '
                                          '$weightUnit',
                                      style: const TextStyle(
                                        color: kOnSurface,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                WeightTrend(
                  points: trendPoints,
                  goalKg: goalKg,
                  projection: projection,
                ),
                if (trendPoints.length >= 2) ...[
                  const SizedBox(height: 6),
                  _TimelineLabels(points: trendPoints),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (widget.records.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kSurfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kSurfaceContainerHighest),
              ),
              child: const Text(
                'Pésate cada mañana y guarda tus medidas para ver la '
                'tendencia aquí.',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
              ),
            )
          else
            Column(
              children: [
                // Últimos 2 registros
                for (var index = 0; index < (widget.records.length > 2 ? 2 : widget.records.length); index++)
                  _RecordCard(
                    record: widget.records[index],
                    previous: index + 1 < widget.records.length
                        ? widget.records[index + 1]
                        : null,
                    onEdit: () => widget.onEdit(widget.records[index]),
                    onDelete: () => widget.onDelete(widget.records[index]),
                  ),
                const SizedBox(height: 8),
              ],
            ),
        ],
      ),
    );
  }
}

/// Entrada a la pantalla de medidas (amenda 2026-10-18): tarjeta compacta en
/// Progreso que abre el histórico de medidas corporales y su evolución.
class _MeasuresEntry extends StatelessWidget {
  const _MeasuresEntry();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Semantics(
        button: true,
        label: 'Abrir medidas corporales y evolución',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const MeasuresView()),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: kSurfaceContainerHigh,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: kSurfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.straighten,
                    size: 18,
                    color: kOnSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medidas',
                        style: textTheme.titleMedium?.copyWith(
                          color: kOnSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Medidas corporales y evolución',
                        style: TextStyle(
                          color: kOnSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
}

/// Pill del ritmo del mes (mockup: «-1.2 kg este mes») con icono de
/// tendencia (RF-23).
class _MonthlyDeltaChip extends StatelessWidget {
  final double deltaKg;

  const _MonthlyDeltaChip({required this.deltaKg});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    final down = deltaKg < 0;
    final flat = deltaKg == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            flat
                ? Icons.trending_flat
                : down
                    ? Icons.trending_down
                    : Icons.trending_up,
            size: 14,
            color: kTertiaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            '${kgDeltaLabel(deltaKg, unitSystem: unitSystem)} este mes',
            style: theme.textTheme.labelSmall?.copyWith(color: kOnSurface),
          ),
        ],
      ),
    );
  }
}

/// Etiquetas del eje temporal del mockup: primera y última con su valor,
/// intermedias solo con la fecha (RF-23).
class _TimelineLabels extends StatelessWidget {
  final List<({DateTime date, double weightKg})> points;

  const _TimelineLabels({required this.points});

  static const _months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  String _dayMonth(DateTime date) => '${date.day} ${_months[date.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final unitSystem = UnitSystemScope.of(context);
    final last = points.length - 1;
    final indexes = <int>{0, last, points.length ~/ 4, (3 * points.length) ~/ 4}
        .toList()
      ..sort();
    return Row(
      children: [
        for (final index in indexes)
          Expanded(
            child: Text(
              index == 0
                  ? '${_dayMonth(points.first.date)} '
                      '(${_fmtValue(displayWeightKg(points.first.weightKg, unitSystem))})'
                  : index == last
                      ? 'Hoy (${_fmtValue(displayWeightKg(points.last.weightKg, unitSystem))})'
                      : _dayMonth(points[index].date),
              textAlign: index == 0
                  ? TextAlign.left
                  : index == last
                      ? TextAlign.right
                      : TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                color: index == last ? kOnSurface : kOnSurfaceVariant,
                fontWeight:
                    index == last ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  final BodyMetric record;
  final BodyMetric? previous;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecordCard({
    required this.record,
    required this.previous,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitSystem = UnitSystemScope.of(context);
    final weightUnit = weightUnitOf(unitSystem);
    final measures = decodeMeasures(record.measuresJson);
    final previousMeasures = decodeMeasures(previous?.measuresJson);
    final deltas =
        measureDeltas(current: measures, previous: previousMeasures);
    final weight = record.weightKg;
    final previousWeight = previous?.weightKg;
    final weightDelta =
        weight != null && previousWeight != null ? weight - previousWeight : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_weight_outlined,
                  size: 18, color: kOnSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDate(record.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: kOnSurface, fontSize: 15),
                ),
              ),
              if (weight != null)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_fmtValue(displayWeightKg(weight, unitSystem))} '
                          '$weightUnit',
                          style: const TextStyle(
                            color: kOnSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (weightDelta != null) ...[
                          const SizedBox(width: 8),
                          _DeltaBadge(
                            delta: displayWeightKg(weightDelta, unitSystem),
                            unit: weightUnit,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Opciones del registro',
                icon: const Icon(Icons.more_horiz, color: kOnSurfaceVariant),
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
            ],
          ),
          if (measures.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in kBodyMeasures)
                  if (measures[id] != null)
                    _MeasureChip(
                      label: measureLabel(id),
                      value: _fmtValue(
                        displayLengthCm(measures[id]!, unitSystem),
                      ),
                      delta: deltas[id] == null
                          ? null
                          : displayLengthCm(deltas[id]!, unitSystem),
                    ),
              ],
            ),
          ],
          if (record.notes != null && record.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              record.notes!,
              style:
                  theme.textTheme.bodySmall?.copyWith(color: kOnSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _MeasureChip extends StatelessWidget {
  final String label;
  final String value;
  final double? delta;

  const _MeasureChip({
    required this.label,
    required this.value,
    required this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label $value',
            style: const TextStyle(color: kOnSurface, fontSize: 12),
          ),
          if (delta != null) ...[
            const SizedBox(width: 4),
            _DeltaBadge(delta: delta!, unit: ''),
          ],
        ],
      ),
    );
  }
}

/// Badge del delta (designer §7.10): fondo neutro y color según el signo;
/// el delta positivo usa el indicador de tendencia.
class _DeltaBadge extends StatelessWidget {
  final double delta;
  final String unit;

  const _DeltaBadge({required this.delta, required this.unit});

  @override
  Widget build(BuildContext context) {
    final positive = delta > 0;
    final text = positive
        ? '+${_fmtValue(delta)} $unit'.trim()
        : '${_fmtValue(delta)} $unit'.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: positive ? kTertiaryContainer : kSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: positive ? kOnTertiaryContainer : kOnSurfaceVariant,
        ),
      ),
    );
  }
}

String _goalTitle(Goal goal) => switch (goal.type) {
      'bodyweight' => 'Peso corporal',
      'strength' => 'Fuerza',
      'volume' => 'Volumen',
      'consistency' => 'Constancia',
      _ => goal.type,
    };

String _goalSubtitle(Goal goal, String? metricLabel) => switch (goal.type) {
      'bodyweight' => 'Peso actual',
      'strength' => metricLabel ?? 'Ejercicio no disponible',
      'volume' =>
        '${goal.period == 'weekly' ? 'Semanal' : 'Mensual'} · ${metricLabel ?? '—'}',
      'consistency' => 'Sesiones en los últimos 7 días',
      _ => '',
    };

double _goalDisplayValue(Goal goal, double value, String unitSystem) =>
    goal.type == 'consistency' ? value : displayWeightKg(value, unitSystem);

String _goalUnit(Goal goal, String unitSystem) =>
    goal.type == 'consistency' ? 'sesiones' : weightUnitOf(unitSystem);

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

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 22, color: kOnSurfaceVariant),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aún no tienes metas',
                  style: TextStyle(
                    color: kOnSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            'Fija metas de peso, fuerza, volumen y constancia '
            'para ver tu progreso aquí.',
            style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _AchievementsBanner extends StatelessWidget {
  final List<Goal> goals;

  const _AchievementsBanner({required this.goals});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kTertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kOliveAccent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, color: kOnTertiaryContainer, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Metas logradas!',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: kOnTertiaryContainer),
                ),
                const SizedBox(height: 2),
                Text(
                  goals.map((g) => _goalTitle(g)).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: kOnTertiaryContainer,
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

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final String? metricLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GoalCard({
    required this.goal,
    required this.metricLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achieved = goal.status == 'achieved';
    final abandoned = goal.status == 'abandoned';
    final progress = goalProgress(
      type: goal.type,
      currentValue: goal.currentValue,
      targetValue: goal.targetValue,
      startValue: goal.baselineValue,
    );
    final current = goal.currentValue;
    final unitSystem = UnitSystemScope.of(context);
    final unit = _goalUnit(goal, unitSystem);
    final currentText = current == null
        ? '—'
        : _fmtValue(_goalDisplayValue(goal, current, unitSystem));
    final targetText =
        _fmtValue(_goalDisplayValue(goal, goal.targetValue, unitSystem));

    final Widget status;
    if (achieved) {
      status = const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: kOliveAccent, size: 18),
          SizedBox(width: 4),
          Text('Lograda', style: TextStyle(color: kOliveAccent)),
        ],
      );
    } else if (abandoned) {
      status = const Text(
        'Abandonada',
        style: TextStyle(color: kOnSurfaceVariant),
      );
    } else {
      status = Text(
        '${(progress * 100).round()} %',
        style: const TextStyle(color: kOnSurface, fontWeight: FontWeight.w600),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
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
              Icon(
                _goalIcon(goal.type),
                size: 20,
                color: achieved ? kOliveAccent : kOnSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _goalTitle(goal),
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: kOnSurface, fontSize: 16),
                    ),
                    if (metricLabel != null || goal.type == 'consistency') ...[
                      const SizedBox(height: 2),
                      Text(
                        _goalSubtitle(goal, metricLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: kOnSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              status,
              PopupMenuButton<String>(
                tooltip: 'Opciones de la meta',
                icon: const Icon(Icons.more_horiz, color: kOnSurfaceVariant),
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
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: achieved ? 1 : (abandoned ? 0 : progress),
              minHeight: 6,
              backgroundColor: kSurfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                achieved
                    ? kOliveAccent
                    : (abandoned ? kOutlineVariant : kOnSurface),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  current == null
                      ? '— / $targetText $unit'
                      : '$currentText / $targetText $unit',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: kOnSurfaceVariant),
                ),
              ),
              if (goal.deadline != null)
                Text(
                  'Plazo ${_formatDate(goal.deadline!)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: kOnSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _goalIcon(String type) => switch (type) {
        'bodyweight' => Icons.monitor_weight_outlined,
        'strength' => Icons.fitness_center,
        'volume' => Icons.assessment_outlined,
        'consistency' => Icons.calendar_month_outlined,
        _ => Icons.flag_outlined,
      };
}


/// Abre la vista de reserva (spec sin implementar) con el mensaje dado.
Future<void> _openSoon(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SoonView(title: title, message: message),
    ),
  );
}

/// Grid de composición corporal (spec 009, RF-3): % grasa y masa magra con
/// el aspecto del mockup. Las columnas aún no existen en `body_metrics`,
/// así que muestra su estado vacío y enlaza a la spec.
class _CompositionSection extends StatelessWidget {
  const _CompositionSection({
    required this.records,
    required this.onAdd,
    this.sex,
    this.heightCm,
  });

  final List<BodyMetric> records;
  final VoidCallback onAdd;
  final String? sex;
  final double? heightCm;

  @override
  Widget build(BuildContext context) {
    final unitSystem = UnitSystemScope.of(context);
    final weightUnit = weightUnitOf(unitSystem);
    final latest = latestComposition(records, sex: sex, heightCm: heightCm);
    final previous =
        previousComposition(records, sex: sex, heightCm: heightCm);
    final fat = latest?.bodyFatPct;
    final lean = latest?.leanMassKg;
    final fatDelta = _compositionDelta(fat, previous?.bodyFatPct);
    final leanDelta = _compositionDelta(lean, previous?.leanMassKg);
    final hasData = fat != null || lean != null;
    final source = latest == null
        ? 'Sin registro anterior'
        : bodyFatSourceLabel(estimated: latest.estimatedBodyFat);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CompositionCard(
                  label: 'GRASA ESTIMADA',
                  icon: Icons.pie_chart_outline,
                  value: fat,
                  unit: '%',
                  delta: fatDelta,
                  deltaColor: fatDelta != null && fatDelta > 0
                      ? kError
                      : kOliveAccent,
                  footer: source,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompositionCard(
                  label: 'MASA MAGRA',
                  icon: Icons.fitness_center,
                  value: lean == null
                      ? null
                      : displayWeightKg(lean, unitSystem),
                  unit: weightUnit,
                  delta: leanDelta == null
                      ? null
                      : displayWeightKg(leanDelta, unitSystem),
                  deltaColor: leanDelta != null && leanDelta < 0
                      ? kError
                      : kOliveAccent,
                  footer: source,
                ),
              ),
            ],
          ),
          if (!hasData)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAdd,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Registra tu % de grasa y masa magra para verlos aquí',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(color: kOnSurfaceVariant, fontSize: 12),
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward, size: 14, color: kOutline),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Δ de una métrica de composición; null sin dato previo.
double? _compositionDelta(double? current, double? previous) {
  if (current == null || previous == null) return null;
  return current - previous;
}

/// Card individual de composición del mockup: label e icono, valor con unidad
/// y pie con el Δ frente al registro anterior.
class _CompositionCard extends StatelessWidget {
  const _CompositionCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.unit,
    required this.footer,
    this.delta,
    this.deltaColor,
  });

  final String label;
  final IconData icon;
  final double? value;
  final String unit;
  final String footer;
  final double? delta;
  final Color? deltaColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final deltaLabel = delta == null
        ? null
        : '${delta! > 0 ? '+' : ''}${delta!.toStringAsFixed(1)} $unit';
    final footerText =
        [deltaLabel, footer].whereType<String>().join(' · ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    color: kOnSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: kOnSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value == null ? '—' : value!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 36,
                    height: 40 / 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.1,
                    color: kPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: textTheme.bodyMedium?.copyWith(color: kSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            footerText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: delta == null ? kOnSurfaceVariant : deltaColor,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

const _photoMonthNames = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Día y mes cortos en español («18 oct») para las fotos de progreso.
String _photoDayLabel(DateTime date) =>
    '${date.day} ${_photoMonthNames[date.month - 1]}';

/// Captura una foto desde cámara o galería y la guarda (spec 009, RF-7/8).
/// Sin `view` fija, se pide la vista tras elegir la fuente.
Future<void> _pickProgressPhoto(BuildContext context, {String? view}) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: kSurfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Cámara'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galería'),
            onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  var targetView = view;
  targetView ??= await showModalBottomSheet<String>(
    context: context,
    backgroundColor: kSurfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final candidate in kPhotoViews)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(photoViewLabel(candidate)),
              onTap: () => Navigator.pop(sheetContext, candidate),
            ),
        ],
      ),
    ),
  );
  if (targetView == null || !context.mounted) return;

  try {
    // `imageQuality` delega la compresión (< 500 KB) al plugin.
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );
    if (picked == null) return;
    await photoRepository.addPhoto(
      date: DateTime.now(),
      view: targetView,
      bytes: await picked.readAsBytes(),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'No se pudo guardar la foto. Revisa los permisos de la cámara '
          'y la galería.',
        ),
      ),
    );
  }
}

Future<bool> _confirmPhotoDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String actionLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: kSurfaceContainer,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: kSurfaceContainerHighest),
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          style: TextButton.styleFrom(foregroundColor: kError),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> _deleteProgressPhoto(
  BuildContext context,
  ProgressPhoto photo,
) async {
  final confirmed = await _confirmPhotoDialog(
    context: context,
    title: '¿Eliminar esta foto?',
    message:
        'Se borrará de este dispositivo y de tu cuenta. No se puede deshacer.',
    actionLabel: 'Eliminar',
  );
  if (!confirmed || !context.mounted) return false;
  await photoRepository.deletePhoto(photo.id);
  if (!context.mounted) return true;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Foto eliminada')),
  );
  return true;
}

Future<void> _deleteAllProgressPhotos(BuildContext context, int count) async {
  final confirmed = await _confirmPhotoDialog(
    context: context,
    title: '¿Eliminar todas las fotos?',
    message:
        'Se borrarán $count fotos de este dispositivo y de tu cuenta. '
        'No se puede deshacer.',
    actionLabel: 'Eliminar todo',
  );
  if (!confirmed || !context.mounted) return;
  await photoRepository.deleteAllPhotos();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Fotos eliminadas')),
  );
}

void _openPhotoViewer(
  BuildContext context,
  List<ProgressPhoto> photos,
  ProgressPhoto photo,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PhotoViewerPage(
        photos: photos,
        initialIndex: [
          for (var i = 0; i < photos.length; i++)
            if (photos[i].id == photo.id) i,
        ].firstOrNull ??
            0,
      ),
    ),
  );
}

/// Fila de 3 columnas del grid de fotos.
Widget _photosGrid({required List<Widget> children}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(child: children[i]),
        ],
      ],
    );

/// Caja informativa de la sección (vacío, error).
Widget _photosNoteBox(
  BuildContext context,
  String text, {
  IconData? icon,
  Color? color,
}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color ?? kOnSurfaceVariant),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color ?? kOnSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

/// Sección de fotos de progreso (spec 009, RF-7 a RF-10): píldora de
/// comparación con las dos fechas más recientes, grid de 3 columnas
/// (frente/perfil/espalda) con la última foto de cada vista, captura desde
/// cámara o galería con subida en segundo plano y zoom a pantalla completa.
class _PhotosSection extends StatelessWidget {
  const _PhotosSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: StreamBuilder<List<ProgressPhoto>>(
        stream: photoRepository.watchPhotos(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final latest = <String, ProgressPhoto>{};
          final dates = <DateTime>[];
          for (final photo in data ?? const <ProgressPhoto>[]) {
            latest.putIfAbsent(photo.view, () => photo);
            if (!dates.contains(photo.date)) dates.add(photo.date);
          }
          final canCompare = data != null && dates.length >= 2;

          Widget body;
          if (snapshot.hasError) {
            body = _photosNoteBox(
              context,
              'No se pudieron cargar tus fotos. Inténtalo de nuevo.',
              icon: Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            );
          } else if (data == null) {
            body = _photosGrid(
              children: [
                for (final view in kPhotoViews)
                  _PhotoPlaceholder(
                    label: photoViewLabel(view).toUpperCase(),
                  ),
              ],
            );
          } else {
            body = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _photosGrid(
                  children: [
                    for (final view in kPhotoViews)
                      _PhotoCard(
                        view: view,
                        photo: latest[view],
                        photos: [
                          for (final photo in data)
                            if (photo.view == view) photo,
                        ],
                      ),
                  ],
                ),
                if (data.isEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _pickProgressPhoto(context),
                    child: _photosNoteBox(
                      context,
                      'Añade fotos de frente, perfil y espalda para '
                      'comparar tu progreso',
                    ),
                  ),
                ],
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Fotos de Progreso',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: kOnSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Añadir foto de progreso',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _pickProgressPhoto(context),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(
                          Icons.photo_camera_outlined,
                          size: 18,
                          color: kOnSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Semantics(
                    button: canCompare,
                    label: 'Comparar dos fechas',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canCompare
                          ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _PhotoComparatorPage(
                                    photos: data,
                                    dates: dates,
                                  ),
                                ),
                              )
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: const BoxDecoration(
                          color: kSurfaceContainer,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: Text(
                          canCompare
                              ? '${_photoDayLabel(dates[1])} vs '
                                  '${_photoDayLabel(dates[0])}'
                              : 'Sin comparación',
                          style: const TextStyle(
                            color: kOnSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              body,
              if (data != null && data.isNotEmpty) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        _deleteAllProgressPhotos(context, data.length),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Eliminar todo'),
                    style: TextButton.styleFrom(foregroundColor: kError),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Tarjeta de una vista (spec 009, RF-8): última foto con etiqueta y zoom;
/// sin foto, acceso directo a la captura.
class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.view,
    required this.photo,
    required this.photos,
  });

  final String view;
  final ProgressPhoto? photo;
  final List<ProgressPhoto> photos;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: photo == null
                ? () => _pickProgressPhoto(context, view: view)
                : () => _openPhotoViewer(context, photos, photo),
            child: photo == null
                ? _PhotoPlaceholder(
                    label: photoViewLabel(view).toUpperCase(),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                        child: _PhotoImage(photo: photo),
                      ),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: _photoChip(
                          PopupMenuButton<String>(
                            tooltip: 'Opciones de la foto',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            icon: const Icon(
                              Icons.more_horiz,
                              size: 14,
                              color: kOnSurface,
                            ),
                            onSelected: (value) async {
                              if (value == 'view') {
                                _openPhotoViewer(context, photos, photo);
                              } else if (value == 'delete') {
                                await _deleteProgressPhoto(context, photo);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'view',
                                child: Text('Ver foto'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: _photoChip(
                          Text(
                            photoViewLabel(view).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: kOnSurface,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: _photoChip(
                          const Icon(
                            Icons.zoom_out_map_outlined,
                            size: 12,
                            color: kOnSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Flexible(
              child: Text(
                photo == null ? 'Sin foto' : _photoDayLabel(photo.date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kOnSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ),
            if (photo != null && photo.uploadStatus == 'pending') ...[
              const SizedBox(width: 4),
              Semantics(
                label: 'Subiendo',
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 12,
                  color: kOnSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _photoChip(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: const BoxDecoration(
          color: kSurfaceContainerHighest,
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        child: child,
      );
}

/// Imagen de una foto con caché en disco (spec 009, RF-9): usa el fichero
/// local y, si no está en el dispositivo, lo descarga desde Storage una vez.
class _PhotoImage extends StatefulWidget {
  const _PhotoImage({required this.photo, this.fit = BoxFit.cover});

  final ProgressPhoto photo;
  final BoxFit fit;

  @override
  State<_PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<_PhotoImage> {
  Future<String?>? _path;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _PhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id) {
      _resolve();
    }
  }

  void _resolve() {
    if (File(widget.photo.path).existsSync()) {
      _path = Future<String?>.value(widget.photo.path);
    } else {
      _path = photoRepository.ensureLocal(widget.photo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _path,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path != null) {
          return Image.file(
            File(path),
            fit: widget.fit,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stack) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: 20,
                color: kOutline,
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return const Center(
          child: Icon(Icons.broken_image_outlined, size: 20, color: kOutline),
        );
      },
    );
  }
}

/// Visor a pantalla completa con zoom (spec 009, RF-8).
class _PhotoViewerPage extends StatefulWidget {
  const _PhotoViewerPage({required this.photos, required this.initialIndex});

  final List<ProgressPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.photos.length - 1);
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: kOnSurface,
        centerTitle: true,
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          IconButton(
            tooltip: 'Eliminar foto',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final photo = widget.photos[_currentIndex];
              final deleted = await _deleteProgressPhoto(context, photo);
              if (deleted && context.mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: _PhotoImage(
              photo: widget.photos[index],
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// Comparador de dos fechas (spec 009, RF-8): antes/después por vista.
class _PhotoComparatorPage extends StatefulWidget {
  const _PhotoComparatorPage({required this.photos, required this.dates});

  final List<ProgressPhoto> photos;
  final List<DateTime> dates; // Descendente.

  @override
  State<_PhotoComparatorPage> createState() => _PhotoComparatorPageState();
}

class _PhotoComparatorPageState extends State<_PhotoComparatorPage> {
  late DateTime _before = widget.dates.last;
  late DateTime _after = widget.dates.first;

  ProgressPhoto? _photoOf(DateTime date, String view) {
    for (final photo in widget.photos) {
      if (photo.date == date && photo.view == view) return photo;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparar fotos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _DateChip(
                  label: 'Antes',
                  date: _before,
                  dates: widget.dates,
                  onSelected: (date) => setState(() => _before = date),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateChip(
                  label: 'Después',
                  date: _after,
                  dates: widget.dates,
                  onSelected: (date) => setState(() => _after = date),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final view in kPhotoViews) ...[
            Text(
              photoViewLabel(view).toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: kOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _CompareCell(photo: _photoOf(_before, view))),
                const SizedBox(width: 8),
                Expanded(child: _CompareCell(photo: _photoOf(_after, view))),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Selector de fecha del comparador: chip con hoja de fechas disponibles.
class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.date,
    required this.dates,
    required this.onSelected,
  });

  final String label;
  final DateTime date;
  final List<DateTime> dates;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: ${_photoDayLabel(date)}. Cambiar fecha',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          final picked = await showModalBottomSheet<DateTime>(
            context: context,
            backgroundColor: kSurfaceContainerHigh,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in dates)
                    ListTile(
                      title: Text(_photoDayLabel(option)),
                      trailing: option == date
                          ? const Icon(Icons.check, size: 18)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, option),
                    ),
                ],
              ),
            ),
          );
          if (picked != null) onSelected(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            color: kSurfaceContainerHigh,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: kOnSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _photoDayLabel(date),
                style: const TextStyle(
                  color: kOnSurface,
                  fontSize: 13,
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

/// Celda del comparador: foto o placeholder «Sin foto».
class _CompareCell extends StatelessWidget {
  const _CompareCell({required this.photo});

  final ProgressPhoto? photo;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: photo == null
          ? const _PhotoPlaceholder(label: 'SIN FOTO')
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _PhotoViewerPage(
                    photos: [photo],
                    initialIndex: 0,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: _PhotoImage(photo: photo),
              ),
            ),
    );
  }
}

/// Celda placeholder del grid de fotos: aspecto 3/4 con icono y label.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: kSurfaceContainerLow,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.photo_camera_outlined,
                size: 20,
                color: kOutline,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: kPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Callout de dispositivos (spec 011, RF-2): báscula y caliper con el
/// aspecto del mockup; sin dispositivos emparejados, estado vacío que
/// enlaza a la spec.
class _DevicesCallout extends StatelessWidget {
  const _DevicesCallout();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openSoon(
          context,
          title: 'Dispositivos',
          message:
              'Próximamente podrás conectar tu báscula y caliper por '
              'Bluetooth y sincronizar peso y grasa automáticamente.',
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: kSurfaceContainerHigh,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: kSurfaceBright,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sync, size: 20, color: kPrimary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Báscula y Caliper Conectados',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: kPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sin dispositivos conectados todavía',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: kOnSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
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
