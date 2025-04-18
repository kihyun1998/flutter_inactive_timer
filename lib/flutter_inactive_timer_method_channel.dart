import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_inactive_timer_platform_interface.dart';

/// An implementation of [FlutterInactiveTimerPlatform] that uses method channels.
class MethodChannelFlutterInactiveTimer extends FlutterInactiveTimerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_inactive_timer');

  @override
  Future<int> getSystemTickCount() async {
    final int tickCount =
        await methodChannel.invokeMethod<int>('getSystemTickCount') ?? 0;
    return tickCount;
  }

  @override
  Future<int> getLastInputTime() async {
    final int lastInputTime =
        await methodChannel.invokeMethod<int>('getLastInputTime') ?? 0;
    return lastInputTime;
  }
}
