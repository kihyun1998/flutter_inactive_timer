import Cocoa
import FlutterMacOS
import IOKit
import IOKit.hid

// Main plugin class for Flutter on macOS
public class FlutterInactiveTimerPlugin: NSObject, FlutterPlugin {

  // Register the plugin with Flutter
  public static func register(with registrar: FlutterPluginRegistrar) {
    // Create a method channel for communication between Flutter and native macOS
    let channel = FlutterMethodChannel(name: "flutter_inactive_timer", binaryMessenger: registrar.messenger)
    let instance = FlutterInactiveTimerPlugin()
    // Set the delegate to handle method calls from Flutter
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // Handle method calls from Flutter
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getSystemTickCount":
      // Return system uptime in milliseconds
      result(getSystemUptimeInMilliseconds())

    case "getLastInputTime":
      // Return the last user input time if available
      if let lastInput = getLastInputTime() {
        result(lastInput)
      } else {
        result(FlutterError(code: "UNAVAILABLE", message: "Cannot get last input time", details: nil))
      }

    default:
      // Method not implemented
      result(FlutterMethodNotImplemented)
    }
  }

  // Get the system uptime since last boot in milliseconds
  private func getSystemUptimeInMilliseconds() -> UInt64 {
    let uptime = ProcessInfo.processInfo.systemUptime
    return UInt64(uptime * 1000)
  }

  // Get the last time the user provided input (keyboard/mouse) in milliseconds
  private func getLastInputTime() -> UInt64? {
    var iterator = io_iterator_t()
    let matchingDict = IOServiceMatching("IOHIDSystem")

    // Get an iterator for matching services
    guard IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
      return nil
    }

    // Get the first matching entry
    let entry = IOIteratorNext(iterator)
    IOObjectRelease(iterator)

    guard entry != 0 else { return nil }

    var properties: Unmanaged<CFMutableDictionary>?

    // Fetch the HID properties dictionary
    guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let dict = properties?.takeRetainedValue() as? [String: AnyObject],
          let hidIdleTime = dict["HIDIdleTime"] as? UInt64 else {
      IOObjectRelease(entry)
      return nil
    }

    IOObjectRelease(entry)

    // Convert HIDIdleTime from nanoseconds to milliseconds
    let idleMillis = hidIdleTime / 1_000_000

    // Subtract idle time from system uptime to get the last input time
    return getSystemUptimeInMilliseconds() - idleMillis
  }
}
