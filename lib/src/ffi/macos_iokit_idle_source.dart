import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'idle_source.dart';

// --- IOKit and CoreFoundation types, in Dart terms ---------------------------
//
// `mach_port_t` and everything derived from it (`io_iterator_t`, `io_object_t`,
// `io_registry_entry_t`) are 32-bit unsigned handles, *not* pointers — passing
// them as pointers would compile and then corrupt the stack. `kern_return_t` is
// a 32-bit signed status where zero means success.

const int _kernSuccess = 0;

/// The default IOKit port. Documented as `MACH_PORT_NULL`, so a literal zero is
/// the value — looking the symbol up by name would be worse, since it was
/// renamed from `kIOMasterPortDefault` to `kIOMainPortDefault` in macOS 12 and
/// a name lookup would fail on one side of that.
const int _defaultIoPort = 0;

/// `kCFStringEncodingUTF8`.
const int _cfStringEncodingUtf8 = 0x08000100;

/// `kCFNumberSInt64Type`. `HIDIdleTime` is a 64-bit nanosecond count.
const int _cfNumberSInt64Type = 4;

typedef _IOServiceMatchingC = Pointer<Void> Function(Pointer<Utf8>);
typedef _IOServiceMatchingDart = Pointer<Void> Function(Pointer<Utf8>);

typedef _IOServiceGetMatchingServicesC = Int32 Function(
    Uint32, Pointer<Void>, Pointer<Uint32>);
typedef _IOServiceGetMatchingServicesDart = int Function(
    int, Pointer<Void>, Pointer<Uint32>);

typedef _IOIteratorNextC = Uint32 Function(Uint32);
typedef _IOIteratorNextDart = int Function(int);

typedef _IOObjectReleaseC = Int32 Function(Uint32);
typedef _IOObjectReleaseDart = int Function(int);

typedef _IORegistryEntryCreateCFPropertiesC = Int32 Function(
    Uint32, Pointer<Pointer<Void>>, Pointer<Void>, Uint32);
typedef _IORegistryEntryCreateCFPropertiesDart = int Function(
    int, Pointer<Pointer<Void>>, Pointer<Void>, int);

typedef _CFStringCreateWithCStringC = Pointer<Void> Function(
    Pointer<Void>, Pointer<Utf8>, Uint32);
typedef _CFStringCreateWithCStringDart = Pointer<Void> Function(
    Pointer<Void>, Pointer<Utf8>, int);

typedef _CFDictionaryGetValueC = Pointer<Void> Function(
    Pointer<Void>, Pointer<Void>);
typedef _CFDictionaryGetValueDart = Pointer<Void> Function(
    Pointer<Void>, Pointer<Void>);

// `Boolean` is a single byte, and `CFNumberType` is a `CFIndex`, which is 64-bit
// signed — not the 32-bit `int` a C enum would normally be.
typedef _CFNumberGetValueC = Uint8 Function(
    Pointer<Void>, Int64, Pointer<Int64>);
typedef _CFNumberGetValueDart = int Function(
    Pointer<Void>, int, Pointer<Int64>);

typedef _CFReleaseC = Void Function(Pointer<Void>);
typedef _CFReleaseDart = void Function(Pointer<Void>);

// Resolved on first use, so this file stays importable — and its arithmetic
// testable — on a CI host that is not macOS.
// coverage:ignore-start
final DynamicLibrary _ioKit = DynamicLibrary.open(
  '/System/Library/Frameworks/IOKit.framework/IOKit',
);

final DynamicLibrary _coreFoundation = DynamicLibrary.open(
  '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
);

final _ioServiceMatching =
    _ioKit.lookupFunction<_IOServiceMatchingC, _IOServiceMatchingDart>(
  'IOServiceMatching',
);

final _ioServiceGetMatchingServices = _ioKit.lookupFunction<
    _IOServiceGetMatchingServicesC,
    _IOServiceGetMatchingServicesDart>('IOServiceGetMatchingServices');

final _ioIteratorNext =
    _ioKit.lookupFunction<_IOIteratorNextC, _IOIteratorNextDart>(
  'IOIteratorNext',
);

final _ioObjectRelease =
    _ioKit.lookupFunction<_IOObjectReleaseC, _IOObjectReleaseDart>(
  'IOObjectRelease',
);

final _ioRegistryEntryCreateCFProperties = _ioKit.lookupFunction<
        _IORegistryEntryCreateCFPropertiesC,
        _IORegistryEntryCreateCFPropertiesDart>(
    'IORegistryEntryCreateCFProperties');

final _cfStringCreateWithCString = _coreFoundation.lookupFunction<
    _CFStringCreateWithCStringC,
    _CFStringCreateWithCStringDart>('CFStringCreateWithCString');

final _cfDictionaryGetValue = _coreFoundation
    .lookupFunction<_CFDictionaryGetValueC, _CFDictionaryGetValueDart>(
  'CFDictionaryGetValue',
);

final _cfNumberGetValue =
    _coreFoundation.lookupFunction<_CFNumberGetValueC, _CFNumberGetValueDart>(
  'CFNumberGetValue',
);

final _cfRelease = _coreFoundation.lookupFunction<_CFReleaseC, _CFReleaseDart>(
  'CFRelease',
);
// coverage:ignore-end

