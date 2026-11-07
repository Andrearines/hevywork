import 'package:flutter/material.dart';

import '../../data/repositories/fatigue_repository.dart';
import '../../domain/fatigue_trend.dart';
import '../../domain/muscle_fatigue.dart';
import '../../domain/units.dart';
import 'fatigue_trend_chart.dart' as ft;
import 'muscle_map.dart' as mm;
import 'zone_volume_chart.dart' as zv;
import 'view_toggle.dart';
import '../unit_system_scope.dart' as uis;

export '../../data/repositories/fatigue_repository.dart' show FatiguePanel;

enum FatigueSectionState { expanded, collapsed }

class LiveFatigueSection extends StatefulWidget {
  final FatiguePanel? panel;
  final ValueChanged<FatiguePanel?>? onPanelChanged;
  final FatigueSectionState initialState;
  final bool? showBack;

  const LiveFatigueSection({
    super.key,
    this.panel,
    this.onPanelChanged,
    this.initialState = FatigueSectionState.expanded,
    this.showBack,
  });

  @override
  State<LiveFatigueSection> createState() => _LiveFatigueSectionState();
}

class _LiveFatigueSectionState extends State<LiveFatigueSection>
    with AutomaticKeepAliveClientMixin {
  late FatigueSectionState _state = widget.initialState;
  String? _selectedMuscle;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _showBack = widget.showBack ?? false;
  }

  @override
  void didUpdateWidget(covariant LiveFatigueSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showBack != null && widget.showBack != _showBack) {
      _showBack = widget.showBack!;
    }
    _syncSelection();
  }

  void _syncSelection() {
    if (_selectedMuscle == null) return;
    final visible = _showBack ? mm.kBackCanonicals : mm.kFrontCanonicals;
    if (!visible.contains(_selectedMuscle)) {
      _selectedMuscle = null;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final panel = widget.panel;
    final fatigue = panel?.fatigue ?? const <String, double>{};
    final zones = panel?.zones ?? const <MuscleZoneStats>[];
    final trend = panel?.trend ?? const <FatigueTrendPoint>[];
    final unitSystem = uis.UnitSystemScope.of(context);

    final isExpanded = _state == FatigueSectionState.expanded;

    final primaryEntry = fatigue.entries.isNotEmpty
        ? fatigue.entries.reduce((a, b) => a.value > b.value ? a : b)
        : null;
    final peakLabel = primaryEntry != null
        ? '${mm.muscleLabel(primaryEntry.key)} (${(primaryEntry.value * 100).round()}%)'
        : 'Sin fatiga';

    final header = InkWell(
      onTap: () {
        setState(() {
          _state = isExpanded
              ? FatigueSectionState.collapsed
              : FatigueSectionState.expanded;
        });
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Flexible(
                child: Text(
                  isExpanded ? 'Fatiga muscular' : 'Fatiga: $peakLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 8),
              if (isExpanded) ... [
                ViewToggle(
                  showBack: _showBack,
                  onChanged: (value) {
                    setState(() {
                      _showBack = value;
                    });
                    _syncSelection();
                  },
                ),
              ],
              if (!isExpanded) ... [
                ViewToggle(
                  showBack: _showBack,
                  onChanged: (value) {
                    setState(() {
                      _showBack = value;
                    });
                    _syncSelection();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );

    final expandedBody = _ExpandedBody(
      fatigue: fatigue,
      zones: zones,
      trend: trend,
      selectedMuscle: _selectedMuscle,
      showBack: _showBack,
      unitSystem: unitSystem,
      onMuscleSelected: (muscle) {
        setState(() {
          _selectedMuscle = muscle;
        });
      },
    );

    return Column(
      children: [
        header,
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: isExpanded ? expandedBody : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Etiqueta pura para el chip de zona de fatiga (spec 017, D-032).
/// Funciona sin BuildContext, Theme u otro contexto de widget.
/// Exportada para ser probada de forma aislada.
String zoneChipLabel(MuscleZoneStats zone, String unitSystem) {
  if (zone.sets == 0) return 'Sin series';

  final muscleName = mm.muscleLabel(zone.muscle);
  final setsText = '${zone.sets} series';
  final volumeKg = formatWeightKg(zone.weeklyVolume, unitSystem);
  final weightUnit = weightUnitOf(unitSystem);
  final volumeText = '$volumeKg $weightUnit';

  return '$muscleName · $setsText · $volumeText';
}

class _ExpandedBody extends StatelessWidget {
  final Map<String, double> fatigue;
  final List<MuscleZoneStats> zones;
  final List<FatigueTrendPoint> trend;
  final String? selectedMuscle;
  final bool showBack;
  final String unitSystem;
  final ValueChanged<String?> onMuscleSelected;

  const _ExpandedBody({
    required this.fatigue,
    required this.zones,
    required this.trend,
    this.selectedMuscle,
    required this.showBack,
    required this.unitSystem,
    required this.onMuscleSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final muscleMap = mm.MuscleMap(
      fatigue: fatigue,
      showBack: showBack,
      selected: selectedMuscle,
      onMuscleTapped: (muscle) {
        onMuscleSelected(selectedMuscle == muscle ? null : muscle);
      },
    );

    Widget zoneContent;
    if (zones.isEmpty) {
      zoneContent = Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Sin series',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      zoneContent = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(zones.length, (i) {
            final zone = zones[i];
            final fatigueVal = zone.fatigue;
            final status = zoneStatusOf(fatigueVal);
            final muscleName = mm.muscleLabel(zone.muscle);
            final isSelected = selectedMuscle == zone.muscle;
            final color = switch (status) {
              MuscleZoneStatus.high => mm.kFatigueHot,
              MuscleZoneStatus.optimal => mm.kFatigueWarm,
              MuscleZoneStatus.recovering => mm.kFatigueCold,
            };
            final chipText = zoneChipLabel(zone, unitSystem);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  onMuscleSelected(isSelected ? null : zone.muscle);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.35)
                        : color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? Border.all(color: color, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    chipText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected ? Colors.white : color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    }

    final volumeChart = RepaintBoundary(
      child: zv.ZoneVolumeChart(
        zones: zones,
        muscle: selectedMuscle,
        showBack: showBack,
        unitSystem: unitSystem,
      ),
    );

    final trendChart = RepaintBoundary(
      child: ft.FatigueTrendChart(
        points: trend.map((p) => p.value).toList(),
        muscle: selectedMuscle,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        muscleMap,
        const SizedBox(height: 8),
        zoneContent,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: volumeChart),
            const SizedBox(width: 8),
            Expanded(child: trendChart),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}