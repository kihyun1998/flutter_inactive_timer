import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_inactive_timer_method_channel.dart';

abstract class FlutterInactiveTimerPlatform extends PlatformInterface {
  /// Constructs a FlutterInactiveTimerPlatform.
  FlutterInactiveTimerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterInactiveTimerPlatform _instance =
      MethodChannelFlutterInactiveTimer();

  /// The default instance of [FlutterInactiveTimerPlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterInactiveTimer].
  static FlutterInactiveTimerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterInactiveTimerPlatform] when
  /// they register themselves.
  static set instance(FlutterInactiveTimerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
