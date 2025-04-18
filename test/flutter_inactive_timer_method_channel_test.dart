import 'package:flutter/services.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelFlutterInactiveTimer platform =
      MethodChannelFlutterInactiveTimer();
  const MethodChannel channel = MethodChannel('flutter_inactive_timer');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'getSystemTickCount':
            return 1000;
          case 'getLastInputTime':
            return 950;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getSystemTickCount', () async {
    expect(await platform.getSystemTickCount(), 1000);
  });

  test('getLastInputTime', () async {
    expect(await platform.getLastInputTime(), 950);
  });
}
