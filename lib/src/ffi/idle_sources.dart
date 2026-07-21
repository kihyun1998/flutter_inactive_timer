import 'dart:io' show Platform;

import 'idle_source.dart';
import 'macos_iokit_idle_source.dart';
import 'windows_idle_source.dart';

/// Every [IdleSource] for [operatingSystem], best-first.
///
/// Taking the OS as a parameter rather than reading [Platform] inside keeps
/// this a pure function, so the Windows and macOS arms are exercisable from the
/// Linux CI host. The same reason the shell takes an injected clock: a decision
/// that depends on ambient state cannot be tested where that state differs.
///
/// A list rather than a single source because macOS briefly had two competing
/// bindings and the parity harness needed to read both in one batch. It returns
/// one entry per platform now — the CoreGraphics candidate was measured against
/// IOKit on CI and lost (ADR-0004) — but the shape stays, since it is also what
/// lets the harness compare a binding against the implementation it replaces.
List<IdleSource> idleSourcesFor(String operatingSystem) {
  switch (operatingSystem) {
    case 'windows':
      return const [WindowsIdleSource()];
    case 'macos':
      return const [MacOsIoKitIdleSource()];
    default:
      return [UnsupportedIdleSource(operatingSystem)];
  }
}

/// The [IdleSource] the plugin uses on [operatingSystem]: the first candidate.
IdleSource defaultIdleSourceFor(String operatingSystem) =>
    idleSourcesFor(operatingSystem).first;

/// Every [IdleSource] candidate for the host this code is running on.
///
/// Used by the parity harness, which needs all candidates at once; ordinary use
/// wants [defaultIdleSource].
List<IdleSource> idleSources() => idleSourcesFor(Platform.operatingSystem);

/// The [IdleSource] the plugin uses on the host this code is running on.
IdleSource defaultIdleSource() =>
    defaultIdleSourceFor(Platform.operatingSystem);
