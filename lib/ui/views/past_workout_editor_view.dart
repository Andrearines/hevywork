import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/units.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/exercise_picker.dart';

/// Serie de una sesión pasada en edición.
class _DraftSet {
  final String key;
  String setType;
  final String? routineSetId;
  final TextEditingController kgCtrl;
  final TextEditingController repsCtrl;
  final TextEditingController rirCtrl;

  _DraftSet({
    required this.key,
    required this.routineSetId,
    this.setType = 'normal',
    required String unitSystem,
    double weightKg = 0,
    int reps = 10,
    int rir = 2,
  })  : kgCtrl = TextEditingController(
          text: weightKg == 0
              ? ''
              : _fmtNumber(displayWeightKg(weightKg, unitSystem)),
        ),
        repsCtrl = TextEditingController(text: '$reps'),
        rirCtrl = TextEditingController(text: '$rir');

  void dispose() {
    kgCtrl.dispose();
    repsCtrl.dispose();
    rirCtrl.dispose();
  }
}

class _DraftExercise {
  final String key;
  final String exerciseId;
  final String name;
  final List<_DraftSet> sets;

  _DraftExercise({
    required this.key,
    required this.exerciseId,
    required this.name,
    required this.sets,
  });

  void dispose() {
    for (final set in sets) {
      set.dispose();
    }
  }
}

String _fmtNumber(double value) {
  final rounded = (value * 1000).roundToDouble() / 1000;
  final text = rounded.toString();
  return text.contains('.') ? text : '$text.0';
}

/// Editor de una sesión pasada (spec 012): fecha, hora de inicio, duración y
/// ejercicios con sus series, que se guardan directamente como sesión
/// terminada (RF-4).
class PastWorkoutEditorView extends StatefulWidget {
  const PastWorkoutEditorView({super.key});

  @override
  State<PastWorkoutEditorView> createState() => _PastWorkoutEditorViewState();
}

