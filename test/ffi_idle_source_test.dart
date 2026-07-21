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

  // Every source scaffolded by this ticket throws until its own ticket lands.
  // The message has to name the source, or a runtime failure on a user's
  // machine says only "unsupported" with no clue which binding is missing.
  group('scaffolded sources', () {
    final pending = <String, IdleSource>{
      'windows': const WindowsIdleSource(),
      'macos/IOKit': const MacOsIoKitIdleSource(),
      'macos/CoreGraphics': const MacOsCoreGraphicsIdleSource(),
      'unsupported OS': const UnsupportedIdleSource('linux'),
    };

    pending.forEach((label, source) {
      test('$label reports itself unsupported and throws, naming itself', () {
        // The two go together: a source that says it is supported but throws
        // would make the parity harness include it and then fail on it.
        expect(source.isSupported, isFalse);
        expect(
          source.idleMilliseconds,
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              contains(source.name),
            ),
          ),
        );
      });
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
