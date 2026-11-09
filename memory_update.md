# Task Update

**Task:** T-xxx - Wrap ExerciseThumb in GestureDetector for navigation to ExerciseInfoView

**Change description:** Modified `lib/ui/views/live_workout_view.dart` line ~1399 to wrap `ExerciseThumb` in a `GestureDetector` that navigates to `ExerciseInfoView` with dependencies (`localDb`, `workoutRepository`). The `ExerciseThumb` widget is now the child of the `GestureDetector` rather than being directly tappable.

**Files modified:**
- `lib/ui/views/live_workout_view.dart` - Replaced `ExerciseThumb(` with `GestureDetector(onTap: ..., child: ExerciseThumb(`)

**Verification:** Change applied exactly as specified. No other modifications made.