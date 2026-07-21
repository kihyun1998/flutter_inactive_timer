import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'flutter_inactive_timer_ffi.dart';

abstract class FlutterInactiveTimerPlatform extends PlatformInterface {
  /// Constructs a FlutterInactiveTimerPlatform.
  FlutterInactiveTimerPlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterInactiveTimerPlatform _instance = FfiFlutterInactiveTimer();

  /// The default instance of [FlutterInactiveTimerPlatform] to use.
  ///
  /// Defaults to [FfiFlutterInactiveTimer], which reads the idle duration
  /// straight from the OS through `dart:ffi` (ADR-0004). It replaced a
  /// method-channel implementation backed by Swift and C++; both reported the
  /// same value on every platform before the swap, and the CI parity runs that
  /// proved it are recorded in ADR-0004.
  static FlutterInactiveTimerPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterInactiveTimerPlatform] when
  /// they register themselves.
  static set instance(FlutterInactiveTimerPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Milliseconds since the user's last keyboard or mouse input, computed
  /// natively per platform. See ADR-0001.
  Future<int> getIdleDuration() {
    throw UnimplementedError('getIdleDuration() has not been implemented.');
  }
}
