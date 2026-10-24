# Effective inactivity

## The fact
"How long the user has been inactive" is `sinceResetMs` when input is locked
(explicit continue after a Notification), and `min(idleMs, sinceResetMs)`
otherwise.

## Why it is cross-cutting
Two methods compute it, separately, and neither calls the other:
`InactivityPolicy.evaluate` (as the `!s.isLocked && s.idleMs < s.sinceResetMs`
reset test, then `effective = sinceResetMs`) and `InactivityPolicy.remainingMs`
(as an explicit `effective`). If they disagree, the countdown the user sees and
the moment the timeout fires drift apart — exactly the case ADR-0003 says only
the package can get right.

## Territories it holds in
- [inactivity-decision](../territory/inactivity-decision.md) — `InactivityPolicy.evaluate`.
- [remaining-countdown](../territory/remaining-countdown.md) — `InactivityPolicy.remainingMs`.
- [explicit-continue](../territory/explicit-continue.md) — the lock that switches the formula.

## What a violation looks like
In locked mode, a countdown that jumps back to full on mouse movement while the
timeout still fires on schedule (or the reverse). Unlocked, a countdown that
keeps falling while the user types.

## Discovery history
- ADR-0003 states the formula ([ADR-0003](../../adr/0003-remaining-time-pull-api.md), *The math is pure*); tests `remainingMs (unlocked) uses fresh input` and `remainingMs (locked) ignores input` cover one site, `locked mode ignores input and keeps counting toward timeout` the other.

## Where it will recur
Any new method that reports or acts on inactivity time (a progress fraction, a
"time until Notification"). If it reads `idleMs` or `sinceResetMs`, it is subject
to this.
