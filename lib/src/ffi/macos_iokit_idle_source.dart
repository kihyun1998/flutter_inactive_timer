import 'idle_source.dart';

/// Reads the Idle duration on macOS through IOKit — the HID system service's
/// idle-time property — via `dart:ffi` (ADR-0004).
///
/// **Scaffolding — the binding is not written yet.** One of two candidates; the
/// other is [MacOsCoreGraphicsIdleSource]. Both exist so their tickets can be
/// worked in parallel without touching the same file, and so the parity harness
/// can compare them against the retired method channel. Exactly one survives —
/// the ticket that measures them deletes the loser.
///
/// This candidate walks the same path the retired Swift plugin walked, which is
/// why it is first in the resolution order: whatever the measurement shows, its
/// values cannot disagree with the implementation being replaced. The cost is
/// that every step allocates something with its own ownership rule, including
/// the early-return paths.
class MacOsIoKitIdleSource extends IdleSource {
  const MacOsIoKitIdleSource();

  @override
  String get name => 'macos/IOKit-HIDIdleTime';

  @override
  bool get isSupported => false;

  @override
  int idleMilliseconds() => throw UnsupportedError(
        '$name: the macOS IOKit FFI binding has not been implemented yet.',
      );
}
