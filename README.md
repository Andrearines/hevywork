# hevywork 1.0.0


App de entrenamiento en Flutter: rutinas, registro de sesiones, objetivos,
medidas corporales, mapa muscular de fatiga y catálogo de ejercicios con
miniaturas locales y GIFs servidos desde Supabase Storage.

## Ejecución

La app funciona en local sin credenciales, pero los GIFs del catálogo y algunas
funciones avanzadas necesitan la URL y la clave publicable de Supabase. Con el
`.env` relleno:

```bash
./tool/run.sh              # flutter run con las credenciales públicas
./tool/run.sh -d <device>  # argumentos extra para flutter run
```

O a mano, sin exponer la clave secreta:

```bash
flutter run \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="$SUPABASE_PUBLISHABLE_KEY"
```

### Para que otros usuarios puedan conectar su propio Supabase

Esta app está diseñada para ser multipl-arrendatario. Cada usuario puede
conectarla con su propio proyecto Supabase siguiendo estos pasos:

1. **Crea un proyecto Supabase** en https://supabase.com/dashboard
2. **Configura el almacenamiento** (Storage):
   - Crea un bucket público llamado `exercise-media`
   - Configura las políticas de acceso público para que cualquiera pueda
     leer los GIFs (esto es necesario para que el catálogo funcione):
     ```sql
     CREATE BUCKET exercise-media WITH (public = true);
     -- O si ya existe:
     UPDATE bucket exercise-media SET public = true;
     ```

3. **Configura RLS (Row Level Security)** para las tablas de la base de datos:
   La app usa `local_user_id` para isolar los datos de cada usuario. Ejecuta
   estas migraciones o políticas manualmente en el SQL editor de Supabase:

   ```sql
   -- Política para que los usuarios puedan ver sus propios ejercicios
   CREATE POLICY "Usuarios pueden ver sus own ejercicios" ON exercises
     FOR SELECT USING (auth.uid()::text = local_user_id::text);

   -- Política para que los usuarios inserten sus propios ejercicios
   CREATE POLICY "Usuarios pueden insertar sus propios ejercicios" ON exercises
     WITH CHECK (auth.uid()::text = local_user_id::text);
   ```

4. **Obtén tus credenciales**:
   - Ve a Configuración > API en tu panel de Supabase
   - Copia la **Project URL** → `SUPABASE_URL`
   - Copia la **anon/public key** → `SUPABASE_PUBLISHABLE_KEY`

5. **Crea tu archivo `.env`**:
   ```bash
   cp .env.example .env
   # Edita .env y coloca tus valores:
   SUPABASE_URL="https://tu-proyecto.supabase.co"
   SUPABASE_PUBLISHABLE_KEY="tu-clave-anon-publica"
   ```

6. **Sube los GIFs** (opcional, solo si tienes el dataset de ejercicios):
   ```bash
   dart run tool/upload_gifs.dart
   ```

7. **Genera el catálogo de ejercicios** (solo la primera vez):
   ```bash
   dart run tool/build_catalog_asset.dart
   ```

8. **Ejecuta la app**:
   ```bash
   ./tool/run.sh
   ```

## Comandos disponibles

- `flutter test` - Ejecuta los tests
- `flutter analyze` - Análisis estático de código
- `dart run tool/build_catalog_asset.dart` - Regenera el asset del catálogo tras tocar el dataset
- `dart run tool/upload_gifs.dart` - Sube los GIFs al bucket de Supabase Storage

## Arquitectura Supabase

- **Base de datos local**: SQLite via Drift (réplica de trabajo, sincronizada con Postgres)
- **Base de datos única fuente de verdad**: Supabase Postgres (remoto)
- **Sincronización**: Los cambios locales se suben a Supabase mediante cola/ migraciones
- **Storage**: GIFs y miniaturas en bucket `exercise-media` de Supabase Storage
- **Autenticación**: La app funciona tanto con auth de Supabase como sin él (modo anónimo/local)
  - Si usas auth de Supabase, los datos se aislán por `user_id`
  - Si usas modo anónimo, usa `local_user_id` fijo para el dispositivo actual
