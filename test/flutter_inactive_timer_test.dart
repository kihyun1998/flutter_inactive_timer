import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterInactiveTimerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterInactiveTimerPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterInactiveTimerPlatform initialPlatform = FlutterInactiveTimerPlatform.instance;

  test('$MethodChannelFlutterInactiveTimer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterInactiveTimer>());
  });

  test('getPlatformVersion', () async {
    FlutterInactiveTimer flutterInactiveTimerPlugin = FlutterInactiveTimer();
    MockFlutterInactiveTimerPlatform fakePlatform = MockFlutterInactiveTimerPlatform();
    FlutterInactiveTimerPlatform.instance = fakePlatform;

    expect(await flutterInactiveTimerPlugin.getPlatformVersion(), '42');
  });
}
