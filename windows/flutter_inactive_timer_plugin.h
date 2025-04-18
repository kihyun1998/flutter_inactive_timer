#ifndef FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_inactive_timer {

class FlutterInactiveTimerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterInactiveTimerPlugin();

  virtual ~FlutterInactiveTimerPlugin();

  // Disallow copy and assign.
  FlutterInactiveTimerPlugin(const FlutterInactiveTimerPlugin&) = delete;
  FlutterInactiveTimerPlugin& operator=(const FlutterInactiveTimerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_inactive_timer

#endif  // FLUTTER_PLUGIN_FLUTTER_INACTIVE_TIMER_PLUGIN_H_
