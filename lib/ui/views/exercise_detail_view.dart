/// Esta vista ha sido sustituida por ExerciseInfoView (spec 015).
/// No elimino el archivo para preservar historial, pero su contenido
/// está en reposo. Usa ExerciseInfoView en su lugar.
import 'package:flutter/material.dart';

class ExerciseDetailView extends StatefulWidget {
  const ExerciseDetailView({super.key});
  @override  State<ExerciseDetailView> createState() =>
      _ExerciseDetailViewState();
}

class _ExerciseDetailViewState extends State<ExerciseDetailView> {
  @override  Widget build(BuildContext context) => const Center(
    child: Text('Vista sustituida por ExerciseInfoView'),
  );
}
