import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/theme/app_theme.dart';
import 'app_config.dart';
import 'data/local/database.dart';
import 'data/repositories/body_metric_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/fatigue_repository.dart';
import 'data/repositories/gif_cache.dart';
import 'data/repositories/goal_repository.dart';
import 'data/repositories/photo_repository.dart';
import 'data/repositories/profile_repository.dart';
import 'data/repositories/routine_repository.dart';
import 'data/repositories/template_repository.dart';
import 'data/repositories/workout_repository.dart';
import 'data/sync/sync_engine.dart';
import 'domain/media.dart';
import 'domain/services/auth_service.dart';
import 'ui/unit_system_scope.dart';
import 'ui/views/catalog_view.dart';
import 'ui/views/live_workout_view.dart';
import 'ui/views/profile_view.dart';
import 'ui/views/progress_view.dart';
import 'ui/views/routines_view.dart';
import 'ui/views/train_view.dart';
import 'ui/widgets/hevy_app_bar.dart';
import 'ui/widgets/hevy_bottom_nav.dart';

// Credenciales por --dart-define (constitución §10):
// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...

late final AppDatabase localDb;
late final SyncEngine syncEngine;
late final CatalogRepository catalogRepository;
late final WorkoutRepository workoutRepository;
late final RoutineRepository routineRepository;
late final GoalRepository goalRepository;
late final BodyMetricRepository bodyMetricRepository;
late final FatigueRepository fatigueRepository;
late final ProfileRepository profileRepository;
late final PhotoRepository photoRepository;
late final TemplateRepository templateRepository;
late final GifCache gifCache;
AuthService? authService;

Future<void>? catalogReady;

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La cuenta es opcional: sin credenciales la app funciona en local (RF-16).
  final hasSupabase =
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  if (hasSupabase) {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  }

  localDb = AppDatabase();
  fatigueRepository = FatigueRepository(localDb);
  syncEngine = SyncEngine(
    localDb,
    hasSupabase ? Supabase.instance.client : null,
    // Spec 007 (RF-6/H2): tras cada sync completado se recalcula la fatiga.2
    onSyncCompleted: fatigueRepository.recalculate,
    // Spec 009 (RF-7): cada ciclo con sesión sube las fotos pendientes.
    onCycleCompleted: () => photoRepository.uploadPending(),
  );
  catalogRepository = CatalogRepository(localDb);
  workoutRepository = WorkoutRepository(
    localDb,
    enqueue: syncEngine.enqueueMutation,
  );
  routineRepository = RoutineRepository(
    localDb,
    workoutRepository,
    enqueue: syncEngine.enqueueMutation,
  );
  templateRepository = TemplateRepository(
    localDb,
    routineRepository,
    supabase: hasSupabase ? Supabase.instance.client : null,
  );
  goalRepository = GoalRepository(localDb, enqueue: syncEngine.enqueueMutation);
  bodyMetricRepository = BodyMetricRepository(
    localDb,
    enqueue: syncEngine.enqueueMutation,
  );
  profileRepository = ProfileRepository(
    localDb,
    enqueue: syncEngine.enqueueMutation,
  );
  photoRepository = PhotoRepository(
    localDb,
    supabase: hasSupabase ? Supabase.instance.client : null,
    enqueue: syncEngine.enqueueMutation,
    // RF-7: subida en segundo plano al bucket privado `progress-photos`.
    uploader: (storagePath, bytes) async {
      await Supabase.instance.client.storage
          .from('progress-photos')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
    },
  );
  // RF-3 de la 001: caché con nombre de los GIFs del catálogo en la ficha.
  gifCache = GifCache(
    download: hasSupabase
        ? (gifPath) => Supabase.instance.client.storage
              .from(mediaBucket)
              .download(gifPath)
        : null,
  );
  if (hasSupabase) {
    authService = AuthService(Supabase.instance.client, localDb);
  }

  catalogReady = catalogRepository.initializeCatalogIfEmpty().catchError((
    Object error,
  ) {
    debugPrint('El catálogo no pudo inicializarse: $error');
  });

  syncEngine.notices.listen((message) {
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  });

  runApp(const HevyWorkApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    syncEngine.start();
  });
}

