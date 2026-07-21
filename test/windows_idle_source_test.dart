import 'package:flutter_inactive_timer/flutter_inactive_timer_ffi.dart';
import 'package:test/test.dart';

/// The largest value the 32-bit last-input tick can hold, i.e. the instant
/// before it wraps back to zero.
const int _maxTick32 = 0xFFFFFFFF;

void main() {
  // These exercise the arithmetic the retired C++ plugin performed, isolated
  // from the OS calls so the boundaries are reachable from any host. The
  // interesting cases are not the ordinary ones — they are the ones that only
  // occur after ~49.7 days of uptime, which is precisely why they were never
  // caught by hand (ADR-0001).
  group('WindowsIdleSource.idleFromTicks', () {
    test('ordinary case subtracts the two ticks', () {
      expect(
        WindowsIdleSource.idleFromTicks(
            succeeded: true, tickCount64: 1000, lastInputTick: 400),
        600,
      );
    });

    test('input at this very instant is zero idle', () {
      expect(
        WindowsIdleSource.idleFromTicks(
            succeeded: true, tickCount64: 1000, lastInputTick: 1000),
        0,
      );
    });

    test('the high bits of the 64-bit tick are discarded, not subtracted', () {
      // Uptime past the 32-bit range: the last-input tick has no high bits to
      // compare against, so using the full 64-bit value would report the whole
      // uptime as idle time. This is the wrong answer the retired C++ avoided
      // by truncating first.
      expect(
        WindowsIdleSource.idleFromTicks(
          succeeded: true,
          tickCount64: 0x2000003E8, // low 32 bits are 1000
          lastInputTick: 400,
        ),
        600,
      );
    });

    test('just before the wrap it is still a plain subtraction', () {
      expect(
        WindowsIdleSource.idleFromTicks(
          succeeded: true,
          tickCount64: _maxTick32,
          lastInputTick: _maxTick32 - 15,
        ),
        15,
      );
    });

    test('across the wrap it counts forward, not backward', () {
      // The tick rolled over 5ms ago; the last input was 16ms before the roll.
      // A signed subtraction would give a large negative number here, which is
      // the garbage ADR-0001 was written about.
      expect(
        WindowsIdleSource.idleFromTicks(
          succeeded: true,
          tickCount64: 0x100000005, // low 32 bits are 5, having wrapped
          lastInputTick: _maxTick32 - 15,
        ),
        21,
      );
    });

    test('the widest representable idle span stays positive', () {
      // One tick short of a full lap. Beyond this the arithmetic genuinely
      // cannot tell 2^32 + n from n — but reaching it needs ~49.7 days with no
      // input at all, and the timeout will have fired long before.
      expect(
        WindowsIdleSource.idleFromTicks(
          succeeded: true,
          tickCount64: _maxTick32,
          lastInputTick: 0,
        ),
        _maxTick32,
      );
    });
  });

  group('WindowsIdleSource.idleFromTicks on failure', () {
    test('a failed OS call reports the user as active, not idle', () {
      // Zero, not an exception and not a large span. Throwing would reach the
      // shell's catch, which treats a read failure as transient and retries —
      // so a persistently failing API would stall monitoring rather than
      // degrade it. Reporting a large span would log the user out because an
      // API call failed.
      expect(
        WindowsIdleSource.idleFromTicks(
          succeeded: false,
          tickCount64: 999999,
          lastInputTick: 0,
        ),
        0,
      );
    });

    test('failure wins over whatever the tick fields happen to hold', () {
      // The struct is zero-filled, so a failed call leaves the tick field at 0
      // while the current tick is large — exactly the shape that would produce
      // a huge bogus idle span if the failure flag were ignored.
      expect(
        WindowsIdleSource.idleFromTicks(
          succeeded: false,
          tickCount64: _maxTick32,
          lastInputTick: 0,
        ),
        0,
      );
    });
  });

  group('WindowsIdleSource', () {
    test('reports itself supported now that the binding exists', () {
      expect(const WindowsIdleSource().isSupported, isTrue);
    });

    test('names the API it reads, so a failure points at the binding', () {
      expect(const WindowsIdleSource().name, contains('GetLastInputInfo'));
    });
  });
}
