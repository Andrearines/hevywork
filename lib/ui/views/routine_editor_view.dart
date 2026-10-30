import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/routine_repository.dart';
import '../../domain/progression.dart';
import '../../domain/units.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/exercise_picker.dart';
import '../widgets/exercise_thumb.dart';

/// Etiquetas cortas de los tipos de serie para la tabla del editor.
const Map<String, String> _setTypeLabels = {
  'warmup': 'CAL',
  'normal': 'NOR',
  'failure': 'FAL',
  'drop': 'DRP',
};

/// Editor de rutina (spec 004): nombre, descripción y una lista de series
/// planificadas por ejercicio (tipo, kg, reps, RIR y descanso), más la
/// progresión automática configurable.
class RoutineEditorView extends StatefulWidget {
  /// Rutina a editar; null crea una nueva.
  final Routine? routine;

  const RoutineEditorView({super.key, this.routine});

  @override
  State<RoutineEditorView> createState() => _RoutineEditorViewState();
}

/// Serie planificada en edición.
class _DraftSet {
  final String key;
  String? id;
  String setType;
  String unitSystem;
  final TextEditingController kgCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController rirCtrl;
  final TextEditingController restCtrl;

  _DraftSet({
    required this.key,
    this.id,
    this.setType = 'normal',
    this.unitSystem = 'metric',
    double weightKg = 0,
    int reps = 10,
    int rir = 2,
    int? restSeconds,
  })  : kgCtrl = TextEditingController(
          text: weightKg == 0
              ? ''
              : _fmtNumber(displayWeightKg(weightKg, unitSystem)),
        ),
        repsCtrl = TextEditingController(text: '$reps'),
        rirCtrl = TextEditingController(text: '$rir'),
        restCtrl = TextEditingController(
          text: restSeconds == null ? '' : '$restSeconds',
        );

  void dispose() {
    kgCtrl.dispose();
    repsCtrl.dispose();
    rirCtrl.dispose();
    restCtrl.dispose();
  }

  RoutineSetDraft toDraft() => RoutineSetDraft(
        id: id,
        setType: setType,
        weightKg: toKg(
          double.tryParse(kgCtrl.text.trim().replaceAll(',', '.')) ?? 0,
          unitSystem,
        ),
        reps: int.tryParse(repsCtrl.text.trim()) ?? 0,
        rir: int.tryParse(rirCtrl.text.trim()) ?? 0,
        restSeconds: int.tryParse(restCtrl.text.trim()),
      );

  static String _fmtNumber(double value) {
    final rounded = (value * 1000).roundToDouble() / 1000;
    final text = rounded.toString();
    return text.contains('.') ? text : '$text.0';
  }
}

class _DraftExercise {
  final String key;
  String? id;
  final String exerciseId;
  final String name;
  final Exercise? exercise;
  final List<_DraftSet> sets;
  bool autoProgress;

  _DraftExercise({
    required this.key,
    this.id,
    required this.exerciseId,
    required this.name,
    this.exercise,
    required this.sets,
    this.autoProgress = true,
  });

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }

  RoutineExerciseDraft toDraft() => RoutineExerciseDraft(
        id: id,
        exerciseId: exerciseId,
        sets: [for (final set in sets) set.toDraft()],
        autoProgress: autoProgress,
      );
}

