/// Pure breakpoint helper for layout adaptation.
///
/// Provides screen classification (phone/tablet), margins, gutters and
/// maximum content width based on the actual screen width in dp.
///
/// Testable without widgets (RNF-7).
enum ScreenClass {
  /// Mobile phone screens (< 600 dp).
  phone,

  /// Tablet screens (≥ 600 dp).
  tablet,
}

const double kTabletBreakpoint = 600.0;

const double kContentMaxWidth = 640.0;

ScreenClass screenClassOf(double width) =>
    width < kTabletBreakpoint ? ScreenClass.phone : ScreenClass.tablet;

double horizontalMarginOf(ScreenClass screenClass) =>
    screenClass == ScreenClass.phone ? 16.0 : 24.0;

double gutterOf(ScreenClass screenClass) =>
    screenClass == ScreenClass.phone ? 12.0 : 16.0;