/// Reads the Idle duration on macOS through IOKit — the HID system service's
/// `HIDIdleTime` property — via `dart:ffi` (ADR-0004).
///
/// One of two candidates; the other is `MacOsCoreGraphicsIdleSource`. This one
/// walks the same path the retired Swift plugin walked, which is why it is
/// first in resolution order: whatever the measurement in #22 shows, its values
/// cannot disagree with the implementation being replaced. The cost is the
/// walk itself — service lookup, iterator, property dictionary, dictionary
/// lookup, number unboxing — where Swift's bridging did the work implicitly.
class MacOsIoKitIdleSource extends IdleSource {
  const MacOsIoKitIdleSource();

  static const int _nanosecondsPerMillisecond = 1000000;

  @override
  String get name => 'macos/IOKit-HIDIdleTime';

  @override
  bool get isSupported => true;

  /// The Idle duration implied by one `HIDIdleTime` reading, including what to
  /// report when the walk did not complete.
  ///
  /// **Truncating division, not rounding.** The retired Swift divided integers,
  /// so 1.999 ms read as 1 ms; rounding here would be an improvement, and an
  /// improvement is a behavior change. A negative reading is clamped — it
  /// should be impossible, but a negative idle duration would read to the
  /// policy as input arriving in the future.
  ///
  /// **When [succeeded] is false the answer is zero — the user is treated as
  /// active.** The shell catches a thrown read as a transient fault and
  /// retries, so throwing on a persistently failing lookup would stall
  /// monitoring rather than degrade it.
  @visibleForTesting
  static int idleFromNanoseconds({
    required bool succeeded,
    required int nanoseconds,
  }) {
    if (!succeeded || nanoseconds <= 0) return 0;
    return nanoseconds ~/ _nanosecondsPerMillisecond;
  }

  // coverage:ignore-start
  @override
  int idleMilliseconds() {
    final nanoseconds = _readIdleNanoseconds();
    return idleFromNanoseconds(
      succeeded: nanoseconds != null,
      nanoseconds: nanoseconds ?? 0,
    );
  }

  /// Walks the IO registry to `IOHIDSystem`'s `HIDIdleTime`, or returns null if
  /// any step fails.
  ///
  /// Ownership differs at every step and two of them are traps:
  ///
  /// - The matching dictionary from `IOServiceMatching` is **not released
  ///   here** — `IOServiceGetMatchingServices` consumes the reference, whether
  ///   it succeeds or fails. Releasing it as well would be an over-release.
  /// - The value from `CFDictionaryGetValue` is **borrowed**, not owned.
  ///   Releasing it would free something the dictionary still points at.
  ///
  /// Everything else — the iterator, the service entry, the created property
  /// dictionary, the created key string — is owned and released on every path,
  /// including the early returns. This runs on every poll for the life of the
  /// app, so a single missed release is a leak that grows all day.
  int? _readIdleNanoseconds() {
    final serviceName = 'IOHIDSystem'.toNativeUtf8();
    final iteratorOut = calloc<Uint32>();
    try {
      final matching = _ioServiceMatching(serviceName);
      if (matching == nullptr) return null;

      // Consumes `matching`. Do not release it, on either outcome.
      if (_ioServiceGetMatchingServices(
            _defaultIoPort,
            matching,
            iteratorOut,
          ) !=
          _kernSuccess) {
        return null;
      }

      final iterator = iteratorOut.value;
      final entry = _ioIteratorNext(iterator);
      _ioObjectRelease(iterator);
      if (entry == 0) return null;

      try {
        return _readIdleNanosecondsFrom(entry);
      } finally {
        _ioObjectRelease(entry);
      }
    } finally {
      calloc.free(iteratorOut);
      malloc.free(serviceName); // toNativeUtf8 allocates with malloc
    }
  }

  /// Pulls `HIDIdleTime` out of one registry entry's properties.
  int? _readIdleNanosecondsFrom(int entry) {
    final propertiesOut = calloc<Pointer<Void>>();
    try {
      if (_ioRegistryEntryCreateCFProperties(
            entry,
            propertiesOut,
            nullptr, // kCFAllocatorDefault
            0,
          ) !=
          _kernSuccess) {
        return null;
      }

      final properties = propertiesOut.value;
      if (properties == nullptr) return null;

      try {
        return _readIdleNanosecondsFromProperties(properties);
      } finally {
        _cfRelease(properties);
      }
    } finally {
      calloc.free(propertiesOut);
    }
  }

  /// Looks up the `HIDIdleTime` key and unboxes the number behind it.
  int? _readIdleNanosecondsFromProperties(Pointer<Void> properties) {
    final keyName = 'HIDIdleTime'.toNativeUtf8();
    final valueOut = calloc<Int64>();
    Pointer<Void> key = nullptr;
    try {
      key = _cfStringCreateWithCString(
        nullptr, // kCFAllocatorDefault
        keyName,
        _cfStringEncodingUtf8,
      );
      if (key == nullptr) return null;

      // Borrowed — belongs to the dictionary, must not be released.
      final value = _cfDictionaryGetValue(properties, key);
      if (value == nullptr) return null;

      if (_cfNumberGetValue(value, _cfNumberSInt64Type, valueOut) == 0) {
        return null;
      }
      return valueOut.value;
    } finally {
      if (key != nullptr) _cfRelease(key);
      calloc.free(valueOut);
      malloc.free(keyName); // toNativeUtf8 allocates with malloc
    }
  }
  // coverage:ignore-end
}
