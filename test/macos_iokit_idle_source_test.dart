import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';
import 'package:test/test.dart';

const int _nsPerMs = 1000000;

void main() {
  // The IOKit walk itself cannot run off macOS, so everything that is a
  // decision rather than plumbing lives here: the unit conversion and what to
  // report when any step of the walk failed. Same split as the Windows source
  // and as InactivityPolicy against the shell.
  group('MacOsIoKitIdleSource.idleFromNanoseconds', () {
    test('converts nanoseconds to whole milliseconds', () {
      expect(
        MacOsIoKitIdleSource.idleFromNanoseconds(
          succeeded: true,
          nanoseconds: 1500 * _nsPerMs,
        ),
        1500,
      );
    });

    test('truncates rather than rounds, matching the retired Swift', () {
      // The Swift divided integers, so 1.999 ms read as 1 ms. Rounding here
      // would be an improvement, and an improvement is a behavior change.
      expect(
        MacOsIoKitIdleSource.idleFromNanoseconds(
          succeeded: true,
          nanoseconds: 1999999,
        ),
        1,
      );
    });

    test('sub-millisecond idle is zero, not one', () {
      expect(
        MacOsIoKitIdleSource.idleFromNanoseconds(
          succeeded: true,
          nanoseconds: 999999,
        ),
        0,
      );
    });

    test('a failed lookup reports the user as active, not idle', () {
      // Zero, not an exception and not a large span — the shell treats a thrown
      // read as a transient fault and retries, so throwing on a persistent
      // failure would stall monitoring instead of degrading it.
      expect(
        MacOsIoKitIdleSource.idleFromNanoseconds(
          succeeded: false,
          nanoseconds: 999 * _nsPerMs,
        ),
        0,
      );
    });

    test('a negative reading is clamped to zero', () {
      // Should not happen, but an unboxing that silently produced a negative
      // would otherwise become a negative idle duration, and the policy reads
      // that as "input arrived in the future" — better to look active.
      expect(
        MacOsIoKitIdleSource.idleFromNanoseconds(
          succeeded: true,
          nanoseconds: -1,
        ),
        0,
      );
    });

    test('a very long idle span survives the conversion', () {
      // Nanoseconds are a big number fast: a day of idle is 8.64e13, well past
      // 32 bits. Dart ints are 64-bit, so this is only a guard against someone
      // "optimising" the conversion later.
      const oneDayNs = 86400 * 1000 * _nsPerMs;
      expect(
        MacOsIoKitIdleSource.idleFromNanoseconds(
          succeeded: true,
          nanoseconds: oneDayNs,
        ),
        86400 * 1000,
      );
    });
  });

  group('MacOsIoKitIdleSource', () {
    test('reports itself supported now that the binding exists', () {
      expect(const MacOsIoKitIdleSource().isSupported, isTrue);
    });

    test('names the registry property it reads', () {
      expect(const MacOsIoKitIdleSource().name, contains('HIDIdleTime'));
    });
  });
}
