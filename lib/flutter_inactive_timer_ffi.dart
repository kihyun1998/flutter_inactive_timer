import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_inactive_timer/src/ffi/idle_source.dart';
import 'package:flutter_inactive_timer/src/ffi/idle_sources.dart';

export 'package:flutter_inactive_timer/src/ffi/idle_source.dart';
export 'package:flutter_inactive_timer/src/ffi/idle_sources.dart';
export 'package:flutter_inactive_timer/src/ffi/macos_iokit_idle_source.dart';
export 'package:flutter_inactive_timer/src/ffi/windows_idle_source.dart';

/// An implementation of [FlutterInactiveTimerPlatform] that reads the Idle
/// duration through `dart:ffi` instead of a method channel (ADR-0004).
///
/// **Not the default yet.** [FlutterInactiveTimerPlatform.instance] still
/// resolves to the method-channel implementation; this class is built and
/// verified alongside it so the two can be compared on a real machine before
/// either is retired. Switching the default is a separate change.
///
/// The [getIdleDuration] override is `async` only because the platform
/// interface says so — the read underneath is a synchronous OS call. That
/// distinction matters more than it looks: the method-channel path suspends at
/// an `await`, which is where four bugs in this package's history came from
/// (`docs/agents/lessons.md`). Here nothing is read after a suspension point,
/// because there is no suspension point. If you ever add one, the shell's
/// generation check is what has to be revisited.
class FfiFlutterInactiveTimer extends FlutterInactiveTimerPlatform {
  /// Creates an FFI-backed platform reading from [source], defaulting to the
  /// host's own source. Tests inject their own rather than reaching the OS.
  FfiFlutterInactiveTimer({IdleSource? source})
      : source = source ?? defaultIdleSource();

  /// The source this platform reads from — exposed so the parity harness can
  /// label which binding produced a value.
  final IdleSource source;

  @override
  Future<int> getIdleDuration() async => source.idleMilliseconds();
}