class HevyWorkApp extends StatefulWidget {
  const HevyWorkApp({super.key});

  @override
  State<HevyWorkApp> createState() => _HevyWorkAppState();
}

class _HevyWorkAppState extends State<HevyWorkApp> {
  String _unitSystem = 'metric';
  StreamSubscription<LocalProfile>? _profileSub;

  @override
  void initState() {
    super.initState();
    _profileSub = profileRepository.watchProfile().listen((profile) {
      if (_unitSystem == profile.unitSystem) return;
      setState(() => _unitSystem = profile.unitSystem);
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HevyWork',
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: buildAppTheme(),
      builder: (context, child) => UnitSystemScope(
        unitSystem: _unitSystem,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const MainNavigator(),
    );
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  static const List<({String title, Widget body})> destinations = [
    (title: 'Entrenar', body: TrainView()),
    (title: 'Rutinas', body: RoutinesView()),
    (title: 'Progreso', body: ProgressView()),
    (title: 'Perfil', body: ProfileView()),
  ];

  int _currentIndex = 0;
  final Set<int> _visited = {0};

  /// Hueco entre el final del contenido scrolleable y el borde superior de
  /// la pill flotante, para que la última fila no quede justo pegada.
  static const double bottomGap = 12;

  @override
  void initState() {
    super.initState();
    _maybeRestoreSession();
  }

  /// RF-10/RF-11 de la 002: al arrancar, si hay una sesión activa marcada se
  /// reabre sola; si tiene más de 7 días se pregunta reanudar o abandonar
  /// (abandonar = RF-19 de la 001). El resto del descanso vive en la sesión,
  /// así que se restaura con ella.
  Future<void> _maybeRestoreSession() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final workout = await workoutRepository.restoreLastActiveWorkout();
      if (workout == null || !mounted) return;

      final age = DateTime.now().difference(workout.startedAt);
      if (age.inDays > 7) {
        await _askReanudarOAbandonar(workout);
      } else {
        _openSession(workout.id);
      }
    });
  }

  void _openSession(String workoutId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveWorkoutView(workoutId: workoutId),
      ),
    );
  }

  Future<void> _askReanudarOAbandonar(Workout workout) async {
    final resume = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sesión sin terminar'),
        content: Text(
          'Tienes una sesión sin terminar del '
          '${_formatDate(workout.startedAt)}. ¿La reanudas o la abandonas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abandonar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reanudar'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resume == true) {
      _openSession(workout.id);
    } else {
      await workoutRepository.abandonWorkout(workout.id);
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  void _goTo(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  /// RF-10 de la 008: el catálogo pasa de tab a pantalla propia, accesible
  /// desde el icono de búsqueda del header de Entrenar.
  void _openCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Ejercicios'),
            automaticallyImplyLeading: true,
          ),
          body: const CatalogView(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: hevyAppBar(
        context,
        title: destinations[_currentIndex].title,
        onProfileTap: () => _goTo(3),
        onCatalogTap: _currentIndex == 0 ? _openCatalog : null,
      ),
      // La pill flota sobre el contenido (mockup): el cuerpo ocupa toda la
      // pantalla y solo se reserva el hueco inferior para poder hacer scroll
      // hasta el final sin que la pill tape la última fila (T-1).
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              bottom: bottomInset + HevyBottomNav.height + bottomGap,
            ),
            child: IndexedStack(
              index: _currentIndex,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  if (_visited.contains(i))
                    TickerMode(
                      enabled: i == _currentIndex,
                      child: destinations[i].body,
                    )
                  else
                    const SizedBox.shrink(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: HevyBottomNav(currentIndex: _currentIndex, onTap: _goTo),
          ),
        ],
      ),
    );
  }
}
