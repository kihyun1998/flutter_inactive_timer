import Cocoa
import FlutterMacOS
import IOKit
import IOKit.hid

public class FlutterInactiveTimerPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_inactive_timer", binaryMessenger: registrar.messenger)
    let instance = FlutterInactiveTimerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getSystemTickCount":
      result(getSystemUptimeInMilliseconds())
    case "getLastInputTime":
      if let lastInput = getLastInputTime(){
        result(lastInput)
      }else {
        result(FlutterError(code: "UNAVAILABLE", message: "Cannot get last input time", details: nil))
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getSystemUptimeInMilliseconds() -> UInt64{
    let uptime = ProcessInfo.processInfo.systemUptime
    return UInt64(uptime * 1000)
  }

  private func getLastInputTime() -> UInt64? {
    var iterator = io_iterator_t()
    let matchingDict = IOServiceMatching("IOHIDSystem")

    guard IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
      return nil
    }

    let entry =  IOIteratorNext(iterator)
    IOObjectRelease(iterator)
    guard entry != 0 else { return nil }

    var properties: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(entry, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let dict = properties?.takeRetainedValue() as? [String: AnyObject],
          let hidIdleTime = dict["HIDIdleTime"] as? UInt64 else {
      IOObjectRelease(entry)
      return nil
    }

    IOObjectRelease(entry)

    let idleMillis = hidIdleTime / 1_000_000
    return getSystemUptimeInMilliseconds() - idleMillis

  }
}
