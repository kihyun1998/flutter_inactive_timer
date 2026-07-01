#include "flutter_inactive_timer_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace flutter_inactive_timer {

// static
void FlutterInactiveTimerPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_inactive_timer",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterInactiveTimerPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterInactiveTimerPlugin::FlutterInactiveTimerPlugin() {}

FlutterInactiveTimerPlugin::~FlutterInactiveTimerPlugin() {}

void FlutterInactiveTimerPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getIdleDuration") == 0) {
    // Milliseconds since the last user input (see ADR-0001).
    LASTINPUTINFO lastInputInfo;
    lastInputInfo.cbSize = sizeof(LASTINPUTINFO);

    if (GetLastInputInfo(&lastInputInfo)) {
      // dwTime is the low 32 bits of the tick clock at the last input. Taking
      // the same low 32 bits of GetTickCount64() and subtracting (unsigned)
      // yields the idle duration correctly modulo 2^32 - no cross-clock or
      // wraparound bug, since a real idle span never exceeds ~49.7 days.
      DWORD nowLow = static_cast<DWORD>(GetTickCount64());
      DWORD idle = nowLow - lastInputInfo.dwTime;
      result->Success(flutter::EncodableValue(static_cast<int64_t>(idle)));
    } else {
      // On error, report zero idle (treat as active) rather than failing.
      result->Success(flutter::EncodableValue(static_cast<int64_t>(0)));
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_inactive_timer
