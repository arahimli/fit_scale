## 0.7.0

* Foldables. `FitHinge` (`fit.hinge`, `FitScale.hingeOf`): the fold or
  hinge splitting the screen, with its bounds and posture (book, tabletop,
  flat). Only separating features count, as in Flutter: a half-open fold
  or a hinge with a width.
* `FitHingeLayout`: `start` and `end` panes on either side of the fold,
  `single` otherwise; right-to-left aware, and correct when it does not
  start at the screen origin.
* Harness: `FitDevices.foldables` (Fold in book posture, Flip in tabletop
  posture, Surface Duo), not in `FitDevices.all`; `FitDevice.displayFeatures`;
  new default check `FitCheck.hingeOverlap` for text lines and tap
  targets lying across a fold. It only fires on devices with one.
* `FitDebugOverlay` draws the fold or hinge and outlines what crosses it
  (teal, `FitDebugProblemKind.hingeOverlap`); the panel shows the posture.
* `FitScaleData` has a `hinge` field and its constructor takes
  `displayFeatures`.

## 0.6.0

* `testFitScale(reportDir: ...)` writes a report when the group finishes,
  also when cases fail: `<screen>.html` (devices × text sizes with a
  screenshot per case and every problem), `<screen>.md`, `<screen>.json`
  and an `index.html` of all screens. On GitHub Actions the markdown is
  added to the job summary.
* `FitScreenReport` with `toMarkdown()`, `toHtml()` and `toJson()`, and
  `writeFitReport`, for custom reports.
* CI uploads the package's own report as an artifact.

## 0.5.0

* New `FitDebugOverlay`: outlines tap targets below the platform minimum
  (red), text drawn below `minFontSize` (purple) and text cut off by
  `maxLines` (orange) on top of the running app, plus a panel with the
  window class, size, scale factors and system text scale. Off in release
  builds by default, scans after each frame without requesting frames,
  touches pass through. `onProblems` reports changes.
* The text checks now live in one place shared by the harness and the
  overlay; harness messages are unchanged.

## 0.4.0

* Breakpoints after Material 3's window size classes: `FitWindowClass`
  (compact < 600, medium, expanded ≥ 840, large ≥ 1200, extraLarge ≥ 1600),
  `FitHeightClass`, `FitBreakpoints` in `FitScaleConfig`.
* `fit.windowClass`, `fit.heightClass`, `fit.when(...)` and `fit.pick(...)`
  with mobile-first fallback to the nearest narrower class.
* `FitLayout`: a layout per window class that rebuilds only when the class
  changes; `FitScale.windowClassOf` / `heightClassOf` for the same
  dependency. Inside `useLayoutSize` scopes classes follow the pane.
* Harness: `FitDevices.foldOpen` (673×841) and `FitDevices.ipadPro13`
  (1032×1376), and `FitDevices.tablets`. **`FitDevices.all` now has 11
  devices**, so `testFitScale` defines 33 tests per screen instead of 27.
* Fix: the root scope rebuilt its whole subtree on every size change even
  in apps that never use `package:fit_scale/extensions.dart`. It now does
  so only once an extension has been read.

## 0.3.0

* New `FitText`: text that shrinks only when it does not fit, never below
  `minFontSize` drawn on screen (system text scale included, the same
  measure as the `minFont` check). For avatars, badges, chips and one-line
  headers. Measured in the demo: plain `Text` initials leave a 56 px
  avatar in all 8 devices at text ×2.0, `FitText` initials in none of 24.
* New opt-in `FitCheck.truncatedText`: reports text cut off by `maxLines`.
* New `FitCheck.defaults`, the checks run when none are given.
* Example and README use `FitText` for avatar initials.

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
