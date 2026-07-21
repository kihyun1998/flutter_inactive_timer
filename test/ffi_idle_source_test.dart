import 'dart:io' show Platform;

import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in [IdleSource] so the adapter can be tested without touching FFI.
class _FakeIdleSource extends IdleSource {
  const _FakeIdleSource(this._value);
  final int _value;

  @override
  String get name => 'fake';

  @override
  bool get isSupported => true;

  @override
  int idleMilliseconds() => _value;
}

void main() {
  // Resolution is a pure function of the OS name so every branch is reachable
  // from any host — the CI Dart job runs on Linux and would otherwise never
  // execute the Windows or macOS arms. Same injection idea as the shell's
  // injected clock.
  group('idleSourcesFor', () {
    test('windows resolves to the single Windows source', () {
      final sources = idleSourcesFor('windows');
      expect(sources, hasLength(1));
      expect(sources.single, isA<WindowsIdleSource>());
    });

    test('macos resolves to both candidates, IOKit first', () {
      final sources = idleSourcesFor('macos');
      expect(sources, hasLength(2));
      expect(sources.first, isA<MacOsIoKitIdleSource>());
      expect(sources.last, isA<MacOsCoreGraphicsIdleSource>());
    });

    test('an unsupported OS resolves to a source naming that OS', () {
      final sources = idleSourcesFor('linux');
      expect(sources, hasLength(1));
      expect(sources.single, isA<UnsupportedIdleSource>());
      expect(sources.single.isSupported, isFalse);
      expect(sources.single.name, contains('linux'));
    });

    test('defaultIdleSourceFor picks the first candidate', () {
      expect(defaultIdleSourceFor('macos'), isA<MacOsIoKitIdleSource>());
      expect(defaultIdleSourceFor('windows'), isA<WindowsIdleSource>());
    });

    test('the host-reading wrappers agree with the pure form', () {
      final os = Platform.operatingSystem;
      expect(
        idleSources().map((s) => s.name),
        idleSourcesFor(os).map((s) => s.name),
      );
      expect(defaultIdleSource().name, defaultIdleSourceFor(os).name);
    });
  });

  // Every binding now exists, so the only unsupported source left is the one
  // standing in for a platform this package does not cover. Its message has to
  // name the platform, or a user on Linux gets a bare "unsupported" with
  // nothing to act on.
  group('unsupported platforms', () {
    test('report themselves unsupported and throw, naming the platform', () {
      // The two go together: a source that claims to be supported but throws
      // would make the parity harness include it and then fail on it.
      const source = UnsupportedIdleSource('linux');
      expect(source.isSupported, isFalse);
      expect(
        source.idleMilliseconds,
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            allOf(contains('linux'), contains('Windows and macOS')),
          ),
        ),
      );
    });

    test('every source for a supported OS claims to be supported', () {
      // The inverse of the check above, and the invariant the parity harness
      // relies on when it filters by isSupported. If a binding is ever removed,
      // this fails here rather than as a confusing skip in the integration run.
      for (final os in ['windows', 'macos']) {
        for (final source in idleSourcesFor(os)) {
          expect(source.isSupported, isTrue, reason: '${source.name} on $os');
        }
      }
    });

    test('toString carries the name, so failures identify the binding', () {
      expect(const WindowsIdleSource().toString(), contains('windows'));
      expect(
        const UnsupportedIdleSource('linux').toString(),
        contains('linux'),
      );
    });
  });

  group('FfiFlutterInactiveTimer', () {
    test('returns the source value as the idle duration', () async {
      final platform = FfiFlutterInactiveTimer(
        source: const _FakeIdleSource(1500),
      );
      expect(await platform.getIdleDuration(), 1500);
    });

    test('surfaces the source name for diagnostics', () {
      const source = _FakeIdleSource(0);
      expect(FfiFlutterInactiveTimer(source: source).source, same(source));
    });

    test('propagates an unsupported source rather than masking it', () {
      final platform = FfiFlutterInactiveTimer(
        source: const UnsupportedIdleSource('linux'),
      );
      expect(platform.getIdleDuration(), throwsA(isA<UnsupportedError>()));
    });

    test('defaults to the host source when none is injected', () {
      expect(
        FfiFlutterInactiveTimer().source.name,
        defaultIdleSource().name,
      );
    });
  });
}
