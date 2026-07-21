import 'dart:ffi';

import 'package:meta/meta.dart';

import 'idle_source.dart';

/// `kCGEventSourceStateHIDSystemState` — the system-wide HID input state.
///
/// The choice of state is the single most consequential constant in this file.
/// The combined *session* state tracks one login session's event stream, which
/// is not the same quantity the IOKit candidate reads from `IOHIDSystem`. If
/// the two macOS candidates disagree, suspect this first.
const int _hidSystemState = 1;

/// `kCGAnyInputEventType`, defined as `(CGEventType)(~0)`.
///
/// Every kind of input event, not one kind. Asking about a specific type would
/// count keyboard but not mouse, or the reverse, and the resulting source would
/// reset the countdown for only half of what counts as activity.
const int _anyInputEventType = 0xFFFFFFFF;

// The state id is a signed 32-bit enum — it has a negative member — while the
// event type is unsigned 32-bit. The return is a CFTimeInterval, a double.
typedef _SecondsSinceLastEventTypeC = Double Function(Int32, Uint32);
typedef _SecondsSinceLastEventTypeDart = double Function(int, int);

// Resolved on first use, so this file stays importable — and its arithmetic
// testable — on a CI host that is not macOS.
// coverage:ignore-start
final _secondsSinceLastEventType = DynamicLibrary.open(
  '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics',
).lookupFunction<_SecondsSinceLastEventTypeC, _SecondsSinceLastEventTypeDart>(
  'CGEventSourceSecondsSinceLastEventType',
);
// coverage:ignore-end

/// Reads the Idle duration on macOS by asking CoreGraphics how long it has been
/// since the last input event, via `dart:ffi` (ADR-0004).
///
/// One of two candidates; the other is `MacOsIoKitIdleSource`. This one is a
/// single call with nothing to allocate and nothing to release, which is the
/// whole argument for it: the class of bug that the IOKit walk can have — a
/// missed release on an early-return path, growing all day — cannot exist here.
///
/// It reads an already-aggregated value rather than intercepting events, so it
/// should need no accessibility permission and should work under the App
/// Sandbox. That is a claim the parity run in CI tests, not an assumption.
class MacOsCoreGraphicsIdleSource extends IdleSource {
  const MacOsCoreGraphicsIdleSource();

  static const int _millisecondsPerSecond = 1000;

  @override
  String get name => 'macos/CGEventSource';

  @override
  bool get isSupported => true;

  /// The Idle duration in milliseconds implied by a reading in [seconds].
  ///
  /// **There is no success flag here, unlike the other two sources, because
  /// this API has none.** It returns a bare number with no error channel, so
  /// the question is not "did the call succeed" but "is this number usable" —
  /// and the unusable answers a floating-point API can give are NaN, infinity,
  /// and negatives. All of them mean the same thing to us as a failed call
  /// elsewhere: report zero, treat the user as active, let the next poll try
  /// again. Without the NaN guard, `(NaN * 1000).floor()` throws, which the
  /// shell would catch as a transient fault and retry forever.
  ///
  /// **Truncating, not rounding**, to match the IOKit candidate's
  /// nanosecond division — otherwise the two candidates would sit a
  /// millisecond apart for no reason and make the comparison harder to read.
  @visibleForTesting
  static int idleFromSeconds(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return 0;
    return (seconds * _millisecondsPerSecond).floor();
  }

  // coverage:ignore-start
  @override
  int idleMilliseconds() => idleFromSeconds(
        _secondsSinceLastEventType(_hidSystemState, _anyInputEventType),
      );
  // coverage:ignore-end
}
