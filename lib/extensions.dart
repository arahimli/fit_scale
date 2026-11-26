/// Everything in `package:fit_scale/fit_scale.dart`, plus `56.w`-style
/// extensions on `num` with the same names as flutter_screenutil
/// (`.w .h .r .sp .sw .sh .verticalSpace .horizontalSpace`, and `.tap`).
///
/// Migrating from flutter_screenutil starts with swapping its import for
/// this one and `ScreenUtilInit` for `FitScaleScope`. Prefer
/// `context.fit` in new code: extensions read the root scope only, and a
/// size change rebuilds the whole tree below it.
///
/// Kept in its own library so the short names never collide with other
/// packages unless you ask for them.
library;

export 'fit_scale.dart';
export 'src/extensions.dart';
