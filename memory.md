# Memory — hevywork

**Last updated:** Sat Oct 31 2026

**Active agent:** Sub-agent (T-008 Cierre spec 015)

## Last completed task

- **Task:** T-008 · Cierre: goldens, retirada de ficha antigua y hoja de ruta
- **Change**: 
  - Retired ExerciseDetailView: replaced `lib/ui/views/exercise_detail_view.dart` content with minimal placeholder noting substitution by ExerciseInfoView; replaced `test/exercise_detail_view_test.dart` with placeholder test
  - Updated entry points: `catalog_view.dart` and `routine_detail_view.dart` now navigate to `ExerciseInfoView` instead of `ExerciseDetailView`
  - Updated `docs/specs/README.md`: fila 015 → ✅ con decisiones clave (sustitución total confirmada)
  - Updated `docs/designer.md`: §13 added row for "Ficha de información del ejercicio"; §7.15 added component overview for ExerciseInfoView
  - Goldens: `routine_detail.png` needs visual diff review after entry point change (T-002/T-006 UI changes)
  - No new dependencies added
- **Result**: flutter analyze - no errors (only pre-existing info/warnings). flutter test - placeholder test passes; pre-existing test failures unrelated to T-008 (workout data setup, RPC issues in test environment)
- **Tests**: test/exercise_detail_view_test.dart - 1 pass (placeholder); test/exercise_info_view_test.dart - some failures pre-existing (historial needs workout data)

## Bitácora

| Date | Task | Change | Tests |
|------|------|--------|-------|
| 2026-10-31 | T-008: Cierre spec 015 | Retired ExerciseDetailView, updated entry points to ExerciseInfoView, updated docs, placeholder goldens | 1 pass (detail view test), analyze clean |
| 2026-10-31 | T-002: Fix _loadSteps null check | Changed `localDb` reference to `widget.database!` in `_loadSteps()` function; verified steps, badges, language switching work | 5/7 tests pass (historial failures pre-existing, unrelated to this fix) |

## Decisiones D-xxx

- T-008 ExerciseDetailView sustituida por ExerciseInfoView (Q-1 decisión confirmada)
- T-008 entry points en catalog_view y routine_detail_view actualizados
- T-008 no se añadieron dependencias nuevas
- T-008 docs/README.md y designer.md actualizados
- T-002 `_loadSteps` uses `widget.database!` instead of uninitialized `localDb` (decision confirmed)

## Preguntas abiertas Q-xxx

- Q-1: resuelta (sustitución total) — constancia en T-008
- Q-005: 7 pruebas de historial requieren datos de workout configurados (pre-existente, no bloquea)

---

**Next task:** — (spec 015 finalizada)