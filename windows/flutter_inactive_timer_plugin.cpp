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
  if (method_call.method_name().compare("getSystemTickCount") == 0) {
    // Use GetTickCount64 to avoid overflow issues with GetTickCount
    ULONGLONG tickCount = GetTickCount64();
    // Convert to int64_t for EncodableValue
    int64_t ticks = static_cast<int64_t>(tickCount);
    result->Success(flutter::EncodableValue(ticks));
  } else if (method_call.method_name().compare("getLastInputTime") == 0) {
    LASTINPUTINFO lastInputInfo;
    lastInputInfo.cbSize = sizeof(LASTINPUTINFO);
    
    if (GetLastInputInfo(&lastInputInfo)) {
      // GetLastInputInfo returns a tick count, convert to int64_t for EncodableValue
      int64_t lastInput = static_cast<int64_t>(lastInputInfo.dwTime);
      result->Success(flutter::EncodableValue(lastInput));
    } else {
      // In case of error, return current tick count
      ULONGLONG tickCount = GetTickCount64();
      int64_t ticks = static_cast<int64_t>(tickCount);
      result->Success(flutter::EncodableValue(ticks));
    }
  } else {
    result->NotImplemented();
  }
}

}  // namespace flutter_inactive_timer
