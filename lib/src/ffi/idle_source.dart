/// A single way of reading the **Idle duration** — milliseconds since the
/// user's last keyboard or mouse input — directly from the operating system.
///
/// Deliberately **synchronous**: an FFI call into the OS is a plain function
/// call, so there is no `await` and therefore no resume point at which
/// monitoring state could have changed underneath us. (That hazard is why the
/// method-channel path needs the generation counter — see
/// `docs/agents/lessons.md`.) The asynchronous
/// [FlutterInactiveTimerPlatform.getIdleDuration] contract is preserved by the
/// adapter, not by this type; see ADR-0003 and ADR-0004.
///
/// A source returns one already-computed value rather than raw clock readings,
/// per ADR-0001 — the wraparound-prone subtraction stays on the side of the
/// boundary where it is naturally correct.
abstract class IdleSource {
  const IdleSource();

  /// Human-readable identifier, e.g. `windows/GetLastInputInfo`. Shown in the
  /// example's parity screen and used to label parity-test failures, so it must
  /// identify *which* binding a failure came from.
  String get name;

  /// Whether this source can actually read the OS on the current platform.
  ///
  /// `false` covers two cases that behave identically at the call site but mean
  /// different things: an OS with no FFI path at all
  /// ([UnsupportedIdleSource]), and a platform whose binding has not been
  /// written yet. Both throw from [idleMilliseconds].
  bool get isSupported;

  /// The Idle duration in milliseconds.
  ///
  /// Throws [UnsupportedError] when [isSupported] is `false`. Implementations
  /// that *are* supported must not throw for ordinary OS failures — they report
  /// `0` (treat the user as active) so a transient failure cannot silently
  /// end monitoring.
  int idleMilliseconds();

  @override
  String toString() => 'IdleSource($name)';
}

/// The source used on platforms this package has no FFI binding for.
///
/// Reaching it is not a bug — it is how a Linux or web host is told, in a
/// message that names the offending platform, that desktop inactivity
/// detection is unavailable here.
class UnsupportedIdleSource extends IdleSource {
  const UnsupportedIdleSource(this.operatingSystem);

  /// The `Platform.operatingSystem` value that resolved to this source.
  final String operatingSystem;

  @override
  String get name => 'unsupported/$operatingSystem';

  @override
  bool get isSupported => false;

  @override
  int idleMilliseconds() => throw UnsupportedError(
        '$name: flutter_inactive_timer reads the idle duration through '
        'platform-specific FFI and supports Windows and macOS only.',
      );
}
