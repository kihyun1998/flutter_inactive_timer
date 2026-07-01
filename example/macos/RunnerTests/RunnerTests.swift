import Cocoa
import FlutterMacOS
import XCTest

@testable import flutter_inactive_timer

// Unit tests for the macOS plugin's method-channel handler.
//
// See https://developer.apple.com/documentation/xctest for more information
// about using XCTest.

class RunnerTests: XCTestCase {

  // getIdleDuration reports the milliseconds since the last user input as a
  // non-negative integer (see ADR-0001). On a real macOS host IOKit's
  // HIDIdleTime is available, so this exercises the success path.
  func testGetIdleDurationReturnsNonNegativeNumber() {
    let plugin = FlutterInactiveTimerPlugin()
    let call = FlutterMethodCall(methodName: "getIdleDuration", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      if let number = result as? NSNumber {
        XCTAssertGreaterThanOrEqual(number.int64Value, 0)
      } else {
        XCTFail("expected a numeric idle duration, got \(String(describing: result))")
      }
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  // An unknown method is reported as not-implemented.
  func testUnknownMethodIsNotImplemented() {
    let plugin = FlutterInactiveTimerPlugin()
    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertTrue((result as AnyObject) === FlutterMethodNotImplemented)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }
}
