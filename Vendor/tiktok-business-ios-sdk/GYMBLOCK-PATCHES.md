# TikTok Business SDK 1.7.2, patched for GymBlock

Upstream: https://github.com/tiktok/tiktok-business-ios-sdk, tag `1.7.2`
(`2a3a35560c2c0547f74869c58160946e29c0932c`), MIT (LICENSE). Copied on 2 Nov 2026: `LICENSE`,
`Package.swift`, `PrivacyInfo.xcprivacy` and `TikTokBusinessSDK/`, nothing else.

Two changes, each marked `GymBlock patch` in the source (and `Package.swift` drops its two test
targets, whose folders aren't copied):

1. `Core/TikTokDebugInfo.m`, `+debugInfo` returns an empty dictionary. Upstream attaches it to the
   settings requests the SDK makes at every launch: the boot time (Apple allows no reason to send it
   off the device), the boot times seen before, memory, CPU count, screen resolution and time zone.
2. `Core/TikTokBusiness.m`, `-setUpCrashMonitor` returns at once. TikTok's remote config can turn on
   a crash reporter whose reports carry the boot time and disk space.

The events are untouched: install, launch, retention, Registration, StartTrial and Subscribe go out
with the same device fields as upstream (IDFV, IP, user agent, locale, model, iOS version; the IDFA
stays empty with no ATT prompt).

To update: copy the new tag's same four paths over this folder, re-apply both patches (check
`kern.boottime`, `systemUptime` and `NSFileSystemSize` uses again), and update the tag above.
