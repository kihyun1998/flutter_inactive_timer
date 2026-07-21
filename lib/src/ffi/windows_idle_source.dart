import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'idle_source.dart';

/// The `LASTINPUTINFO` structure `GetLastInputInfo` fills in.
///
/// Both fields are 32-bit unsigned: `cbSize` is a `UINT` the caller must set to
/// the structure's own size before the call — the API validates it and fails
/// outright if it is wrong — and `dwTime` is a `DWORD` tick value.
final class _LastInputInfo extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int dwTime;
}

typedef _GetLastInputInfoC = Int32 Function(Pointer<_LastInputInfo>);
typedef _GetLastInputInfoDart = int Function(Pointer<_LastInputInfo>);

typedef _GetTickCount64C = Uint64 Function();
typedef _GetTickCount64Dart = int Function();

// Resolved once, on first use: a top-level `final` in Dart is lazily
// initialised, so a host that never reads the idle duration never opens these
// libraries — which is what keeps this file importable, and its arithmetic
// testable, on the Linux CI host.
// coverage:ignore-start
final _GetLastInputInfoDart _getLastInputInfo = DynamicLibrary.open(
  'user32.dll',
).lookupFunction<_GetLastInputInfoC, _GetLastInputInfoDart>(
  'GetLastInputInfo',
);

final _GetTickCount64Dart _getTickCount64 = DynamicLibrary.open(
  'kernel32.dll',
).lookupFunction<_GetTickCount64C, _GetTickCount64Dart>('GetTickCount64');
// coverage:ignore-end

/// Reads the Idle duration on Windows from `GetLastInputInfo` against
/// `GetTickCount64`, through `dart:ffi` (ADR-0004).
///
/// This reproduces what the retired C++ plugin computed rather than improving
/// on it — the point of the FFI port is that behavior is unchanged, so any
/// difference here is a regression by definition.
class WindowsIdleSource extends IdleSource {
  const WindowsIdleSource();

  /// The 32 bits the Windows tick clock actually spans.
  static const int _tick32Mask = 0xFFFFFFFF;

  @override
  String get name => 'windows/GetLastInputInfo';

  @override
  bool get isSupported => true;

  /// The Idle duration implied by one reading of the two clocks, including
  /// what to report when the OS call did not succeed.
  ///
  /// Everything that can be decided without touching the OS lives here, so it
  /// can be tested on any host — the same split as `InactivityPolicy` and the
  /// shell. What is left in [idleMilliseconds] is plumbing with no decisions in
  /// it.
  ///
  /// **When [succeeded] is false the answer is zero — the user is treated as
  /// active.** The retired C++ made that choice and it must be preserved: the
  /// shell catches exceptions from a read as transient faults and retries, so
  /// throwing on a persistently failing API would stall monitoring instead of
  /// degrading it, and reporting a large idle span would log the user out for
  /// an API failure.
  ///
  /// Otherwise this is the wraparound-safe subtraction.
  /// `GetLastInputInfo` reports the last input as a **32-bit** tick that wraps
  /// roughly every 49.7 days, while `GetTickCount64` does not wrap in any
  /// practical timeframe. Subtracting them as they come would, after a wrap,
  /// report an idle span of about 49.7 days and fire the timeout on an actively
  /// used machine. Truncating the current tick to the same 32 bits and
  /// subtracting modulo 2^32 is correct for any real span, because a real span
  /// is far shorter than one lap. Dart has no 32-bit unsigned type, so the mask
  /// states that wrapping explicitly; on a two's-complement 64-bit int it also
  /// turns the negative difference a wrap produces back into the intended
  /// positive one. See ADR-0001 — this is the arithmetic that motivated
  /// computing the idle duration on the side of the boundary where it is
  /// naturally correct.
  @visibleForTesting
  static int idleFromTicks({
    required bool succeeded,
    required int tickCount64,
    required int lastInputTick,
  }) =>
      succeeded ? (tickCount64 - lastInputTick) & _tick32Mask : 0;

  // coverage:ignore-start
  @override
  int idleMilliseconds() {
    // Freed unconditionally: this runs on every poll for the lifetime of the
    // app, so a leaked 8 bytes per call is a leak that grows all day. `calloc`
    // rather than `malloc` so the tick field is zero even on the failure path,
    // where it is read but ignored.
    final info = calloc<_LastInputInfo>();
    try {
      info.ref.cbSize = sizeOf<_LastInputInfo>();
      return idleFromTicks(
        succeeded: _getLastInputInfo(info) != 0,
        tickCount64: _getTickCount64(),
        lastInputTick: info.ref.dwTime,
      );
    } finally {
      calloc.free(info);
    }
  }
  // coverage:ignore-end
}
