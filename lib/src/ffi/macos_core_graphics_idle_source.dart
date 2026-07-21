import 'idle_source.dart';

/// Reads the Idle duration on macOS by asking CoreGraphics how long it has been
/// since the last input event, via `dart:ffi` (ADR-0004).
///
/// **Scaffolding — the binding is not written yet.** One of two candidates; the
/// other is [MacOsIoKitIdleSource]. Both exist so their tickets can be worked in
/// parallel without touching the same file. Exactly one survives — the ticket
/// that measures them deletes the loser.
///
/// This candidate is a single call returning seconds as a floating-point value,
/// with nothing to release afterwards, which is the whole argument for it. Two
/// details decide whether it can win: the query has to cover **every** kind of
/// input event (asking about one kind counts keyboard but not mouse, or the
/// reverse), and the seconds-to-milliseconds conversion introduces rounding the
/// parity tolerance has to absorb.
class MacOsCoreGraphicsIdleSource extends IdleSource {
  const MacOsCoreGraphicsIdleSource();

  @override
  String get name => 'macos/CGEventSource';

  @override
  bool get isSupported => false;

  @override
  int idleMilliseconds() => throw UnsupportedError(
        '$name: the macOS CoreGraphics FFI binding has not been implemented '
        'yet.',
      );
}
