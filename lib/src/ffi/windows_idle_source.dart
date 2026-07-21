import 'idle_source.dart';

/// Reads the Idle duration on Windows from `GetLastInputInfo` against
/// `GetTickCount64`, through `dart:ffi` (ADR-0004).
///
/// **Scaffolding — the binding is not written yet.** This class exists now so
/// that the ticket implementing it edits only this file, and so the parity
/// harness has a stable name to resolve. Implementing it means filling in
/// [idleMilliseconds] and flipping [isSupported]; nothing outside this file
/// needs to change.
///
/// The implementation must reproduce what the retired C++ plugin did, not
/// improve on it: `GetLastInputInfo` reports the last input time as a **32-bit**
/// tick value that wraps roughly every 49.7 days, so the current tick has to be
/// truncated to the same 32 bits before subtracting (ADR-0001). Keep that
/// arithmetic in a pure function so its boundaries are testable without
/// Windows.
class WindowsIdleSource extends IdleSource {
  const WindowsIdleSource();

  @override
  String get name => 'windows/GetLastInputInfo';

  @override
  bool get isSupported => false;

  @override
  int idleMilliseconds() => throw UnsupportedError(
        '$name: the Windows FFI binding has not been implemented yet.',
      );
}
