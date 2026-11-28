import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/palette.dart' as palette;
import '../../data/local/database.dart';
import '../../data/repositories/custom_exercise_repository.dart';
import '../../domain/custom_exercise.dart';
import '../../domain/custom_exercise_image.dart';
import '../widgets/exercise_thumb.dart';

typedef CustomExerciseImagePicker = Future<XFile?> Function(ImageSource source);

class CustomExerciseEditorView extends StatefulWidget {
  final CustomExerciseRepository repository;
  final Exercise? exercise;
  final CustomExerciseImagePicker? pickImage;

  const CustomExerciseEditorView({
    super.key,
    required this.repository,
    this.exercise,
    this.pickImage,
  });

  @override
  State<CustomExerciseEditorView> createState() =>
      _CustomExerciseEditorViewState();
}

class _CustomExerciseEditorViewState extends State<CustomExerciseEditorView> {
  final _nameController = TextEditingController();
  final _bodyPartController = TextEditingController();
  final _equipmentController = TextEditingController();
  final _restController = TextEditingController(text: '90');
  final _secondaryMuscles = <String>[];

  String? _target;
  String? _currentImagePath;
  Uint8List? _newImageBytes;
  bool _removeImage = false;
  bool _loadingImage = false;
  bool _saving = false;
  String? _imageError;
  String? _saveError;
  String? _nameError;
  String? _bodyPartError;
  String? _equipmentError;
  String? _targetError;
  String? _secondaryError;
  String? _restError;

  bool get _editing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    final exercise = widget.exercise;
    if (exercise == null) return;
    _nameController.text = exercise.name;
    _bodyPartController.text = exercise.bodyPart;
    _equipmentController.text = exercise.equipment;
    _restController.text = exercise.restSeconds.toString();
    _target = exercise.target;
    _currentImagePath = exercise.imagePath;
    final secondary = exercise.secondaryMuscles;
    if (secondary != null && secondary.isNotEmpty) {
      _secondaryMuscles.addAll(
        (jsonDecode(secondary) as List<dynamic>).cast<String>(),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bodyPartController.dispose();
    _equipmentController.dispose();
    _restController.dispose();
    super.dispose();
  }

  Future<void> _chooseImage(ImageSource source) async {
    if (_loadingImage) return;
    setState(() {
      _loadingImage = true;
      _imageError = null;
    });
    try {
      final picker =
          widget.pickImage ??
          (source) => ImagePicker().pickImage(
            source: source,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 85,
          );
      final file = await picker(source);
      if (file == null) {
        if (mounted) setState(() => _loadingImage = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final valid = await validateCustomImageBytes(bytes);
      if (!mounted) return;
      setState(() {
        _newImageBytes = valid.bytes;
        _removeImage = false;
        _loadingImage = false;
      });
    } on CustomImageValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        _imageError = error.message;
        _loadingImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _imageError = 'No se pudo acceder a la imagen. Revisa el permiso e inténtalo de nuevo';
        _loadingImage = false;
      });
    }
  }

  void _removeCurrentImage() {
    setState(() {
      _newImageBytes = null;
      _removeImage = true;
      _imageError = null;
    });
  }

  bool _validateFields() {
    final rest = int.tryParse(_restController.text.trim());
    setState(() {
      _nameError = _nameController.text.trim().isEmpty
          ? 'Escribe el nombre del ejercicio'
          : null;
      _bodyPartError = _bodyPartController.text.trim().isEmpty
          ? 'Escribe la parte del cuerpo'
          : null;
      _equipmentError = _equipmentController.text.trim().isEmpty
          ? 'Escribe el equipo'
          : null;
      _targetError = _target == null ? 'Selecciona el músculo objetivo' : null;
      _secondaryError = null;
      _restError = rest == null || rest < 15 || rest > 300
          ? 'Usa un descanso entre 15 y 300 segundos'
          : null;
      _saveError = null;
    });
    return _nameError == null &&
        _bodyPartError == null &&
        _equipmentError == null &&
        _targetError == null &&
        _restError == null;
  }

