import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/local/database.dart';
import '../../domain/media.dart';
import '../../main.dart';
import '../theme/colors.dart';
import '../widgets/exercise_thumb.dart';

class ExerciseDetailView extends StatefulWidget {
  final Exercise exercise;

  const ExerciseDetailView({super.key, required this.exercise});

  @override
  State<ExerciseDetailView> createState() => _ExerciseDetailViewState();
}

class _ExerciseDetailViewState extends State<ExerciseDetailView> {
  Map<String, List<String>> _steps = const {};
  String _language = 'es';
  late int _restSeconds = widget.exercise.restSeconds;

  /// GIF servido desde la caché con nombre; `null` si no hay URL (sin
  /// credenciales la ficha muestra la miniatura local, RF-3).
  Future<File?>? _gifFile;

  Future<void> _changeRest(int deltaSeconds) async {
    final next = (_restSeconds + deltaSeconds).clamp(15, 300);
    setState(() => _restSeconds = next);
    await catalogRepository.updateRestSeconds(widget.exercise.id, next);
  }

  @override
  void initState() {
    super.initState();
    _loadSteps();
    final gifPath = widget.exercise.gifPath;
    if (gifPath != null && gifUrl(gifPath) != null) {
      _gifFile = gifCache.ensureCached(
        exerciseId: widget.exercise.id,
        gifPath: gifPath,
      );
    }
  }

  Future<void> _loadSteps() async {
    final rows = await (localDb.select(localDb.exerciseInstructions)
          ..where((t) => t.exerciseId.equals(widget.exercise.id)))
        .get();

    final grouped = <String, List<ExerciseInstruction>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.language, () => []).add(row);
    }

    final steps = <String, List<String>>{};
    grouped.forEach((language, list) {
      list.sort((a, b) => a.stepNumber.compareTo(b.stepNumber));
      steps[language] = [for (final step in list) step.instruction];
    });

    if (!mounted) return;
    setState(() {
      _steps = steps;
      if (!steps.containsKey(_language) && steps.isNotEmpty) {
        _language = steps.keys.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final steps = _steps[_language] ?? const <String>[];

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kOnSurface),
        title: Text(
          exercise.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: kOnSurface,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildMedia(exercise),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(exercise.muscleGroup),
              _badge(exercise.equipment),
              _badge(exercise.bodyPart),
            ],
          ),
          if (_steps.length > 1) ...[
            const SizedBox(height: 20),
            _buildLanguageSwitch(),
          ],
          const SizedBox(height: 16),
          _buildRestSetting(),
          const SizedBox(height: 16),
          if (steps.isEmpty)
            const Text(
              'Sin instrucciones disponibles',
              style: TextStyle(fontSize: 14, color: kOnSurfaceVariant),
            )
          else
            for (var i = 0; i < steps.length; i++) _buildStep(i + 1, steps[i]),
          if (exercise.attribution != null) ...[
            const SizedBox(height: 8),
            Text(
              exercise.attribution!,
              style: const TextStyle(fontSize: 10, color: kOutline),
            ),
          ],
        ],
      ),
    );
  }

  /// Ajuste del descanso por defecto del ejercicio, 15–300 s (RF-5 de la 002).
  Widget _buildRestSetting() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: const BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, size: 18, color: kOnSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Descanso por defecto',
              style: theme.textTheme.bodyLarge?.copyWith(color: kOnSurface),
            ),
          ),
          Text(
            '$_restSeconds s',
            style: theme.textTheme.titleMedium?.copyWith(
              color: kPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          IconButton(
            key: const Key('rest-detail-minus'),
            tooltip: 'Reducir 15 s',
            onPressed: _restSeconds > 15 ? () => _changeRest(-15) : null,
            icon: const Icon(Icons.remove_rounded, color: kOnSurfaceVariant),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              backgroundColor: kSurfaceContainerHighest,
              shape: const StadiumBorder(),
            ),
          ),
          IconButton(
            key: const Key('rest-detail-plus'),
            tooltip: 'Aumentar 15 s',
            onPressed: _restSeconds < 300 ? () => _changeRest(15) : null,
            icon: const Icon(Icons.add_rounded, color: kOnSurfaceVariant),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            style: IconButton.styleFrom(
              backgroundColor: kSurfaceContainerHighest,
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedia(Exercise exercise) {
    final local = _localMedia(exercise);
    final gif = gifUrl(exercise.gifPath ?? '');

    return Container(
      height: 220,
      decoration: const BoxDecoration(
        color: kSurfaceContainer,
        borderRadius: BorderRadius.all(Radius.circular(12)),
        border: Border.fromBorderSide(BorderSide(color: kSurfaceContainerHighest)),
      ),
      clipBehavior: Clip.antiAlias,
      child: gif == null
          ? local
          : FutureBuilder<File?>(
              future: _gifFile,
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file != null) {
                  return Image.file(file, fit: BoxFit.contain);
                }
                // Descargando o sin red: la miniatura local (RF-3).
                return local;
              },
            ),
    );
  }

  Widget _localMedia(Exercise exercise) {
    final imagePath = exercise.imagePath;
    if (imagePath == null) return const ThumbFallback(radius: 16);
    return Image.asset(
      thumbAsset(imagePath),
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const ThumbFallback(radius: 16),
    );
  }

  Widget _buildLanguageSwitch() {
    final languages = _steps.keys.toList()..sort();
    return Wrap(
      spacing: 8,
      children: [
        for (final language in languages)
          ChoiceChip(
            label: Text(language.toUpperCase()),
            selected: language == _language,
            onSelected: (_) => setState(() => _language = language),
            showCheckmark: false,
            selectedColor: kSurfaceContainerHighest,
            backgroundColor: kSurfaceContainerLow,
            side: const BorderSide(color: kSurfaceContainerHighest),
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: language == _language ? kPrimary : kOnSurfaceVariant,
            ),
          ),
      ],
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: const BoxDecoration(
        color: kSurfaceContainerHighest,
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: kOnSurface,
        ),
      ),
    );
  }

  Widget _buildStep(int index, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text(
              index.toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kOutline,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: kOnSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
