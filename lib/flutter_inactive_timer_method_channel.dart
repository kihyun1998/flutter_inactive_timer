import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_inactive_timer_platform_interface.dart';

/// An implementation of [FlutterInactiveTimerPlatform] that uses method channels.
class MethodChannelFlutterInactiveTimer extends FlutterInactiveTimerPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_inactive_timer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
