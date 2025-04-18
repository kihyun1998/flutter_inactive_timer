import 'flutter_inactive_timer_platform_interface.dart';

class FlutterInactiveTimer {
  Future<String?> getPlatformVersion() {
    return FlutterInactiveTimerPlatform.instance.getPlatformVersion();
  }
}