class _PastWorkoutEditorViewState extends State<PastWorkoutEditorView> {
  final TextEditingController _durationCtrl = TextEditingController(text: '60');
  final List<_DraftExercise> _drafts = [];
  late DateTime _date;
  late TimeOfDay _start;
  String? _routineId;
  String? _routineName;
  bool _busy = false;
  int _draftSeq = 0;
  int _setSeq = 0;
  String _unitSystem = 'metric';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    _start = now.hour < 17
        ? TimeOfDay(hour: now.hour, minute: (now.minute ~/ 5) * 5)
        : const TimeOfDay(hour: 17, minute: 0);
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
        if (text.isEmpty) continue;
        final value = double.tryParse(text.replaceAll(',', '.'));
        if (value == null) continue;
        set.kgCtrl.text = _fmtNumber(
          displayWeightKg(toKg(value, previous), units),
        );
      }
    }
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  _DraftSet _newSet({
    String setType = 'normal',
    String? routineSetId,
    double weightKg = 0,
    int reps = 10,
    int rir = 2,
  }) =>
      _DraftSet(
        key: 'set-${_setSeq++}',
        setType: setType,
        routineSetId: routineSetId,
        unitSystem: _unitSystem,
        weightKg: weightKg,
        reps: reps,
        rir: rir,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _clampStartToNow();
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked == null || !mounted) return;
    setState(() => _start = picked);
  }

  void _clampStartToNow() {
    final now = DateTime.now();
    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _start.hour,
      _start.minute,
    );
    if (!start.isAfter(now)) return;
    _start = TimeOfDay(hour: now.hour, minute: (now.minute ~/ 5) * 5);
  }

  Future<void> _pickRoutine() async {
    final routine = await showModalBottomSheet<Routine>(
      context: context,
      backgroundColor: kSurfaceContainer,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: kSurfaceContainerHighest),
      ),
      builder: (context) => const _RoutinePickerSheet(),
    );
    if (routine == null || !mounted) return;

    if (_drafts.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: kSurfaceContainer,
          surfaceTintColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            side: BorderSide(color: kSurfaceContainerHighest),
          ),
          title: const Text('Reemplazar ejercicios'),
          content: const Text(
            'La rutina elegida sustituye los ejercicios actuales del '
            'borrador.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Reemplazar'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }

    final entries = await routineRepository.routineExercises(routine.id);
    final available = [
      for (final entry in entries)
        if (entry.exercise != null) entry,
    ];
    if (available.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La rutina no tiene ejercicios disponibles'),
        ),
      );
      return;
    }

    final planned = <String, List<RoutineSet>>{};
    final batch = await routineRepository.routineSetsBatch(
      [for (final entry in available) entry.item.id],
    );
    for (final set in batch) {
      planned.putIfAbsent(set.routineExerciseId, () => []).add(set);
    }

    if (!mounted) return;
    setState(() {
      for (final draft in _drafts) {
        draft.dispose();
      }
      _drafts.clear();
      for (final entry in available) {
        final rows = planned[entry.item.id]?..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
        final sets = rows == null || rows.isEmpty
            ? [_newSet(), _newSet(), _newSet()]
            : [
                for (final row in rows)
                  _newSet(
                    setType: row.setType,
                    routineSetId: row.id,
                    weightKg: row.weightKg,
                    reps: row.reps,
                    rir: row.rir,
                  ),
              ];
        _drafts.add(
          _DraftExercise(
            key: 'ex-${_draftSeq++}',
            exerciseId: entry.item.exerciseId,
            name: entry.exercise!.name,
            sets: sets,
          ),
        );
      }
      _routineId = routine.id;
      _routineName = routine.name;
    });
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
          key: 'ex-${_draftSeq++}',
          exerciseId: selected.id,
          name: selected.name,
          sets: [_newSet(), _newSet(), _newSet()],
        ),
      );
    });
  }

  void _removeDraft(_DraftExercise draft) {
    setState(() {
      draft.dispose();
      _drafts.remove(draft);
      if (_drafts.isEmpty) {
        _routineId = null;
        _routineName = null;
      }
    });
  }

  void _addSet(_DraftExercise draft) {
    setState(() => draft.sets.add(_newSet()));
  }

  void _removeSet(_DraftExercise draft, _DraftSet set) {
    setState(() {
      set.dispose();
      draft.sets.remove(set);
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_drafts.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Añade al menos un ejercicio')),
      );
      return;
    }

    final duration = int.tryParse(_durationCtrl.text.trim());
    if (duration == null || duration < 1 || duration > 720) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('La duración debe estar entre 1 y 720 minutos'),
        ),
      );
      return;
    }

    final startedAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _start.hour,
      _start.minute,
    );
    if (startedAt.isAfter(DateTime.now())) {
      messenger.showSnackBar(
        const SnackBar(content: Text('La hora de inicio no puede ser futura')),
      );
      return;
    }

    final exercises = <PastExerciseDraft>[];
    for (final draft in _drafts) {
      if (draft.sets.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text('${draft.name}: añade al menos una serie')),
        );
        return;
      }
      final sets = <PastSetDraft>[];
      for (final set in draft.sets) {
        final reps = int.tryParse(set.repsCtrl.text.trim());
        if (reps == null || reps < 1) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '${draft.name}: las repeticiones deben ser 1 o más',
              ),
            ),
          );
          return;
        }
        final rir = int.tryParse(set.rirCtrl.text.trim());
        if (rir == null || rir < 0 || rir > 10) {
          messenger.showSnackBar(
            SnackBar(content: Text('${draft.name}: el RIR debe estar entre 0 y 10')),
          );
          return;
        }
        final kgText = set.kgCtrl.text.trim();
        var weightKg = 0.0;
        if (kgText.isNotEmpty) {
          final parsed = double.tryParse(kgText.replaceAll(',', '.'));
          if (parsed == null || parsed < 0) {
            messenger.showSnackBar(
              SnackBar(content: Text('${draft.name}: pon un peso válido')),
            );
            return;
          }
          weightKg = toKg(parsed, _unitSystem);
        }
        sets.add(
          PastSetDraft(
            weightKg: weightKg,
            reps: reps,
            rir: rir,
            setType: set.setType,
            routineSetId: set.routineSetId,
          ),
        );
      }
      exercises.add(
        PastExerciseDraft(exerciseId: draft.exerciseId, sets: sets),
      );
    }

    setState(() => _busy = true);
    try {
      await workoutRepository.createPastWorkout(
        startedAt: startedAt,
        duration: Duration(minutes: duration),
        exercises: exercises,
        routineId: _routineId,
        name: _routineName,
      );
      await fatigueRepository.recalculate();
      await goalRepository.recalculate();
    } on PastWorkoutValidationException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    } on SetValidationException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Entrenamiento registrado')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: const Text('Registrar entrenamiento pasado'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _label(theme, 'Cuándo'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              '${_date.day.toString().padLeft(2, '0')}/'
              '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickTime,
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(_start.format(context)),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('past-duration'),
            controller: _durationCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duración (min)'),
          ),
          const SizedBox(height: 20),
          _label(theme, 'Ejercicios'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickRoutine,
            icon: const Icon(Icons.playlist_play, size: 18),
            label: const Text('Elegir rutina'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickExercise,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Añadir ejercicio'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_drafts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Text(
                'Añade los ejercicios que hiciste ese día: elige una rutina '
                'o búscalos en el catálogo.',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
              ),
            ),
          for (final draft in _drafts) _draftTile(draft),
        ],
      ),
      bottomNavigationBar: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: const BoxDecoration(
          color: kSurface,
          border: Border(top: BorderSide(color: kSurfaceContainerHighest)),
        ),
        child: SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: kOnPrimary,
                    ),
                  )
                : const Text('Guardar sesión'),
          ),
        ),
      ),
    );
  }

  Widget _label(ThemeData theme, String text) => Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(color: kOnSurfaceVariant),
      );

  Widget _draftTile(_DraftExercise draft) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey(draft.key),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      decoration: BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
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
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: kOnSurfaceVariant,
                ),
              ),
            ],
          ),
          _setHeader(theme),
          for (var i = 0; i < draft.sets.length; i++)
            _setRow(draft, draft.sets[i], i),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _addSet(draft),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir serie'),
            ),
          ),
        ],
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
          Expanded(
            child: Text('RIR', textAlign: TextAlign.center, style: style),
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
          _setInput(
            key: Key('past-set-kg-${draft.key}-$index'),
            controller: set.kgCtrl,
            decimal: true,
          ),
          const SizedBox(width: 4),
          _setInput(
            key: Key('past-set-reps-${draft.key}-$index'),
            controller: set.repsCtrl,
          ),
          const SizedBox(width: 4),
          _setInput(
            key: Key('past-set-rir-${draft.key}-$index'),
            controller: set.rirCtrl,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: IconButton(
              key: Key('past-remove-set-${draft.key}-$index'),
              onPressed: draft.sets.length <= 1
                  ? null
                  : () => _removeSet(draft, set),
              tooltip: 'Quitar serie',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(
                Icons.close,
                size: 16,
                color: kOnSurfaceVariant,
              ),
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

/// Hoja con la lista de rutinas del perfil para elegir el origen (spec 012,
/// RF-2).
class _RoutinePickerSheet extends StatelessWidget {
  const _RoutinePickerSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: const BoxDecoration(
                color: kSurfaceContainerHighest,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Elegir rutina',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: kOnSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, color: kOnSurfaceVariant),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Routine>>(
              stream: routineRepository.watchRoutines(),
              builder: (context, snapshot) {
                final routines = snapshot.data ?? const <Routine>[];
                if (routines.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aún no tienes rutinas',
                      style: TextStyle(
                        color: kOnSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: routines.length,
                  itemBuilder: (context, index) {
                    final routine = routines[index];
                    return InkWell(
                      onTap: () => Navigator.pop(context, routine),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                routine.name,
                                style: const TextStyle(
                                  color: kOnSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: kOutline,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
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
