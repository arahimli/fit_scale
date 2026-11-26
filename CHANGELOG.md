## 0.1.0

* First release.
* `FitScaleScope` and `context.fit`: clamped width, height, uniform and font
  factors. No global singleton; nested scopes with `useLayoutSize` scale a
  pane by its own size.
* Touch-target floor (`tap`): 48 on Android, 44 on iOS, configurable.
* Fonts never below the design size by default; the system text scale is
  applied on top by Flutter.
* `FitBox`: min-height box that grows with its text instead of overflowing.
* `FitSquare`: stays square on every aspect ratio.
* `package:fit_scale/testing.dart`: `testFitScale` and `pumpFitScreen` render a
  screen on 9 device sizes × 3 system text sizes and fail on overflow, small
  tap targets and text below a minimum size. `loadFitScaleTestFonts` renders
  real glyphs instead of Ahem.