class _RoutineEditorViewState extends State<RoutineEditorView> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final List<_DraftExercise> _drafts = [];
  bool _loading = false;
  bool _busy = false;
  int _draftSeq = 0;
  int _setSeq = 0;

  // Metadata de planificación (spec 008, RF-18): opcional y editable.
  String? _category;
  String? _level;
  String? _goal;
  int? _targetDays;
  bool _planningOpen = false;
  String _unitSystem = 'metric';

  @override
  void initState() {
    super.initState();
    final routine = widget.routine;
    if (routine != null) {
      _nameCtrl.text = routine.name;
      _descCtrl.text = routine.description ?? '';
      _category = routine.category;
      _level = routine.level;
      _goal = routine.goal;
      _targetDays = routine.targetDays;
      _planningOpen = routine.category != null ||
          routine.level != null ||
          routine.goal != null ||
          routine.targetDays != null;
      _loading = true;
      _loadExercises(routine.id);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final units = UnitSystemScope.of(context);
    if (_unitSystem == units) return;
    final previous = _unitSystem;
    _unitSystem = units;
    for (final draft in _drafts) {
      for (final set in draft.sets) {
        final text = set.kgCtrl.text.trim();
        set.unitSystem = units;
        if (text.isEmpty) continue;
        final value = double.tryParse(text.replaceAll(',', '.'));
        if (value == null) continue;
        set.kgCtrl.text = _DraftSet._fmtNumber(
          displayWeightKg(toKg(value, previous), units),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExercises(String routineId) async {
    final entries = await routineRepository.routineExercises(routineId);
    final exerciseIds = [for (final row in entries) row.item.id];
    final rows = await routineRepository.routineSetsBatch(exerciseIds);
    final draftSets = <String, List<_DraftSet>>{};
    for (final set in rows) {
      (draftSets[set.routineExerciseId] ??= []).add(
        _DraftSet(
          key: set.id,
          id: set.id,
          setType: set.setType,
          unitSystem: _unitSystem,
          weightKg: set.weightKg,
          reps: set.reps,
          rir: set.rir,
          restSeconds: set.restSeconds,
        ),
      );
    }
    final drafts = <_DraftExercise>[];
    for (final row in entries) {
      final item = row.item;
      final stored = draftSets[item.id] ?? [];
      final sets = stored.isEmpty
          ? _legacySets(item)
          : stored;
      drafts.add(
        _DraftExercise(
          key: item.id,
          id: item.id,
          exerciseId: item.exerciseId,
          name: row.exercise?.name ?? 'Ejercicio no disponible',
          sets: sets,
          autoProgress: item.autoProgress,
        ),
      );
    }
    if (!mounted) {
      for (final draft in drafts) {
        draft.dispose();
      }
      return;
    }
    setState(() {
      _drafts.addAll(drafts);
      _loading = false;
    });
  }

  /// Convierte el objetivo antiguo (series/reps/RIR) en series planificadas,
  /// para rutinas guardadas antes de la spec actual.
  List<_DraftSet> _legacySets(RoutineExercise item) {
    final count = item.targetSets ?? 3;
    return [
      for (var i = 0; i < count; i++)
        _DraftSet(
          key: 'legacy-${item.id}-$i',
          setType: 'normal',
          unitSystem: _unitSystem,
          weightKg: item.suggestedWeightKg ?? 0,
          reps: item.targetReps ?? 10,
          rir: item.targetRir ?? 2,
        ),
    ];
  }

  Future<void> _pickExercise() async {
    final selected = await showModalBottomSheet<Exercise>(
      context: context,
      backgroundColor: kSurfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: kSurfaceContainerHighest),
      ),
      builder: (context) => const ExercisePicker(),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _drafts.add(
        _DraftExercise(
          key: 'new-${_draftSeq++}',
          exerciseId: selected.id,
          name: selected.name,
          exercise: selected,
          sets: [
            _DraftSet(key: 'set-${_setSeq++}', unitSystem: _unitSystem),
            _DraftSet(key: 'set-${_setSeq++}', unitSystem: _unitSystem),
            _DraftSet(key: 'set-${_setSeq++}', unitSystem: _unitSystem),
          ],
        ),
      );
    });
  }

  void _removeDraft(_DraftExercise draft) {
    _drafts.removeWhere((d) => d.key == draft.key);
    draft.dispose();
    setState(() {});
  }

  void _addSet(_DraftExercise draft) {
    setState(() {
      draft.sets.add(_DraftSet(key: 'set-${_setSeq++}', unitSystem: _unitSystem));
    });
  }

  void _removeSet(_DraftExercise draft, _DraftSet set) {
    if (draft.sets.length <= 1) return;
    draft.sets.removeWhere((s) => s.key == set.key);
    set.dispose();
    setState(() {});
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final draft = _drafts.removeAt(oldIndex);
      _drafts.insert(newIndex, draft);
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Ponle un nombre a la rutina')),
      );
      return;
    }
    for (final draft in _drafts) {
      if (draft.sets.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('Añade al menos una serie a ${draft.name}')),
        );
        return;
      }
      for (final set in draft.sets) {
        final reps = int.tryParse(set.repsCtrl.text.trim());
        final rir = int.tryParse(set.rirCtrl.text.trim());
        final kg = double.tryParse(set.kgCtrl.text.trim().replaceAll(',', '.'));
        final rest = set.restCtrl.text.trim().isEmpty
            ? null
            : int.tryParse(set.restCtrl.text.trim());
        final invalid = reps == null ||
            reps < 1 ||
            rir == null ||
            rir < 0 ||
            rir > 10 ||
            (kg != null && kg < 0) ||
            (set.restCtrl.text.trim().isNotEmpty &&
                (rest == null || rest < 1 || rest > 600));
        if (invalid) {
          messenger.showSnackBar(
            SnackBar(content: Text('Revisa las series de ${draft.name}')),
          );
          return;
        }
      }
    }

    setState(() => _busy = true);
    final routine = widget.routine;
    final drafts = [for (final draft in _drafts) draft.toDraft()];
    if (routine == null) {
      await routineRepository.createRoutine(
        name: name,
        description: _descCtrl.text,
        category: _category,
        level: _level,
        goal: _goal,
        targetDays: _targetDays,
        exercises: drafts,
      );
    } else {
      await routineRepository.updateRoutine(
        routineId: routine.id,
        name: name,
        description: _descCtrl.text,
        category: _category,
        level: _level,
        goal: _goal,
        targetDays: _targetDays,
        exercises: drafts,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(routine == null ? 'Rutina creada' : 'Rutina guardada'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: Text(widget.routine == null ? 'Nueva rutina' : 'Editar rutina'),
      ),
      body: _loading
          ? const Center(
              child: Text(
                'Cargando rutina...',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('routine-name'),
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Descripción (opcional)',
                        ),
                      ),
                    ],
                  ),
                ),
                _planningSection(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'EJERCICIOS',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: kOnSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_drafts.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _drafts.isEmpty
                      ? const Center(
                          child: Text(
                            'Añade ejercicios a tu rutina',
                            style: TextStyle(
                              color: kOnSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          buildDefaultDragHandles: false,
                          onReorderItem: _onReorder,
                          itemCount: _drafts.length,
                          itemBuilder: (context, index) => _draftTile(
                            _drafts[index],
                            index,
                            key: ValueKey(_drafts[index].key),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _pickExercise,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Añadir ejercicio'),
                    ),
                  ),
                ),
                _saveBar(),
              ],
            ),
    );
  }

  /// Sección de metadata de planificación (RF-18/RF-19): categoría, nivel,
  /// objetivo y frecuencia semanal, toda opcional. Plegada por defecto para
  /// no desbordar en pantallas bajas.
  Widget _planningSection() {
    final theme = Theme.of(context);
    Widget chipRow(
      String label,
      List<String> options,
      String? selected,
      ValueChanged<String?> onSelected,
    ) =>
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 84,
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: kOnSurfaceVariant,
                  ),
                ),
              ),
              for (final option in options)
                _MetaChip(
                  label: option,
                  selected: selected == option,
                  onTap: () => onSelected(selected == option ? null : option),
                ),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: const Key('planning-toggle'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _planningOpen = !_planningOpen),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PLANIFICACIÓN',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: kOnSurfaceVariant,
                  ),
                ),
                Icon(
                  _planningOpen ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: kOnSurfaceVariant,
                ),
              ],
            ),
          ),
          if (_planningOpen) ...[
            chipRow(
              'Categoría',
              const ['PPL', 'Torso-Pierna', 'Fuerza'],
              _category,
              (value) => setState(() => _category = value),
            ),
            chipRow(
              'Nivel',
              const ['Principiante', 'Intermedio', 'Avanzado'],
              _level,
              (value) => setState(() => _level = value),
            ),
            chipRow(
              'Objetivo',
              const ['Fuerza', 'Hipertrofia', 'Resistencia'],
              _goal,
              (value) => setState(() => _goal = value),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      'Días / semana',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: kOnSurfaceVariant,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'Quitar un día',
                      onPressed: _targetDays == null
                          ? null
                          : () => setState(
                                () => _targetDays = _targetDays! > 1
                                    ? _targetDays! - 1
                                    : null,
                              ),
                      icon: const Icon(Icons.remove),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    child: Text(
                      _targetDays == null ? '—' : '$_targetDays',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _targetDays == null
                            ? kOnSurfaceVariant
                            : kOnSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      tooltip: 'Añadir un día',
                      onPressed: () => setState(
                        () => _targetDays = (_targetDays ?? 0) + 1,
                      ),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: kSurface,
        border: Border(top: BorderSide(color: kSurfaceContainerHighest)),
      ),
      child: SizedBox(
        height: 48,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _nameCtrl,
          builder: (context, value, _) {
            final canSave = value.text.trim().isNotEmpty &&
                _drafts.isNotEmpty &&
                !_busy;
            return ElevatedButton(
              onPressed: canSave ? _save : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: kOnPrimary,
                      ),
                    )
                  : Text(
                      widget.routine == null
                          ? 'Crear rutina'
                          : 'Guardar cambios',
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _draftTile(_DraftExercise draft, int index, {required Key key}) {
    final theme = Theme.of(context);

    return RepaintBoundary(
      key: key,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: Column(
        children: [
          // Thumbnail at the top of the tile
          Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: kSurfaceContainerHighest)),
            ),
            child: Center(
              child: draft.exercise != null
                  ? ExerciseThumb(
                      exercise: draft.exercise!,
                      size: 60,
                    )
                  : const ThumbFallback(),
            ),
          ),
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(
                  Icons.drag_handle,
                  size: 20,
                  color: kOnSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  draft.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: kOnSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeDraft(draft),
                tooltip: 'Quitar ejercicio',
                icon: const Icon(Icons.close, size: 20, color: kOnSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _setHeader(theme),
          for (var i = 0; i < draft.sets.length; i++)
            _setRow(draft, draft.sets[i], i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('draft-add-set-${draft.key}'),
              onPressed: () => _addSet(draft),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir serie'),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                'Progresión automática',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: kOnSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Sugerir +${formatDisplay(displayWeightKg(kDefaultProgressionIncrementKg, _unitSystem))} '
                '${weightUnitOf(_unitSystem)} si cumples el objetivo',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: kOnSurfaceVariant,
                ),
              ),
              value: draft.autoProgress,
              onChanged: (value) =>
                  setState(() => draft.autoProgress = value),
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _setHeader(ThemeData theme) {
    final style = theme.textTheme.labelSmall?.copyWith(
      color: kOnSurfaceVariant,
      fontSize: 10,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          const SizedBox(width: 18),
          const SizedBox(width: 4),
          SizedBox(width: 52, child: Text('TIPO', style: style)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              weightUnitOf(_unitSystem).toUpperCase(),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text('REPS', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text('RIR', textAlign: TextAlign.center, style: style)),
          const SizedBox(width: 4),
          Expanded(
            child: Text('DESC', textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: 4),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _setRow(_DraftExercise draft, _DraftSet set, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            child: Text(
              '${index + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                color: kOnSurfaceVariant,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: PopupMenuButton<String>(
              key: Key('draft-set-type-${draft.key}-$index'),
              tooltip: 'Tipo de serie',
              initialValue: set.setType,
              onSelected: (value) => setState(() => set.setType = value),
              itemBuilder: (context) => [
                for (final entry in _setTypeLabels.entries)
                  PopupMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              child: Container(
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kSurfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _setTypeLabels[set.setType] ?? 'NOR',
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 13,
                    color: kPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _setInput(
            key: Key('draft-set-kg-${set.key}'),
            controller: set.kgCtrl,
            decimal: true,
          ),
          const SizedBox(width: 4),
          _setInput(
            key: Key('draft-set-reps-${set.key}'),
            controller: set.repsCtrl,
          ),
          const SizedBox(width: 4),
          _setInput(
            key: Key('draft-set-rir-${set.key}'),
            controller: set.rirCtrl,
          ),
          const SizedBox(width: 4),
          _setInput(
            key: Key('draft-set-rest-${set.key}'),
            controller: set.restCtrl,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: IconButton(
              key: Key('draft-remove-set-${set.key}'),
              onPressed:
                  draft.sets.length <= 1 ? null : () => _removeSet(draft, set),
              tooltip: 'Quitar serie',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.close, size: 16, color: kOnSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _setInput({
    required Key key,
    required TextEditingController controller,
    bool decimal = false,
  }) {
    return Expanded(
      child: SizedBox(
        height: 40,
        child: TextField(
          key: key,
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          style: const TextStyle(
            fontFamily: 'Geist',
            fontSize: 13,
            color: kPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: 10,
            ),
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
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: kOnSurface),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip seleccionable de la sección de planificación (opcional: al volver
/// a tocarlo se deselecciona y limpia el valor).
class _MetaChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MetaChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('meta-$label'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? kSurfaceContainerHighest : kSurfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? kOnSurface : kOnSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }
}
