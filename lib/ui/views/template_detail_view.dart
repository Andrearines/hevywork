import 'package:flutter/material.dart';

import '../../data/repositories/template_repository.dart';
import '../../main.dart';
import '../theme/colors.dart';

/// Detalle de una plantilla (spec 010, H1/H2): metadata, desglose de días y
/// ejercicios, e importación como rutina(s) editables.
class TemplateDetailView extends StatefulWidget {
  const TemplateDetailView({super.key, required this.templateId});

  final String templateId;

  @override
  State<TemplateDetailView> createState() => _TemplateDetailViewState();
}

class _TemplateDetailViewState extends State<TemplateDetailView> {
  TemplateDetail? _detail;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final detail = await templateRepository.detail(widget.templateId);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  Future<void> _import() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final result = await templateRepository.importTemplate(widget.templateId);
      if (!mounted) return;
      if (result.routines.isEmpty) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo importar: faltan los ejercicios en el catálogo',
            ),
          ),
        );
        return;
      }
      Navigator.of(context).pop(result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo importar la plantilla')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: Text(detail?.template.name ?? 'Plantilla'),
      ),
      body: _loading
          ? const Center(
              child: Text(
                'Cargando plantilla...',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            )
          : detail == null
          ? const Center(
              child: Text(
                'Plantilla no encontrada',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (detail.template.category != null)
                      _Tag(detail.template.category!),
                    if (detail.template.level != null)
                      _Tag(detail.template.level!),
                    if (detail.template.goal != null)
                      _Tag(detail.template.goal!),
                    if (detail.template.targetDays != null)
                      _Tag('${detail.template.targetDays} días/sem'),
                    if (detail.template.weeks != null)
                      _Tag('${detail.template.weeks} semanas'),
                  ],
                ),
                if (detail.template.description != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    detail.template.description!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: kOnSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                for (final day in detail.days) ...[
                  Text(
                    day.day.name,
                    style: textTheme.titleMedium?.copyWith(color: kOnSurface),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in day.exercises) _ExerciseRow(entry: entry),
                  const SizedBox(height: 20),
                ],
              ],
            ),
      bottomNavigationBar: _loading || detail == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('import-template'),
                  onPressed: _busy ? null : _import,
                  child: Text(_busy ? 'Importando...' : 'Usar esta plantilla'),
                ),
              ),
            ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.entry});

  final TemplateExerciseDetail entry;

  String get _summary {
    final sets = entry.sets;
    if (sets.isEmpty) return 'Sin series';
    final reps = sets.map((s) => s.reps).toSet();
    final rirs = sets.map((s) => s.rir).toSet();
    final repsLabel = reps.length == 1
        ? '${reps.first} reps'
        : 'reps variables';
    final rirLabel = rirs.length == 1 ? ' · RIR ${rirs.first}' : '';
    return '${sets.length} series · $repsLabel$rirLabel';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final missing = entry.exercise == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.exercise?.name ?? 'Ejercicio no disponible',
                  style: textTheme.bodyLarge?.copyWith(
                    color: missing ? kOnSurfaceVariant : kOnSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  missing ? 'Se omitirá al importar' : _summary,
                  style: textTheme.bodySmall?.copyWith(
                    color: kOnSurfaceVariant,
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

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: kOnSurfaceVariant),
      ),
    );
  }
}
