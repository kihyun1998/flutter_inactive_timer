import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Unlike the Windows and IOKit sources, this API has no success/failure
  // channel — it returns a bare number. So the decision surface here is not
  // "did the call work" but "is this number usable", and that is what these
  // cover. The CoreGraphics call itself cannot run off macOS.
  group('MacOsCoreGraphicsIdleSource.idleFromSeconds', () {
    test('converts seconds to whole milliseconds', () {
      expect(MacOsCoreGraphicsIdleSource.idleFromSeconds(1.5), 1500);
    });

    test('truncates rather than rounds, matching the IOKit candidate', () {
      // The other macOS candidate reads nanoseconds and divides, so 1.9999 s
      // is 1999 ms there. Rounding here would put the two candidates 1 ms apart
      // for no reason and make the parity comparison harder to read.
      expect(MacOsCoreGraphicsIdleSource.idleFromSeconds(1.9999), 1999);
    });

    test('sub-millisecond idle is zero, not one', () {
      expect(MacOsCoreGraphicsIdleSource.idleFromSeconds(0.0009), 0);
    });

    test('zero idle stays zero', () {
      expect(MacOsCoreGraphicsIdleSource.idleFromSeconds(0), 0);
    });

    test('a negative reading is clamped to zero', () {
      // A negative idle duration would read to the policy as input arriving in
      // the future; treating it as "active" is the safe direction.
      expect(MacOsCoreGraphicsIdleSource.idleFromSeconds(-1), 0);
    });

    test('NaN is treated as no reading, not as an idle span', () {
      // A double API can hand back NaN where an integer API would return an
      // error code. Without this check `(NaN * 1000).floor()` throws, which
      // would surface as a monitoring stall rather than a degraded read.
      expect(MacOsCoreGraphicsIdleSource.idleFromSeconds(double.nan), 0);
    });

    test('infinity is treated as no reading', () {
      expect(MacOsCoreGraphicsIdleSource.idleFromSeconds(double.infinity), 0);
      expect(
        MacOsCoreGraphicsIdleSource.idleFromSeconds(double.negativeInfinity),
        0,
      );
    });

    test('a long idle span survives the conversion', () {
      expect(MacOsCoreGraphicsIdleSource.idleFromSeconds(86400), 86400000);
    });
  });

  group('MacOsCoreGraphicsIdleSource', () {
    test('reports itself supported now that the binding exists', () {
      expect(const MacOsCoreGraphicsIdleSource().isSupported, isTrue);
    });

    test('names the API it reads', () {
      expect(
        const MacOsCoreGraphicsIdleSource().name,
        contains('CGEventSource'),
      );
    });
  });
}
