import 'package:flutter/material.dart';

import '../../data/repositories/catalog_repository.dart';
import '../../domain/exercise_filter.dart';
import '../theme/colors.dart';

/// Etiqueta legible de una dimensión de filtro (RF-1 de la 003).
String exerciseDimensionLabel(ExerciseDimension dimension) =>
    switch (dimension) {
      ExerciseDimension.bodyPart => 'Cuerpo',
      ExerciseDimension.equipment => 'Equipo',
      ExerciseDimension.target => 'Objetivo',
      ExerciseDimension.muscleGroup => 'Músculo',
      ExerciseDimension.secondaryMuscle => 'Secundarios',
    };

/// Opción de una dimensión: la etiqueta visible y los valores crudos del
/// dataset que abarca. Los sinónimos musculares (`lats` / `latissimus dorsi`)
/// comparten etiqueta, así que una opción puede envolver varios valores.
typedef DimensionOption = ({String label, Set<String> values});

/// Etiqueta en español de un valor de filtro muscular. Los sinónimos del
/// dataset (`lats`/`latissimus dorsi`, `groin`/`inner thighs`…) comparten
/// etiqueta para que cada músculo aparezca una sola vez en el filtro (§9).
String muscleFilterLabel(String value) =>
    _muscleFilterLabels[_normalizeMuscleKey(value)] ?? value;

String _normalizeMuscleKey(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z]'), '');

/// Vocabulario muscular del catálogo (`target`, `muscle_group` y
/// `secondary_muscles`) traducido y con sinónimos fusionados.
const Map<String, String> _muscleFilterLabels = {
  'abductors': 'Abductores',
  'adductors': 'Aductores',
  'abs': 'Abdominales',
  'abdominals': 'Abdominales',
  'anklestabilizers': 'Estabilizadores de tobillo',
  'ankles': 'Tobillos',
  'back': 'Espalda',
  'biceps': 'Bíceps',
  'brachialis': 'Braquial',
  'calves': 'Gemelos',
  'cardiovascularsystem': 'Cardio',
  'chest': 'Pecho',
  'core': 'Core',
  'delts': 'Hombros',
  'deltoids': 'Hombros',
  'reardeltoids': 'Hombros',
  'shoulders': 'Hombros',
  'feet': 'Pies',
  'forearms': 'Antebrazos',
  'glutes': 'Glúteos',
  'gripmuscles': 'Músculos del agarre',
  'groin': 'Aductores',
  'innerthighs': 'Aductores',
  'hamstrings': 'Isquios',
  'hands': 'Manos',
  'hipflexors': 'Flexores de cadera',
  'latissimusdorsi': 'Dorsales',
  'lats': 'Dorsales',
  'levatorscapulae': 'Escápula',
  'lowerabs': 'Abdominales bajas',
  'lowerback': 'Lumbar',
  'obliques': 'Oblicuos',
  'pectorals': 'Pecho',
  'quadriceps': 'Cuádriceps',
  'quads': 'Cuádriceps',
  'rhomboids': 'Romboides',
  'rotatorcuff': 'Manguito rotador',
  'serratusanterior': 'Serrato',
  'shins': 'Canillas',
  'soleus': 'Sóleo',
  'spine': 'Columna',
  'sternocleidomastoid': 'Esternocleidomastoideo',
  'trapezius': 'Trapecio',
  'traps': 'Trapecio',
  'triceps': 'Tríceps',
  'upperback': 'Espalda alta',
  'upperchest': 'Pecho superior',
  'wristextensors': 'Extensores de muñeca',
  'wristflexors': 'Flexores de muñeca',
  'wrists': 'Muñecas',
};

/// Opciones de una dimensión (RF-1 de la 003), traducidas al español y con
/// los sinónimos musculares fusionados en una sola entrada. Las dimensiones
/// no musculares (cuerpo, equipo) pasan sus valores tal cual.
List<DimensionOption> exerciseDimensionOptions(
  ExerciseDimension dimension,
  FilterOptions options,
) =>
    switch (dimension) {
      ExerciseDimension.bodyPart =>
        [for (final v in options.bodyParts) (label: v, values: {v})],
      ExerciseDimension.equipment =>
        [for (final v in options.equipments) (label: v, values: {v})],
      ExerciseDimension.target => _mergedMuscleOptions(options.targets),
      ExerciseDimension.muscleGroup => _mergedMuscleOptions(options.muscleGroups),
      ExerciseDimension.secondaryMuscle =>
        _mergedMuscleOptions(options.secondaryMuscles),
    };

/// Agrupa los valores musculares por etiqueta en español —los sinónimos
/// acaban en la misma entrada— y las ordena alfabéticamente por etiqueta.
List<DimensionOption> _mergedMuscleOptions(List<String> values) {
  final byLabel = <String, Set<String>>{};
  for (final value in values) {
    byLabel.putIfAbsent(muscleFilterLabel(value), () => <String>{}).add(value);
  }
  final labels = byLabel.keys.toList()..sort();
  return [for (final label in labels) (label: label, values: byLabel[label]!)];
}

/// Barra de filtros por dimensión compartida por el catálogo y el selector de
/// ejercicios (RF-1 de la 003). El padre es dueño del estado del filtro.
class ExerciseFilterBar extends StatelessWidget {
  final ExerciseFilter filter;
  final FilterOptions options;
  final ValueChanged<ExerciseFilter> onChanged;

  const ExerciseFilterBar({
    super.key,
    required this.filter,
    required this.options,
    required this.onChanged,
  });

  Future<void> _editDimension(
    BuildContext context,
    ExerciseDimension dimension,
  ) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (sheetContext) => _DimensionSheet(
        title: exerciseDimensionLabel(dimension),
        options: exerciseDimensionOptions(dimension, options),
        selected: filter.valuesOf(dimension),
      ),
    );
    if (result == null) return;
    onChanged(filter.withDimension(dimension, result));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final dimension in ExerciseDimension.values)
            _filterPill(
              label: exerciseDimensionLabel(dimension),
              selected: filter.valuesOf(dimension).length,
              onTap: () => _editDimension(context, dimension),
            ),
        ],
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required int selected,
    required VoidCallback onTap,
  }) {
    final active = selected > 0;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? kSurfaceContainerHigh : kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Text(
              active ? '$label ($selected)' : label,
              style: TextStyle(
                color: active ? kOnSurface : kOnSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DimensionSheet extends StatefulWidget {
  const _DimensionSheet({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final List<DimensionOption> options;
  final Set<String> selected;

  @override
  State<_DimensionSheet> createState() => _DimensionSheetState();
}

class _DimensionSheetState extends State<_DimensionSheet> {
  late final Set<String> _selected = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: kOnSurfaceVariant),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.options.length,
                itemBuilder: (context, index) {
                  final option = widget.options[index];
                  final checked = option.values.any(_selected.contains);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (on) => setState(() {
                      if (on ?? false) {
                        _selected.addAll(option.values);
                      } else {
                        _selected.removeAll(option.values);
                      }
                    }),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 14,
                        color: kOnSurface,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(_selected.clear),
                    child: const Text('Limpiar'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Listo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
