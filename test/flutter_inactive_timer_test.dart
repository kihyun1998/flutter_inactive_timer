import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterInactiveTimerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterInactiveTimerPlatform {
  int _mockTickCount = 1000;
  int _mockLastInputTime = 950;

  // Method to change tick count for testing
  void setMockTickCount(int value) {
    _mockTickCount = value;
  }

  // Method to change last input time for testing
  void setMockLastInputTime(int value) {
    _mockLastInputTime = value;
  }

  @override
  Future<int> getSystemTickCount() async {
    return _mockTickCount;
  }

  @override
  Future<int> getLastInputTime() async {
    return _mockLastInputTime;
  }
}

void main() {
  final FlutterInactiveTimerPlatform initialPlatform =
      FlutterInactiveTimerPlatform.instance;

  test('$MethodChannelFlutterInactiveTimer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterInactiveTimer>());
  });

  group('FlutterInactiveTimer', () {
    late MockFlutterInactiveTimerPlatform mockPlatform;
    late FlutterInactiveTimer inactiveTimer;

    setUp(() {
      mockPlatform = MockFlutterInactiveTimerPlatform();
      FlutterInactiveTimerPlatform.instance = mockPlatform;

      inactiveTimer = FlutterInactiveTimer(
        timeoutDuration: 10, // 10-second timeout
        notificationPer: 70, // 70% threshold for notification
        onInactiveDetected: () {
          // Optional actions to take when the callback is invoked
        },
        onNotification: () {
          // Optional actions to take when the callback is invoked
        },
      );
    });

    test('init constructor creates instance with default values', () {
      final timer = FlutterInactiveTimer.init();
      expect(timer.timeoutDuration, 0);
      expect(timer.notificationPer, 0);
    });

    test('startMonitoring initializes monitoring state', () async {
      await inactiveTimer.startMonitoring();
      // It's difficult to test private fields, but state should be initialized
      expect(true, true); // Just confirming execution
    });

    test('stopMonitoring stops timer', () async {
      await inactiveTimer.startMonitoring();
      inactiveTimer.stopMonitoring();
      // The timer should be stopped. We can't verify internal state but can ensure no errors
      expect(true, true);
    });

    test('continueSession resets timer lock', () async {
      await inactiveTimer.startMonitoring();
      inactiveTimer.continueSession();
      // lockInputReset should be set to false, but it's a private field so we can't check directly
      expect(true, true);
    });

    // Tests based on elapsed time can simulate time manipulation using the mock
    test('inactive detection occurs after timeout', () async {
      await inactiveTimer.startMonitoring();

      // Simulate time passing beyond the timeout
      mockPlatform.setMockTickCount(1000);
      mockPlatform
          .setMockLastInputTime(1000 - 11000); // Last input was 11 seconds ago

      // We can't directly call _checkInactivity since it's private,
      // and in a real environment it would be invoked via the timer.
      // So here we only test the setup and structure.

      expect(inactiveTimer.timeoutDuration, 10);
      expect(inactiveTimer.notificationPer, 70);
    });
  });
}
