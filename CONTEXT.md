# Flutter Inactive Timer

A cross-platform (macOS, Windows) Flutter plugin that detects user inactivity — no keyboard or mouse input — and fires callbacks at a warning threshold and at timeout.

## Language

**Monitoring**:
The active state in which the plugin is watching for inactivity. Started with `startMonitoring`, ended with `stopMonitoring`.

**Inactive**:
The terminal state reached when the user has produced no input for the full timeout duration. Fires `onInactiveDetected` and ends monitoring.
_Avoid_: idle, timed-out

**Notification**:
The warning fired once when inactivity crosses the configured NotificationTrigger, before reaching Inactive. Fires `onNotification`.
_Avoid_: alert, warning

**NotificationTrigger**:
When the Notification fires, relative to the timeout. A sealed type: `NotifyAtPercent` (a percentage of the timeout) or `NotifyBefore` (a fixed `Duration` lead time before it). Never both — the two are the same value. `null` means no Notification. The shell resolves it to a single millisecond offset before it reaches InactivityPolicy, so the policy is agnostic to the kind. See ADR-0002.
_Avoid_: notification mode, threshold type

**Explicit continue**:
The mode (`requireExplicitContinue`) in which, after a Notification, only a `continueSession` call resets the timer — user input alone is ignored.

**Idle duration**:
Milliseconds since the user's last keyboard or mouse input, computed natively per platform and returned as a single value. The one time quantity the rest of the system reasons about — see ADR-0001.
_Avoid_: inactive time, elapsed time

**InactivityPolicy**:
The pure decision rule that, given the current values (idle duration, config, whether a Notification already fired), returns an InactivityDecision. Side-effect free — owns no timer and makes no platform calls.
_Avoid_: evaluator, state machine

**InactivityDecision**:
The value returned by InactivityPolicy describing what the shell should do next — schedule the next check, fire the Notification, fire Inactive, or reset. A sealed/closed set of outcomes.
_Avoid_: action, command, event
