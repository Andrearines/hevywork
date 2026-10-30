import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/body_metric_repository.dart';
import '../../domain/body_composition.dart';
import '../../domain/body_metrics.dart';
import '../../domain/units.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';

/// Creación y edición de un registro diario de peso y medidas (spec 006,
/// RF-1/RF-2). Peso y medidas son opcionales, pero hace falta al menos uno de
/// los dos (o notas) para guardar.
class BodyMetricEditorView extends StatefulWidget {
  final BodyMetric? record;

  const BodyMetricEditorView({super.key, this.record});

  @override
  State<BodyMetricEditorView> createState() => _BodyMetricEditorViewState();
}

class _BodyMetricEditorViewState extends State<BodyMetricEditorView> {
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _fatCtrl = TextEditingController();
  final TextEditingController _leanCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final Map<String, TextEditingController> _measureCtrls = {
    for (final id in kBodyMeasures) id: TextEditingController(),
  };
  late DateTime _date;
  bool _busy = false;
  String _unitSystem = 'metric';

  @override
  void initState() {
    super.initState();
    final record = widget.record;
    _date = BodyMetricRepository.dayOf(DateTime.now());
    if (record != null) {
      _date = BodyMetricRepository.dayOf(record.date);
      if (record.weightKg != null) _weightCtrl.text = _fmt(record.weightKg!);
      if (record.bodyFatPct != null) {
        _fatCtrl.text = _fmt(record.bodyFatPct!);
      }
      if (record.leanMassKg != null) {
        _leanCtrl.text = _fmt(record.leanMassKg!);
      }
      final measures = decodeMeasures(record.measuresJson);
      for (final id in kBodyMeasures) {
        final value = measures[id];
        if (value != null) _measureCtrls[id]!.text = _fmt(value);
      }
      if (record.notes != null) _notesCtrl.text = record.notes!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final units = UnitSystemScope.of(context);
    if (_unitSystem == units) return;
    _unitSystem = units;
    final record = widget.record;
    if (record == null) return;
    if (record.weightKg != null) {
      _weightCtrl.text = _fmt(displayWeightKg(record.weightKg!, units));
    }
    if (record.bodyFatPct != null) _fatCtrl.text = _fmt(record.bodyFatPct!);
    if (record.leanMassKg != null) {
      _leanCtrl.text = _fmt(displayWeightKg(record.leanMassKg!, units));
    }
    final measures = decodeMeasures(record.measuresJson);
    for (final id in kBodyMeasures) {
      final value = measures[id];
      if (value != null) {
        _measureCtrls[id]!.text = _fmt(displayLengthCm(value, units));
      }
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _fatCtrl.dispose();
    _leanCtrl.dispose();
    _notesCtrl.dispose();
    for (final ctrl in _measureCtrls.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String _fmt(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = BodyMetricRepository.dayOf(picked));
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);

    final weightText = _weightCtrl.text.trim();
    final double? weightKg;
    if (weightText.isEmpty) {
      weightKg = null;
    } else {
      final parsed = double.tryParse(weightText);
      if (parsed == null || parsed <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Pon un peso válido')),
        );
        return;
      }
      weightKg = toKg(parsed, _unitSystem);
    }

    final measures = <String, double>{};
    for (final id in kBodyMeasures) {
      final text = _measureCtrls[id]!.text.trim();
      if (text.isEmpty) continue;
      final parsed = double.tryParse(text);
      if (parsed == null || parsed <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Revisa las medidas')),
        );
        return;
      }
      measures[id] = toCm(parsed, _unitSystem);
    }

    final fatText = _fatCtrl.text.trim();
    final double? bodyFatPct;
    if (fatText.isEmpty) {
      bodyFatPct = null;
    } else {
      final parsed = double.tryParse(fatText);
      if (parsed == null || parsed < kBodyFatMin || parsed > kBodyFatMax) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Pon un % de grasa entre 0 y 70')),
        );
        return;
      }
      bodyFatPct = parsed;
    }

    final leanText = _leanCtrl.text.trim();
    final double? leanMassKg;
    if (leanText.isEmpty) {
      leanMassKg = null;
    } else {
      final parsed = double.tryParse(leanText);
      if (parsed == null || parsed <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Pon una masa magra válida')),
        );
        return;
      }
      leanMassKg = toKg(parsed, _unitSystem);
    }

    if (weightKg == null &&
        bodyFatPct == null &&
        leanMassKg == null &&
        measures.isEmpty &&
        _notesCtrl.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Añade peso, medidas o composición')),
      );
      return;
    }

    setState(() => _busy = true);
    await bodyMetricRepository.upsert(
      date: _date,
      weightKg: weightKg,
      bodyFatPct: bodyFatPct,
      leanMassKg: leanMassKg,
      measures: measures,
      notes: _notesCtrl.text,
    );
    await goalRepository.recalculate();
    if (!mounted) return;
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(widget.record == null ? 'Registro guardado' : 'Registro actualizado'),
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
        title: Text(widget.record == null ? 'Nuevo registro' : 'Editar registro'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Fecha',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: kOnSurfaceVariant),
          ),
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
          const SizedBox(height: 20),
          Text(
            'Peso',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weightCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Peso (${weightUnitOf(_unitSystem)})'),
          ),
          const SizedBox(height: 20),
          Text(
            'Composición',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _fatCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '% de grasa'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _leanCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Masa magra (${weightUnitOf(_unitSystem)}) · opcional',
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Medidas',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            _unitSystem == 'imperial' ? 'En pulgadas.' : 'En centímetros.',
            style: const TextStyle(color: kOnSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final id in kBodyMeasures) ...[
            TextField(
              controller: _measureCtrls[id],
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${measureLabel(id)} (${lengthUnitOf(_unitSystem)})',
              ),
            ),
            if (id != kBodyMeasures.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 20),
          Text(
            'Notas',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notas'),
          ),
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
            child: const Text('Guardar registro'),
          ),
        ),
      ),
    );
  }
}