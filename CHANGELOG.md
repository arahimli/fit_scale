## 0.2.0

* New `package:fit_scale/extensions.dart`: `56.w`-style extensions on `num`
  with flutter_screenutil's names (`.w .h .r .sp .sw .sh .verticalSpace
  .horizontalSpace`) plus `.tap`, backed by the clamped factors. Migrating
  starts with swapping one import.
* `FitScale.global`: data of the root `FitScaleScope`, used by the
  extensions. When it changes the root scope rebuilds its subtree, since
  extension calls have no `context`. Scopes with `useLayoutSize` never
  become global.
* `FitScaleScope` is now a `StatefulWidget`; its constructor is unchanged.
* README: a measured migration guide. Swapping the import alone still
  fails 21 of 24 demo cases; fixing what `testFitScale` reports gets to 0.

## 0.1.1

* README: side-by-side screenshots against flutter_screenutil, measured on
  the real package (0 of 24 device and text-size cases fail), and a note on
  the Flutter 3.47 Material split.
* pubspec: screenshots for pub.dev.
* Test screens and README samples use a generic English order screen.
* CI on Flutter 3.24.5 and stable; `flutter_lints` lowered to ^5.0.0 so the
  package resolves on its minimum Flutter version.

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
