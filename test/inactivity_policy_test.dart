import 'package:flutter_inactive_timer/src/inactivity_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = InactivityPolicy();

  // timeout 10s, notification threshold at 1000ms (the 10% mark).
  InactivitySnapshot snap({
    int idleMs = 0,
    int sinceResetMs = 0,
    int timeoutMs = 10000,
    int? notifyAtMs = 1000,
    bool requireExplicitContinue = false,
    bool isNotified = false,
    bool isLocked = false,
  }) =>
      InactivitySnapshot(
        idleMs: idleMs,
        sinceResetMs: sinceResetMs,
        timeoutMs: timeoutMs,
        notifyAtMs: notifyAtMs,
        requireExplicitContinue: requireExplicitContinue,
        isNotified: isNotified,
        isLocked: isLocked,
      );

  test('before the notification threshold, schedules a check at the threshold',
      () {
    // 400ms of inactivity, threshold at 1000ms -> wait the remaining 600ms.
    final decision = policy.evaluate(snap(idleMs: 400, sinceResetMs: 400));
    expect(decision, isA<ScheduleNext>());
    expect((decision as ScheduleNext).delayMs, 600);
  });

  test('at the notification threshold, fires the notification', () {
    // 1000ms of inactivity == the 10% threshold on a 10s timeout.
    final decision = policy.evaluate(snap(idleMs: 1000, sinceResetMs: 1000));
    expect(decision, isA<FireNotification>());
    // Unlocked: after notifying, poll every 500ms to detect the user's return.
    expect((decision as FireNotification).delayMs, 500);
  });

  test('at the timeout, fires inactive', () {
    final decision = policy.evaluate(
      snap(idleMs: 10000, sinceResetMs: 10000, isNotified: true),
    );
    expect(decision, isA<FireInactive>());
  });

  test('input newer than the reset baseline resets (no onActive before notify)',
      () {
    // idle (200ms) < sinceReset (800ms) => the user gave input 200ms ago,
    // which is more recent than our 800ms-old reset baseline.
    final decision = policy.evaluate(snap(idleMs: 200, sinceResetMs: 800));
    expect(decision, isA<ResetFromInput>());
    final reset = decision as ResetFromInput;
    expect(reset.fireOnActive, isFalse);
    // After reset, effective == idle (200ms); next check at the 1000ms mark.
    expect(reset.delayMs, 800);
  });

  test('input after a notification resets AND fires onActive', () {
    final decision = policy.evaluate(
      snap(idleMs: 200, sinceResetMs: 1500, isNotified: true),
    );
    expect(decision, isA<ResetFromInput>());
    expect((decision as ResetFromInput).fireOnActive, isTrue);
  });

  test('locked mode ignores input and keeps counting toward timeout', () {
    // idle (100ms) < sinceReset (5000ms) would normally reset, but isLocked
    // means the user is deliberately ignored until continueSession().
    final decision = policy.evaluate(
      snap(idleMs: 100, sinceResetMs: 5000, isNotified: true, isLocked: true),
    );
    expect(decision, isA<ScheduleNext>());
  });

  test('unlocked post-notification polling is capped at 500ms', () {
    final decision = policy.evaluate(
      snap(idleMs: 2000, sinceResetMs: 2000, isNotified: true),
    );
    expect((decision as ScheduleNext).delayMs, 500);
  });

  test('locked post-notification wait is floored at 1000ms', () {
    // remain is 500ms, but requireExplicitContinue floors the wait at 1000ms
    // so we do not busy-poll while input is ignored.
    final decision = policy.evaluate(snap(
      idleMs: 100,
      sinceResetMs: 9500,
      isNotified: true,
      isLocked: true,
      requireExplicitContinue: true,
    ));
    expect((decision as ScheduleNext).delayMs, 1000);
  });

  test('notifyAtMs null never fires a notification', () {
    final decision = policy.evaluate(
      snap(idleMs: 5000, sinceResetMs: 5000, notifyAtMs: null),
    );
    expect(decision, isA<ScheduleNext>());
    // Waits out the whole remaining timeout in one hop.
    expect((decision as ScheduleNext).delayMs, 5000);
  });

  test('remainingMs (unlocked) uses fresh input: timeout - min(idle, since)',
      () {
    // The user moved 2s ago (idle 2000) although our reset baseline is 5s old.
    // Unlocked, the fresher input wins: 10s - 2s = 8s left.
    final ms = policy.remainingMs(snap(idleMs: 2000, sinceResetMs: 5000));
    expect(ms, 8000);
  });

  test('remainingMs (locked) ignores input and counts from the baseline', () {
    // Locked: the recent input (idle 100) is ignored; the 9s-old baseline
    // stands, so 10s - 9s = 1s left.
    final ms = policy.remainingMs(
      snap(idleMs: 100, sinceResetMs: 9000, isLocked: true),
    );
    expect(ms, 1000);
  });

  test('remainingMs clamps to zero past the timeout', () {
    final ms = policy.remainingMs(snap(idleMs: 12000, sinceResetMs: 12000));
    expect(ms, 0);
  });
}
