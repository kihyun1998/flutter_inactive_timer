import 'flutter_inactive_timer_ffi.dart';

/// The seam between the timer and whatever reads the Idle duration.
///
/// Subclass this to supply your own reader — a fake in a test, or a platform
/// this package does not cover. **Extend it, do not implement it:**
/// [getIdleDuration] has a default body, so an `extends` subclass keeps
/// compiling if the interface ever gains a member, while an `implements` one
/// breaks. Until 4.0.0 that rule was enforced at runtime by
/// `plugin_platform_interface`'s token; dropping that package to become a pure
/// Dart package (ADR-0005) gave up the enforcement but not the rule, and the
/// failure it guarded against is a compile error rather than a silent one.
abstract class FlutterInactiveTimerPlatform {
  FlutterInactiveTimerPlatform();

  /// The instance the timer reads from unless one is passed to its constructor.
  ///
  /// Defaults to [FfiFlutterInactiveTimer], which reads the idle duration
  /// straight from the OS through `dart:ffi` (ADR-0004). It replaced a
  /// method-channel implementation backed by Swift and C++; both reported the
  /// same value on every platform before the swap, and the CI runs that proved
  /// it are recorded in ADR-0004.
  ///
  /// A plain mutable field rather than a validating setter: the validation it
  /// used to carry belonged to `plugin_platform_interface`, and pretending to
  /// still guard something would be worse than saying plainly that it does not.
  ///
  /// Prefer passing a platform to the `FlutterInactiveTimer` constructor over
  /// setting this — the constructor parameter is per-instance, this is global.
  static FlutterInactiveTimerPlatform instance = FfiFlutterInactiveTimer();

  /// Milliseconds since the user's last keyboard or mouse input, computed per
  /// platform and returned as a single value. See ADR-0001.
  ///
  /// Asynchronous because the public API is (ADR-0003), not because the read
  /// is: an FFI read is a plain synchronous call.
  Future<int> getIdleDuration() {
    throw UnimplementedError('getIdleDuration() has not been implemented.');
  }
}
