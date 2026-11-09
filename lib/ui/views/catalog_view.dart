import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../domain/exercise_filter.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../widgets/exercise_filter_bar.dart';
import '../widgets/exercise_thumb.dart';
import 'exercise_info_view.dart';
import 'live_workout_view.dart';

class CatalogView extends StatefulWidget {
  const CatalogView({super.key});

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  static const _pageSize = 50;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _searchDebounce;
  late final Stream<Workout?> _activeWorkout;

  ExerciseFilter _filter = const ExerciseFilter();
  FilterOptions? _options;
  List<Exercise> _exercises = const [];
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _generation = 0;

  /// RF-1: solo busca con ≥ 2 caracteres; con menos no filtra por texto.
  String get _effectiveQuery =>
      _searchCtrl.text.trim().length >= 2 ? _searchCtrl.text : '';

  bool get _isFiltered => _effectiveQuery.isNotEmpty || _filter.activeCount > 0;

  @override
  void initState() {
    super.initState();
    _activeWorkout = workoutRepository.watchActiveWorkout();
    _scrollCtrl.addListener(_onScroll);
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
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final options = await catalogRepository.filterOptions();
    if (!mounted) return;
    setState(() => _options = options);
  }

  /// Refresca desde la primera página. Un cambio de búsqueda o de filtro
  /// invalida la petición en vuelo (caso límite de la 003).
  Future<void> _reload() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
    });
    final page = await catalogRepository.searchPage(
      query: _effectiveQuery,
      filter: _filter,
      pageSize: _pageSize,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _exercises = page.exercises;
      _total = page.total;
      _hasMore = page.total > page.exercises.length;
      _loading = false;
    });
  }

  /// RF-5: siguiente página sin bloquear la UI; si el resultado quedó
  /// obsoleto por un cambio de búsqueda o filtro, solo se suelta el bloqueo.
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);
    final page = await catalogRepository.searchPage(
      query: _effectiveQuery,
      filter: _filter,
      offset: _exercises.length,
      pageSize: _pageSize,
    );
    if (!mounted) return;
    if (generation != _generation) {
      setState(() => _loadingMore = false);
      return;
    }
    setState(() {
      _exercises = [..._exercises, ...page.exercises];
      _total = page.total;
      _hasMore = page.total > _exercises.length;
      _loadingMore = false;
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    if (position.extentAfter <= position.maxScrollExtent * 0.2) {
      _loadMore();
    }
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

  Future<void> _startOrResume(Workout? active) async {
    final workout = active ?? await workoutRepository.startWorkout();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveWorkoutView(workoutId: workout.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<Workout?>(
          stream: _activeWorkout,
          builder: (context, snapshot) {
            final active = snapshot.data;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      snapshot.connectionState == ConnectionState.waiting
                          ? null
                          : () => _startOrResume(active),
                  child: Text(
                    active == null
                        ? 'Iniciar Entreno Libre'
                        : 'Continuar sesión en curso',
                  ),
                ),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Buscar ejercicio...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        _filterBar(),
        _resultBar(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _filterBar() {
    final options = _options;
    if (options == null) return const SizedBox.shrink();
    return ExerciseFilterBar(
      filter: _filter,
      options: options,
      onChanged: (filter) {
        _searchDebounce?.cancel();
        setState(() => _filter = filter);
        _reload();
      },
    );
  }

  Widget _resultBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 4),
      child: Row(
        children: [
          Text(
            '$_total resultados',
            style: const TextStyle(color: kOnSurfaceVariant, fontSize: 12),
          ),
          const Spacer(),
          if (_filter.activeCount > 0)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Limpiar filtros'),
            ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _exercises.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_exercises.isEmpty) {
      return Center(
        child: Text(
          _isFiltered ? 'Prueba otros filtros' : 'No hay ejercicios',
          style: const TextStyle(color: kOnSurfaceVariant),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      itemCount: _exercises.length + 1,
      itemBuilder: (context, index) {
        if (index == _exercises.length) {
          return _loadingMore
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : const SizedBox(height: 16);
        }
        final ex = _exercises[index];
        return InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseInfoView(
                exercise: ex,
                database: localDb,
                workoutRepository: workoutRepository,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ExerciseThumb(exercise: ex),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.name,
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
                        '${ex.target} · ${ex.equipment}',
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
