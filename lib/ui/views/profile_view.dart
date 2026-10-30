import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/local/database.dart';
import '../../domain/body_composition.dart';
import '../../domain/goals.dart';
import '../../domain/profile_stats.dart';
import '../../domain/services/auth_service.dart';
import '../../domain/units.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../unit_system_scope.dart';
import '../widgets/capped_scroll.dart';
import '../widgets/metric_cluster.dart';
import '../widgets/section_header.dart';
import 'soon_view.dart';

/// Formato corto de una altura/medida para los subtítulos de ajustes.
String _fmtMeasure(double value) =>
    value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

const Map<String, String> _goalTypeLabels = {
  'bodyweight': 'Peso corporal',
  'strength': 'Fuerza',
  'volume': 'Volumen',
  'consistency': 'Constancia',
};

const int _visibleGoalTiles = 3;
const double _goalTileHeight = 54;
const String _avatarBucket = 'profile-photos';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  late final Stream<LocalProfile> _profile = profileRepository.watchProfile();
  late final Stream<ProfileStats> _stats = profileRepository.watchStats();
  late final Stream<List<Goal>> _goals = goalRepository.watchGoals();

  Future<void> _editName(String? current) async {
    final controller = TextEditingController(text: current ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tu nombre'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Atleta'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await profileRepository.setDisplayName(result);
  }

  Future<void> _export() async {
    try {
      final csv = await profileRepository.exportCsv();
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              bytes,
              mimeType: 'text/csv',
              name: 'hevywork_export.csv',
            ),
          ],
          fileNameOverrides: const ['hevywork_export.csv'],
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.dismissed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exportación cancelada')),
        );
      } else if (result.status == ShareResultStatus.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La exportación no está disponible aquí'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el archivo')),
      );
    }
  }

  Future<void> _pickRirPreference(bool current) async {
    var value = current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ajustes de RIR y RPE'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elige cómo registrar el esfuerzo en cada serie.',
              ),
              const SizedBox(height: 16),
              RadioGroup<bool>(
                groupValue: value,
                onChanged: (v) => setState(() => value = v ?? value),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('RIR (repeticiones en reserva)'),
                      subtitle: Text('Cuántas repeticiones te quedan'),
                      value: false,
                    ),
                    RadioListTile<bool>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('RPE (esfuerzo percibido)'),
                      subtitle: Text('Del 1 al 10 según lo duro que fue'),
                      value: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || value == current) return;
    await profileRepository.setPreferRpe(value);
  }

  Future<void> _signOut() async {
    final service = authService;
    if (service == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('Se dejará de sincronizar en este dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await service.signOut();
      if (mounted) setState(() {});
    }
  }

  Future<void> _signInWithEmail() async {
    final service = authService;
    if (service == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sin configuración de Supabase no hay cuenta: arranca la app '
            'con tool/run.sh.',
          ),
        ),
      );
      return;
    }
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _EmailSignInDialog(service: service),
    );
    if (!mounted) return;
    setState(() {});
    if (result == 'created') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada. Revisa tu correo para confirmarla.'),
        ),
      );
    }
  }

  Future<void> _pickUnits() async {
    final current = await profileRepository.currentUnitSystem();
    if (!mounted) return;
    var value = current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Unidades de medida'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Elige las unidades para peso, medidas y volúmenes.',
              ),
              const SizedBox(height: 16),
              RadioGroup<String>(
                groupValue: value,
                onChanged: (v) =>
                    setState(() => value = v ?? value),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Métrico'),
                      subtitle: Text('kg / cm'),
                      value: 'metric',
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Imperial'),
                      subtitle: Text('lb / in'),
                      value: 'imperial',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || value == current) return;
    await profileRepository.setUnitSystem(value);
  }

  void _openDevices() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SoonView(
          title: 'Dispositivos',
          message: 'Próximamente podrás conectar tu báscula, tu caliper y leer tu frecuencia cardiaca.',
        ),
      ),
    );
  }

  /// Sexo para la estimación US Navy (spec 009, RF-4). Opcional.
  Future<void> _pickSex() async {
    final profile = await profileRepository.current();
    if (!mounted) return;
    final units = UnitSystemScope.of(context);
    String? value = profile.sex;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Sexo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se usa para estimar el % de grasa con el método US Navy '
                '(unidades: ${units == 'imperial' ? 'in' : 'cm'}).',
              ),
              const SizedBox(height: 16),
              RadioGroup<String?>(
                groupValue: value,
                onChanged: (v) => setState(() => value = v),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<String?>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Hombre'),
                      value: kSexMale,
                    ),
                    RadioListTile<String?>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Mujer'),
                      value: kSexFemale,
                    ),
                    RadioListTile<String?>(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Sin especificar'),
                      value: null,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || value == profile.sex) return;
    await profileRepository.setSex(value);
  }

  /// Altura en cm para la estimación US Navy (spec 009, RF-4). Opcional.
  Future<void> _pickHeight() async {
    final profile = await profileRepository.current();
    if (!mounted) return;
    final units = UnitSystemScope.of(context);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _HeightDialog(
        initial: profile.heightCm == null
            ? ''
            : _fmtMeasure(displayLengthCm(profile.heightCm!, units)),
        unitLabel: lengthUnitOf(units),
      ),
    );
    if (result == null) return;
    final text = result.trim();
    if (text.isEmpty) {
      await profileRepository.setHeightCm(null);
      return;
    }
    final parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pon una altura válida')),
      );
      return;
    }
    await profileRepository.setHeightCm(toCm(parsed, units));
  }

  Future<void> _pickAvatar() async {
    final service = authService;
    if (service == null || !service.hasSession) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para subir tu foto')),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: kSurfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: kSurfaceContainerHighest),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: kOnSurface),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: kOnSurface),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    try {
      final bytes = await File(file.path).readAsBytes();
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final path = 'avatars/$userId.jpg';
      await Supabase.instance.client.storage.from(_avatarBucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      final url = Supabase.instance.client.storage
          .from(_avatarBucket)
          .getPublicUrl(path);
      await profileRepository.setAvatarUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo subir la foto')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Header(
          profile: _profile,
          stats: _stats,
          onEditName: _editName,
          onPickAvatar: _pickAvatar,
        ),
        const SectionHeader(title: 'Tus métricas'),
        _Metrics(profile: _profile, stats: _stats),
        const SectionHeader(title: 'Objetivos'),
        _Goals(goals: _goals),
        const SectionHeader(title: 'Récords personales'),
        _Records(profile: _profile, stats: _stats),
        const SectionHeader(title: 'Configuración de Atleta'),
        _Settings(
          profile: _profile,
          onExport: _export,
          onSignOut: _signOut,
          onSignIn: _signInWithEmail,
          onPickRirPreference: _pickRirPreference,
          onPickUnits: _pickUnits,
          onPickSex: _pickSex,
          onPickHeight: _pickHeight,
          onOpenDevices: _openDevices,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Stream<LocalProfile> profile;
  final Stream<ProfileStats> stats;
  final Future<void> Function(String?) onEditName;
  final Future<void> Function() onPickAvatar;

  const _Header({
    required this.profile,
    required this.stats,
    required this.onEditName,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<LocalProfile>(
      stream: profile,
      builder: (context, snapshot) {
        final displayName = snapshot.data?.displayName;
        final avatarUrl = snapshot.data?.avatarUrl;
        return StreamBuilder<ProfileStats>(
          stream: stats,
          builder: (context, statsSnapshot) {
            final level =
                athleteLevel(statsSnapshot.data?.finishedSessions ?? 0);
            return Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Cambiar foto de perfil',
                  child: GestureDetector(
                    onTap: onPickAvatar,
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: kSurfaceContainerHigh,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 32)
                          : ClipOval(
                              child: Image.network(
                                avatarUrl,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) =>
                                    progress == null
                                        ? child
                                        : const Icon(Icons.person, size: 32),
                                errorBuilder: (context, error, stack) =>
                                    const Icon(Icons.person, size: 32),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () => onEditName(displayName),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName ?? 'Atleta',
                                style: textTheme.headlineSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.edit,
                              size: 16,
                              color: kOnSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kSurfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: 12,
                              color: kTertiaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Nivel $level',
                                style: textTheme.labelSmall
                                    ?.copyWith(color: kTertiaryContainer),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _Metrics extends StatelessWidget {
  final Stream<LocalProfile> profile;
  final Stream<ProfileStats> stats;

  const _Metrics({required this.profile, required this.stats});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProfileStats>(
      stream: stats,
      builder: (context, statsSnapshot) {
        final data = statsSnapshot.data ?? ProfileStats.empty;
        return StreamBuilder<LocalProfile>(
          stream: profile,
          builder: (context, profileSnapshot) {
            final unitSystem = profileSnapshot.data?.unitSystem ?? 'metric';
            final unit = unitSystem == 'imperial' ? 'lb' : 'kg';
            final factor = unitSystem == 'imperial' ? 2.2046226218 : 1.0;
            return MetricCluster(
              metrics: [
                (
                  label: 'Sesiones',
                  value: '${data.finishedSessions}',
                ),
                (
                  label: 'Volumen total',
                  value:
                      '${_formatThousands(data.totalVolumeKg * factor)} $unit',
                ),
                (
                  label: 'Racha',
                  value: '${data.weekStreak} sem',
                ),
              ],
            );
          },
        );
      },
    );
  }
}

String _formatThousands(double value) {
  final text = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) buffer.write('.');
    buffer.write(text[i]);
  }
  return buffer.toString();
}

class _Goals extends StatelessWidget {
  final Stream<List<Goal>> goals;

  const _Goals({required this.goals});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<List<Goal>>(
      stream: goals,
      builder: (context, snapshot) {
        final active = (snapshot.data ?? const <Goal>[])
            .where((goal) => goal.status == 'active')
            .toList();
        if (active.isEmpty) {
          return const _EmptyHint('Aún no tienes objetivos activos.');
        }
        return CappedScroll(
          itemCount: active.length,
          visibleItems: _visibleGoalTiles,
          itemHeight: _goalTileHeight,
          child: Column(
            children: [
              for (final goal in active)
                _GoalTile(goal: goal, textTheme: textTheme),
            ],
          ),
        );
      },
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Goal goal;
  final TextTheme textTheme;

  const _GoalTile({required this.goal, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final progress = goalProgress(
      type: goal.type,
      currentValue: goal.currentValue,
      targetValue: goal.targetValue,
      startValue: goal.baselineValue,
    );
    final label = _goalTypeLabels[goal.type] ?? goal.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: textTheme.bodyLarge),
              Text(
                '${(progress * 100).round()} %',
                style: textTheme.labelMedium
                    ?.copyWith(color: kOnSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: kSurfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Records extends StatefulWidget {
  final Stream<LocalProfile> profile;
  final Stream<ProfileStats> stats;

  const _Records({required this.profile, required this.stats});

  @override
  State<_Records> createState() => _RecordsState();
}

class _RecordsState extends State<_Records> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: false, label: Text('Este mes')),
            ButtonSegment(value: true, label: Text('Histórico')),
          ],
          selected: {_showHistory},
          onSelectionChanged: (selection) =>
              setState(() => _showHistory = selection.first),
        ),
        const SizedBox(height: 12),
        StreamBuilder<ProfileStats>(
          stream: widget.stats,
          builder: (context, snapshot) {
            final allRecords =
                snapshot.data?.records ?? const <PersonalRecord>[];
            final records = _showHistory
                ? allRecords
                : allRecords
                    .where((r) => isWithinMonth(r.achievedAt, DateTime.now()))
                    .toList();
            if (records.isEmpty) {
              return _EmptyHint(
                _showHistory
                    ? 'Termina series para ver tus mejores marcas.'
                    : 'Sin récords este mes. Termina series para ver tus mejores marcas.',
              );
            }
            return StreamBuilder<LocalProfile>(
              stream: widget.profile,
              builder: (context, profileSnapshot) {
                final unitSystem =
                    profileSnapshot.data?.unitSystem ?? 'metric';
                final factor = unitSystem == 'imperial' ? 2.2046226218 : 1.0;
                final unit = unitSystem == 'imperial' ? 'lb' : 'kg';
                return Column(
                  children: [
                    for (final record in records.take(5))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_outlined,
                              size: 20,
                              color: kOliveAccent,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                record.exerciseName,
                                style: textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${_formatThousands(record.weightKg * factor)} $unit'
                              ' × ${record.reps}',
                              style: textTheme.labelMedium
                                  ?.copyWith(color: kOnSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _EmailSignInDialog extends StatefulWidget {
  final AuthService service;

  const _EmailSignInDialog({required this.service});

  @override
  State<_EmailSignInDialog> createState() => _EmailSignInDialogState();
}

class _EmailSignInDialogState extends State<_EmailSignInDialog> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _loading = false;
  bool _createAccount = false;
  String _errorText = '';

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Escribe tu correo y tu contraseña.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _errorText = '';
    });
    String? outcome;
    try {
      if (_createAccount) {
        final response = await widget.service.signUpWithEmail(
          email: email,
          password: password,
        );
        outcome = response.session != null ? 'signedIn' : 'created';
      } else {
        await widget.service.signInWithEmail(
          email: email,
          password: password,
        );
        outcome = 'signedIn';
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorText =
            e is AuthException ? e.message : AuthService.authErrorMessage(e);
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(_createAccount ? 'Crear cuenta' : 'Iniciar sesión'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          if (_errorText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _errorText,
              style: textTheme.bodySmall?.copyWith(color: kError),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading
              ? null
              : () => setState(() {
                    _createAccount = !_createAccount;
                    _errorText = '';
                  }),
          child: Text(_createAccount ? 'Ya tengo cuenta' : 'Crear cuenta'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_createAccount ? 'Crear' : 'Entrar'),
        ),
      ],
    );
  }
}

class _Settings extends StatelessWidget {
  final Stream<LocalProfile> profile;
  final Future<void> Function() onExport;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onSignIn;
  final Future<void> Function(bool) onPickRirPreference;
  final VoidCallback onPickUnits;
  final VoidCallback onPickSex;
  final VoidCallback onPickHeight;
  final VoidCallback onOpenDevices;

  const _Settings({
    required this.profile,
    required this.onExport,
    required this.onSignOut,
    required this.onSignIn,
    required this.onPickRirPreference,
    required this.onPickUnits,
    required this.onPickSex,
    required this.onPickHeight,
    required this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<LocalProfile>(
      stream: profile,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final unitSystem = data?.unitSystem ?? 'metric';
        final preferRpe = data?.preferRpe ?? false;
        final sex = data?.sex;
        final heightCm = data?.heightCm;
        final sexLabel = switch (sex) {
          kSexMale => 'Hombre',
          kSexFemale => 'Mujer',
          _ => 'Sin especificar',
        };
        final heightLabel = heightCm == null
            ? 'Sin especificar'
            : '${_fmtMeasure(displayLengthCm(heightCm, unitSystem))} '
                '${lengthUnitOf(unitSystem)}';
        final service = authService;
        final signedIn = service?.hasSession ?? false;
        final canSignIn = service != null && !signedIn;
        final unitLabel = unitSystem == 'imperial'
            ? 'Imperial (lb / in)'
            : 'Métrico (kg / cm)';
        return Column(
          children: [
            _SettingsRow(
              icon: Icons.straighten,
              title: 'Unidades de medida',
              subtitle: unitLabel,
              onTap: onPickUnits,
            ),
            _SettingsRow(
              icon: Icons.wc,
              title: 'Sexo',
              subtitle: sexLabel,
              onTap: onPickSex,
            ),
            _SettingsRow(
              icon: Icons.height,
              title: 'Altura',
              subtitle: heightLabel,
              onTap: onPickHeight,
            ),
            _SettingsRow(
              icon: Icons.tune,
              title: 'Ajustes de RIR y RPE',
              subtitle: preferRpe
                  ? 'Esfuerzo percibido (RPE) activo'
                  : 'Cálculo automático de 1RM activo',
              onTap: () => onPickRirPreference(preferRpe),
            ),
            _SettingsRow(
              icon: Icons.download,
              title: 'Exportar datos',
              subtitle: 'CSV / Copia de seguridad completa',
              onTap: onExport,
            ),
            _SettingsRow(
              icon: Icons.bluetooth,
              title: 'Dispositivos',
              subtitle: 'Báscula, caliper y frecuencia cardiaca',
              trailing: const Icon(
                Icons.chevron_right,
                size: 20,
                color: kOnSurfaceVariant,
              ),
              onTap: onOpenDevices,
            ),
            _SettingsRow(
              icon: signedIn ? Icons.logout : Icons.login,
              iconColor: signedIn ? kError : kOnSurfaceVariant,
              title: signedIn
                  ? 'Cerrar sesión'
                  : canSignIn
                      ? 'Iniciar sesión'
                      : 'Sincronización sin configurar',
              subtitle: signedIn
                  ? 'Dejar de sincronizar en este dispositivo'
                  : canSignIn
                      ? 'Correo y contraseña para sincronizar'
                      : 'La app funciona en local, sin cuenta',
              enabled: signedIn || canSignIn,
              onTap: signedIn
                  ? () => onSignOut()
                  : canSignIn
                      ? () => onSignIn()
                      : null,
            ),
            if (!signedIn && !canSignIn)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 56),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Falta la configuración de Supabase: arranca la app '
                    'con tool/run.sh para poder iniciar sesión.',
                    style: textTheme.labelMedium
                        ?.copyWith(color: kOnSurfaceVariant),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Fila navegable de la sección «Configuración de Atleta» (mockup Perfil):
/// círculo con icono + título/subtítulo + chevron. Sin sombras (§7).
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: kSurfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: iconColor ?? kSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: enabled ? kPrimary : kOnSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: textTheme.labelSmall
                        ?.copyWith(color: kOnSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: kOnSurfaceVariant,
                ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;

  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: kOnSurfaceVariant),
      ),
    );
  }
}

/// Diálogo de altura con su propio controlador (se libera al desmontar la
/// ruta, no antes de que termine la animación de salida).
class _HeightDialog extends StatefulWidget {
  const _HeightDialog({required this.initial, required this.unitLabel});

  final String initial;
  final String unitLabel;

  @override
  State<_HeightDialog> createState() => _HeightDialogState();
}

class _HeightDialogState extends State<_HeightDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Altura'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Altura (${widget.unitLabel})',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
