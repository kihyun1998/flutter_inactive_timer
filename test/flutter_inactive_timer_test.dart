import 'package:flutter_inactive_timer/flutter_inactive_timer_method_channel.dart';
import 'package:flutter_inactive_timer/flutter_inactive_timer_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterInactiveTimerPlatform
    with MockPlatformInterfaceMixin
    implements FlutterInactiveTimerPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<int> getLastInputTime() {
    // TODO: implement getLastInputTime
    throw UnimplementedError();
  }

  @override
  Future<int> getSystemTickCount() {
    // TODO: implement getSystemTickCount
    throw UnimplementedError();
  }
}

void main() {
  final FlutterInactiveTimerPlatform initialPlatform =
      FlutterInactiveTimerPlatform.instance;

  test('$MethodChannelFlutterInactiveTimer is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterInactiveTimer>());
  });
}
