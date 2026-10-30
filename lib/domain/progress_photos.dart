/// Vistas de las fotos de progreso (spec 009, RF-8): frente, perfil y
/// espalda. Etiquetas en español; el código usa los ids en inglés.
const List<String> kPhotoViews = ['front', 'side', 'back'];

/// Etiqueta visible de cada vista («Frente», «Perfil», «Espalda»).
String photoViewLabel(String view) => switch (view) {
      'front' => 'Frente',
      'side' => 'Perfil',
      'back' => 'Espalda',
      _ => view,
    };

/// ¿Es una vista válida de foto?
bool isPhotoView(String view) => kPhotoViews.contains(view);
