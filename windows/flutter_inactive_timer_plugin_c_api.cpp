#include "include/flutter_inactive_timer/flutter_inactive_timer_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_inactive_timer_plugin.h"

void FlutterInactiveTimerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_inactive_timer::FlutterInactiveTimerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
