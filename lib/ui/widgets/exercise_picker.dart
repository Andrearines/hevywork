import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/exercise_filter.dart';
import '../../main.dart';
import '../theme/colors.dart';
import 'exercise_filter_bar.dart';
import 'exercise_thumb.dart';

/// Selector de ejercicios del catálogo local, con búsqueda y filtros (RF-1 de
/// la 003). Devuelve el ejercicio elegido vía `Navigator.pop`.
class ExercisePicker extends StatefulWidget {
  const ExercisePicker({super.key});

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<ExercisePicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  ExerciseFilter _filter = const ExerciseFilter();
  FilterOptions? _options;
  List<Exercise> _results = const [];
  int _total = 0;
  bool _loading = true;
  int _generation = 0;

  /// RF-1 de la 003: solo filtra por texto con ≥ 2 caracteres.
  String get _effectiveQuery =>
      _searchCtrl.text.trim().length >= 2 ? _searchCtrl.text : '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final ready = catalogReady;
    if (ready != null) await ready;
    if (!mounted) return;
    await Future.wait([_reload(), _loadOptions()]);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final options = await catalogRepository.filterOptions();
    if (!mounted) return;
    setState(() => _options = options);
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() => _loading = true);
    final page = await catalogRepository.searchPage(
      query: _effectiveQuery,
      filter: _filter,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _results = page.exercises;
      _total = page.total;
      _loading = false;
    });
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    setState(() => _filter = const ExerciseFilter());
    _reload();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), _reload);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = _options;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
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
                      'Añadir ejercicio',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: kOnSurface),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Buscar ejercicio...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (options != null)
              ExerciseFilterBar(
                filter: _filter,
                options: options,
                onChanged: (filter) {
                  _searchDebounce?.cancel();
                  setState(() => _filter = filter);
                  _reload();
                },
              ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 8, top: 2),
              child: Row(
                children: [
                  Text(
                    '$_total resultados',
                    style: const TextStyle(
                      color: kOnSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  if (_filter.activeCount > 0)
                    TextButton(
                      onPressed: _clearFilters,
                      child: const Text('Limpiar filtros'),
                    ),
                ],
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text(
          'No hay ejercicios',
          style: TextStyle(color: kOnSurfaceVariant, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final exercise = _results[index];
        return InkWell(
          onTap: () => Navigator.pop(context, exercise),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ExerciseThumb(exercise: exercise, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kOnSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${exercise.target} · ${exercise.equipment}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kOnSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
  }
}