  Future<void> _save() async {
    if (_saving || !_validateFields()) return;
    final draft = CustomExerciseDraft(
      name: _nameController.text,
      bodyPart: _bodyPartController.text,
      equipment: _equipmentController.text,
      target: _target!,
      secondaryMuscles: List.unmodifiable(_secondaryMuscles),
      restSeconds: int.parse(_restController.text.trim()),
    );
    setState(() => _saving = true);
    try {
      final exercise = widget.exercise;
      final saved = exercise == null
          ? await widget.repository.createCustomExercise(
              draft: draft,
              imageBytes: _newImageBytes,
            )
          : await widget.repository.updateCustomExercise(
              id: exercise.id,
              draft: draft,
              imageBytes: _newImageBytes,
              removeImage: _removeImage,
            );
      if (!mounted) return;
      Navigator.pop(context, saved);
    } on CustomExerciseValidationException catch (error) {
      if (!mounted) return;
      setState(() {
        if (error.message == 'Selecciona un músculo objetivo conocido') {
          _targetError = error.message;
          _saveError = null;
        } else if (error.message ==
                'Selecciona músculos secundarios conocidos' ||
            error.message ==
                'No repitas el objetivo ni los músculos secundarios') {
          _secondaryError = error.message;
          _saveError = null;
        } else {
          _saveError = error.message;
        }
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'No se pudo guardar. Inténtalo de nuevo';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.kSurface,
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        ),
        title: Text(_editing ? 'Editar ejercicio' : 'Crear ejercicio'),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageSection(),
                  const SizedBox(height: 8),
                  Text(
                    'Se sincronizará cuando haya conexión',
                    key: const Key('custom-pending-notice'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    key: const Key('custom-name'),
                    controller: _nameController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      errorText: _nameError,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    key: const Key('custom-target'),
                    initialValue: _target,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Objetivo',
                      errorText: _targetError,
                    ),
                    items: [
                      for (final target in customExerciseTargets)
                        DropdownMenuItem(value: target, child: Text(target)),
                    ],
                    onChanged: (value) => setState(() {
                      _target = value;
                      _targetError = null;
                    }),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Secundarios (opcional)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final muscle in customExerciseSecondaryMuscles)
                        FilterChip(
                          key: Key('custom-secondary-$muscle'),
                          label: Text(muscle.replaceAll(' ', '\u00a0')),
                          selected: _secondaryMuscles.contains(muscle),
                          showCheckmark: false,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _secondaryMuscles.add(muscle);
                            } else {
                              _secondaryMuscles.remove(muscle);
                            }
                            _secondaryError = null;
                            _saveError = null;
                          }),
                        ),
                    ],
                  ),
                  if (_secondaryError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _secondaryError!,
                        key: const Key('custom-secondary-error'),
                        style: const TextStyle(color: palette.kError),
                      ),
                    ),
                  const SizedBox(height: 20),
                  _buildSuggestionField(
                    fieldKey: const Key('custom-body-part'),
                    controller: _bodyPartController,
                    label: 'Parte del cuerpo',
                    errorText: _bodyPartError,
                    suggestions: const [
                      'back',
                      'cardio',
                      'chest',
                      'lower arms',
                      'lower legs',
                      'neck',
                      'shoulders',
                      'upper arms',
                      'upper legs',
                      'waist',
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSuggestionField(
                    fieldKey: const Key('custom-equipment'),
                    controller: _equipmentController,
                    label: 'Equipo',
                    errorText: _equipmentError,
                    suggestions: const [
                      'assisted',
                      'band',
                      'barbell',
                      'body weight',
                      'bosu ball',
                      'cable',
                      'dumbbell',
                      'elliptical machine',
                      'ez barbell',
                      'hammer',
                      'kettlebell',
                      'leverage machine',
                      'medicine ball',
                      'olympic barbell',
                      'resistance band',
                      'roller',
                      'rope',
                      'skierg machine',
                      'sled machine',
                      'smith machine',
                      'stability ball',
                      'stationary bike',
                      'stepmill machine',
                      'tire',
                      'trap bar',
                      'upper body ergometer',
                      'weighted',
                      'wheel roller',
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const Key('custom-rest'),
                    controller: _restController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Descanso inicial (segundos)',
                      hintText: '90',
                      errorText: _restError,
                    ),
                  ),
                  if (_saveError != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _saveError!,
                      key: const Key('custom-save-error'),
                      style: const TextStyle(color: palette.kError),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('custom-save'),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(_editing ? 'Guardar cambios' : 'Guardar ejercicio'),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionField({
    required Key fieldKey,
    required TextEditingController controller,
    required String label,
    required String? errorText,
    required List<String> suggestions,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            decoration: InputDecoration(labelText: label, errorText: errorText),
          ),
        ),
        const SizedBox(width: 4),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: PopupMenuButton<String>(
            tooltip: 'Sugerencias de $label',
            constraints: const BoxConstraints(maxHeight: 320),
            onSelected: (value) => setState(() => controller.text = value),
            itemBuilder: (_) => [
              for (final suggestion in suggestions)
                PopupMenuItem(value: suggestion, child: Text(suggestion)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    final hasImage =
        _newImageBytes != null || (!_removeImage && _currentImagePath != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: palette.kSurfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.kTonalBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImagePreview(),
                if (_loadingImage)
                  const ColoredBox(
                    color: Color(0x66121316),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('custom-image-gallery'),
                onPressed: () => _chooseImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                key: const Key('custom-image-camera'),
                onPressed: () => _chooseImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Cámara'),
              ),
            ),
            if (hasImage)
              SizedBox(
                height: 44,
                child: TextButton.icon(
                  key: const Key('custom-image-remove'),
                  onPressed: _removeCurrentImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Quitar imagen'),
                ),
              ),
          ],
        ),
        if (_imageError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _imageError!,
              key: const Key('custom-image-error'),
              style: const TextStyle(color: palette.kError),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePreview() {
    final bytes = _newImageBytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ThumbFallback(radius: 16),
      );
    }
    final path = _currentImagePath;
    if (!_removeImage && path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const ThumbFallback(radius: 16),
      );
    }
    return const ThumbFallback(radius: 16);
  }
}
