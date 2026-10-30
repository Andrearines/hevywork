import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../domain/units.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/exercise_picker.dart';

/// Creación y edición de metas (spec 005, RF-2): el formulario cambia según
/// el tipo (peso corporal, fuerza, volumen, constancia).
class GoalEditorView extends StatefulWidget {
  final Goal? goal;

  const GoalEditorView({super.key, this.goal});

  @override
  State<GoalEditorView> createState() => _GoalEditorViewState();
}

class _GoalEditorViewState extends State<GoalEditorView> {
  static const List<String> _types = [
    'bodyweight',
    'strength',
    'volume',
    'consistency',
  ];

  final TextEditingController _targetCtrl = TextEditingController();
  String _type = 'strength';
  String _period = 'weekly';
  String _scope = 'exercise';
  Exercise? _exercise;
  List<String> _muscles = const [];
  String? _muscle;
  DateTime? _deadline;
  double? _currentWeight;
  bool _initializing = true;
  bool _busy = false;
  String _unitSystem = 'metric';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final units = UnitSystemScope.of(context);
    if (_unitSystem == units) return;
    _unitSystem = units;
    final goal = widget.goal;
    if (goal != null && goal.type != 'consistency') {
      _targetCtrl.text = _fmtTarget(displayWeightKg(goal.targetValue, units));
    }
  }

  Future<void> _init() async {
    final goal = widget.goal;
    if (goal != null) {
      _type = goal.type;
      _targetCtrl.text = _fmtTarget(goal.targetValue);
      _deadline = goal.deadline;
      if (goal.type == 'volume') {
        _period = goal.period ?? 'weekly';
      }
    }
    final ready = catalogReady;
    if (ready != null) await ready;
    if (!mounted) return;
    final muscles = await catalogRepository.muscleGroups();
    final weight = await bodyMetricRepository.latestWeightKg();
    if (goal != null && goal.metricRef != null) {
      final ref = goal.metricRef!;
      if (goal.type == 'strength' ||
          (goal.type == 'volume' && !muscles.contains(ref))) {
        final exercise = await catalogRepository.exerciseById(ref);
        if (exercise != null) _exercise = exercise;
      } else if (goal.type == 'volume') {
        _scope = 'muscle';
        _muscle = ref;
      }
    }
    if (!mounted) return;
    setState(() {
      _muscles = muscles;
      _currentWeight = weight;
      _initializing = false;
    });
  }

  String _fmtTarget(double value) => value % 1 == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  String _fmtType(String type) => switch (type) {
        'bodyweight' => 'Peso corporal',
        'strength' => 'Fuerza',
        'volume' => 'Volumen',
        'consistency' => 'Constancia',
        _ => type,
      };

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
    setState(() => _exercise = selected);
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = _targetCtrl.text.trim();
    final target = double.tryParse(text);
    if (target == null || target <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pon un objetivo válido')),
      );
      return;
    }
    if (_type == 'consistency' && (int.tryParse(text) == null || int.parse(text) < 1)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Pon sesiones por semana')),
      );
      return;
    }
    if (_type == 'strength' && _exercise == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Elige un ejercicio')),
      );
      return;
    }
    if (_type == 'volume' && _scope == 'exercise' && _exercise == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Elige un ejercicio')),
      );
      return;
    }
    if (_type == 'volume' && _scope == 'muscle' && _muscle == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Elige un músculo')),
      );
      return;
    }
    if (_deadline != null && _deadline!.isBefore(DateTime.now())) {
      messenger.showSnackBar(
        const SnackBar(content: Text('El plazo ya ha pasado')),
      );
      return;
    }

    final metricRef = switch (_type) {
      'strength' => _exercise?.id,
      'volume' => _scope == 'exercise' ? _exercise?.id : _muscle,
      _ => null,
    };
    final period = _type == 'volume' ? _period : null;
    final targetValue =
        _type == 'consistency' ? target : toKg(target, _unitSystem);

    setState(() => _busy = true);
    final existing = widget.goal;
    if (existing == null) {
      await goalRepository.createGoal(
        type: _type,
        targetValue: targetValue,
        deadline: _deadline,
        period: period,
        metricRef: metricRef,
      );
    } else {
      await goalRepository.updateGoal(
        existing.id,
        type: _type,
        targetValue: targetValue,
        deadline: _deadline,
        period: period,
        metricRef: metricRef,
      );
    }
    await goalRepository.recalculate();
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(content: Text(existing == null ? 'Meta creada' : 'Meta guardada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: Text(widget.goal == null ? 'Nueva meta' : 'Editar meta'),
      ),
      body: _initializing
          ? const Center(
              child: Text(
                'Cargando...',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Tipo',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: kOnSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in _types)
                      ChoiceChip(
                        label: Text(_fmtType(type)),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                ..._typeFields(),
                const SizedBox(height: 20),
                _deadlineField(),
              ],
            ),
      bottomNavigationBar: _initializing
          ? null
          : Container(
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
                  child: const Text('Guardar meta'),
                ),
              ),
            ),
    );
  }

  List<Widget> _typeFields() {
    final weightUnit = weightUnitOf(_unitSystem);
    switch (_type) {
      case 'bodyweight':
        return [
          TextField(
            controller: _targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Peso objetivo ($weightUnit)'),
          ),
          if (_currentWeight != null) ...[
            const SizedBox(height: 8),
            Text(
              'Tu peso actual: '
              '${_fmtTarget(displayWeightKg(_currentWeight!, _unitSystem))} '
              '$weightUnit',
              style: const TextStyle(color: kOnSurfaceVariant, fontSize: 13),
            ),
          ],
        ];
      case 'strength':
        return [
          _exerciseField('Ejercicio'),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'e1RM objetivo ($weightUnit)'),
          ),
        ];
      case 'volume':
        return [
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'exercise', label: Text('Por ejercicio')),
              ButtonSegment(value: 'muscle', label: Text('Por músculo')),
            ],
            selected: {_scope},
            onSelectionChanged: (selection) =>
                setState(() => _scope = selection.first),
          ),
          const SizedBox(height: 12),
          if (_scope == 'exercise')
            _exerciseField('Ejercicio')
          else
            DropdownButtonFormField<String>(
              initialValue: _muscle,
              decoration: const InputDecoration(labelText: 'Músculo'),
              items: [
                for (final muscle in _muscles)
                  DropdownMenuItem(value: muscle, child: Text(muscle)),
              ],
              onChanged: (value) => setState(() => _muscle = value),
            ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 'weekly', label: Text('Semanal')),
              ButtonSegment(value: 'monthly', label: Text('Mensual')),
            ],
            selected: {_period},
            onSelectionChanged: (selection) =>
                setState(() => _period = selection.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Volumen objetivo ($weightUnit)'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Peso × repeticiones de las series completadas en el periodo.',
            style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
          ),
        ];
      case 'consistency':
        return [
          TextField(
            controller: _targetCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Sesiones por semana',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuenta las sesiones completadas en los últimos 7 días.',
            style: TextStyle(color: kOnSurfaceVariant, fontSize: 13),
          ),
        ];
    }
    return const [];
  }

  Widget _exerciseField(String label) {
    return OutlinedButton.icon(
      onPressed: _pickExercise,
      icon: const Icon(Icons.add, size: 18),
      label: Text(
        _exercise == null ? 'Elegir $label' : _exercise!.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }

  Widget _deadlineField() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickDeadline,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(
              _deadline == null
                  ? 'Sin plazo'
                  : 'Plazo: ${_deadline!.day.toString().padLeft(2, '0')}/'
                      '${_deadline!.month.toString().padLeft(2, '0')}/'
                      '${_deadline!.year}',
            ),
            style: OutlinedButton.styleFrom(
              alignment: Alignment.centerLeft,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
        if (_deadline != null)
          IconButton(
            onPressed: () => setState(() => _deadline = null),
            tooltip: 'Quitar plazo',
            icon: const Icon(Icons.close, color: kOnSurfaceVariant),
          ),
      ],
    );
  }
}