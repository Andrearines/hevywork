# Investigation Report: Exercise Info Screen Issues

## Test Results Summary

### `flutter test test/exercise_info_view_test.dart`
**Passes:** 10 tests  
**Fails:** 6 tests

### Failing Tests:

1. **"al cambiar a EN muestra los pasos ingleses"** (line 196)
   - `find.text('EN')` returns 0 widgets - ChoiceChip label not findable
   
2. **"lista los pasos en español por defecto"** (line 186)
   - `find.text('Baja la barra hasta tocar el pecho')` returns 0 widgets - Steps not visible
   
3. **"historial de sesiones paginado (SCR-7, RF-14 y RF-15) la sesión más reciente se expande con tabla, warmup y ★"** (line 266)
   - `find.text('123.3 kg')` returns 0 widgets - Session data not displaying correctly
   
4. **"historial de sesiones paginado (SCR-7, RF-14 y RF-15) muestra los pesos en la unidad del perfil (RNF-7)"** (line 408)
   - `find.text('661.4 lb')` returns 0 widgets - Unit conversion failing
   
5. **"historial de sesiones paginado (SCR-7, RF-14 y RF-15) no desborda en 375 dp (RNF-3)"** (line 431)
   - Overflow error: 173 pixels on the right
   
6. **"CTA y conservados (G33-G36) G35: Given sin sesión activa, When se pulsa, Then se crea sesión y snackbar"** (line 518)
   - `find.text('Sesión iniciada con el ejercicio')` returns 0 widgets - CTA snackbar not showing

### `flutter analyze lib/ui/views/exercise_info_view.dart`
**Issues:** 9 items found (1 unused import, 3 library prefix info, 3 prefer final, 2 unused elements, 1 use_build_context_synchronously)

### Spec 019 Alignment Issues:

1. **Context Bar vs AppBar** (SCR-1): Current code has AppBar, spec requires Context bar with "volver", "Base de Datos / Detalle de Ejercicio", favorito/más opciones (oculto v1)
2. **Section Order**: Spec requires "context bar → identity → media → KPIs → gráfico → cues → historial → CTA", current code missing context bar
3. **KPIs without borders**: Spec says "sin bordes", current code has borders on KPI cards
4. **Language switch**: ChoiceChip labels not findable by test `find.text()`
5. **Unit conversion RNF-7**: lbs conversion not working correctly in test

### Code Checks (from task step 3):

- ✅ `Image.file` in `_buildmedia` has `scale`, `cacheWidth`, `cacheHeight` (line 209-210)
- ✅ `_badge` has `ConstrainedBox(maxWidth: 60)` (line 253)

### Golden Test Update
`flutter test --update-goldens` produces no changes - same tests fail before/after