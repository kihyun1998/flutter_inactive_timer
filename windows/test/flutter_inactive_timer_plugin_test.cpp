#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "flutter_inactive_timer_plugin.h"

namespace flutter_inactive_timer {
namespace test {

namespace {

using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

// Captures the outcome of a single HandleMethodCall invocation so tests can
// assert on observable behavior (success / error / not-implemented) rather than
// internals.
struct CallOutcome {
  bool succeeded = false;
  bool errored = false;
  std::string error_code;
  EncodableValue value;
};

CallOutcome Invoke(FlutterInactiveTimerPlugin& plugin, const std::string& method,
                   std::unique_ptr<EncodableValue> arguments) {
  CallOutcome outcome;
  auto result = std::make_unique<MethodResultFunctions<>>(
      [&outcome](const EncodableValue* value) {
        outcome.succeeded = true;
        if (value) outcome.value = *value;
      },
      [&outcome](const std::string& code, const std::string& /*message*/,
                 const EncodableValue* /*details*/) {
        outcome.errored = true;
        outcome.error_code = code;
      },
      nullptr);
  plugin.HandleMethodCall(MethodCall(method, std::move(arguments)),
                          std::move(result));
  return outcome;
}

}  // namespace

// getIdleDuration reports the milliseconds since the last user input as a
// non-negative integer (see ADR-0001). On a CI runner GetLastInputInfo is
// available, so this exercises the success path.
TEST(FlutterInactiveTimerPlugin, GetIdleDurationReturnsNonNegativeInt) {
  FlutterInactiveTimerPlugin plugin;
  auto outcome =
      Invoke(plugin, "getIdleDuration", std::make_unique<EncodableValue>());

  EXPECT_TRUE(outcome.succeeded);
  EXPECT_FALSE(outcome.errored);
  ASSERT_TRUE(std::holds_alternative<int64_t>(outcome.value));
  EXPECT_GE(std::get<int64_t>(outcome.value), 0);
}

// An unknown method is reported as not-implemented: neither the success nor the
// error callback is delivered.
TEST(FlutterInactiveTimerPlugin, UnknownMethodIsNotImplemented) {
  FlutterInactiveTimerPlugin plugin;
  auto outcome =
      Invoke(plugin, "getPlatformVersion", std::make_unique<EncodableValue>());

  EXPECT_FALSE(outcome.succeeded);
  EXPECT_FALSE(outcome.errored);
}

}  // namespace test
}  // namespace flutter_inactive_timer
