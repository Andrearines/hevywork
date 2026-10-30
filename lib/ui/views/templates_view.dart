import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/template_repository.dart';
import '../../main.dart';
import '../theme/colors.dart';
import 'template_detail_view.dart';

/// Navegador del catálogo de plantillas comunitarias (spec 010, RF-3/RF-4):
/// búsqueda por nombre, filtro por categoría y detalle con importación.
class TemplatesView extends StatefulWidget {
  const TemplatesView({super.key});

  @override
  State<TemplatesView> createState() => _TemplatesViewState();
}

class _TemplatesViewState extends State<TemplatesView> {
  List<CommunityTemplate> _templates = const [];
  String _query = '';
  String _category = '';
  bool _loading = true;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _templates.isEmpty;
      _offline = false;
    });

    try {
      await templateRepository.refresh();
    } catch (_) {
      if (mounted) setState(() => _offline = true);
    }

    final cached = await templateRepository.cachedTemplates();
    if (!mounted) return;
    setState(() {
      _templates = cached;
      _loading = false;
    });
  }

  List<String> get _categories {
    final values = <String>{};
    for (final template in _templates) {
      final category = template.category;
      if (category != null && category.isNotEmpty) values.add(category);
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  List<CommunityTemplate> get _filtered {
    final term = _query.trim().toLowerCase();
    return [
      for (final template in _templates)
        if ((term.isEmpty || template.name.toLowerCase().contains(term)) &&
            (_category.isEmpty || template.category == _category))
          template,
    ];
  }

  Future<void> _open(String id) async {
    final result = await Navigator.of(context).push<TemplateImportResult>(
      MaterialPageRoute<TemplateImportResult>(
        builder: (_) => TemplateDetailView(templateId: id),
      ),
    );
    if (result == null || !mounted) return;

    final count = result.routines.length;
    final base = count == 1 ? 'Rutina creada' : '$count rutinas creadas';
    final message = result.skippedExercises == 0
        ? base
        : '$base · ${result.skippedExercises} ejercicio(s) no disponibles';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: const Text('Biblioteca de plantillas'),
      ),
      body: _loading
          ? const Center(
              child: Text(
                'Cargando plantillas...',
                style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
              ),
            )
          : _templates.isEmpty
          ? _EmptyState(offline: _offline, onRetry: _load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: TextField(
                    onChanged: (value) => setState(() => _query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Buscar plantillas',
                    ),
                  ),
                ),
                if (_categories.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      children: [
                        _CategoryChip(
                          label: 'Todas',
                          selected: _category.isEmpty,
                          onTap: () => setState(() => _category = ''),
                        ),
                        for (final category in _categories)
                          _CategoryChip(
                            label: category,
                            selected: _category == category,
                            onTap: () => setState(() => _category = category),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No hay plantillas con ese filtro',
                            style: textTheme.bodyMedium?.copyWith(
                              color: kOnSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final template = _filtered[index];
                            return _TemplateCard(
                              template: template,
                              onTap: () => _open(template.id),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.offline, required this.onRetry});

  final bool offline;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline ? Icons.cloud_off : Icons.article_outlined,
              size: 32,
              color: kOnSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              offline
                  ? 'Conéctate para ver las plantillas'
                  : 'No hay plantillas disponibles',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(color: kOnSurface),
            ),
            const SizedBox(height: 6),
            Text(
              offline
                  ? 'La primera carga necesita conexión; después podrás '
                        'navegar sin ella.'
                  : 'Vuelve a intentarlo en unos minutos.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: kOnSurfaceVariant),
            ),
            if (offline) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onRetry(),
                child: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? kOnSurface : kSurfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? kSurface : kOnSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});

  final CommunityTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: kSurfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: Key('template-card-${template.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.name,
                style: textTheme.titleMedium?.copyWith(color: kOnSurface),
              ),
              if (template.description != null) ...[
                const SizedBox(height: 6),
                Text(
                  template.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: kOnSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (template.category != null) _Tag(template.category!),
                  if (template.level != null) _Tag(template.level!),
                  if (template.targetDays != null)
                    _Tag('${template.targetDays} días/sem'),
                  if (template.goal != null) _Tag(template.goal!),
                ],
              ),
            ],
          ),
        ),
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
