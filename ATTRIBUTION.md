# Source and license

This distribution is provided under GNU GPL version 3, included as LICENSE.

HIDPP.swift is adapted from APKiwi/Squeak's Sources/HIDPPKit/HIDPP.swift:
https://github.com/APKiwi/Squeak

Upstream revision: c644e241e61a61fa14ab6ab01d29d9d68b110a35

Local changes dated 2026-11-14 include mouse/trackball filtering, scanning receiver slots 1–6, rotating software transaction tags and matching complete command bytes to reject delayed responses, accepting zero-percent unified readings, and integration with a separate power-source publication implementation in main.swift.

main.swift implements the local single-process polling and macOS accessory power-source publication, including a short retry and bounded five-minute retention of last successful readings after transient failures. Connection registry IDs are carried with readings. IOKit termination notifications withdraw records for removed connections, with synchronization and guards against late scan results. The complete source required to build this executable is included in this directory.

Local changes dated 2026-11-17 activate an independent HID manager for topology notifications, reconcile removed and added registry IDs on every scan, debounce reconnect-triggered polls, and cancel each HID device before releasing its per-device report buffer. Callback contexts hold weak owners and are retained until cancellation completes. Reconnect regression checks are included in tests/.

Version 1.1.0 adds Dashboard.swift (AppKit/SwiftUI), a native main window, status-item menu, single-instance window activation, manual refresh, visible reading age, and graceful UI termination. The HID polling and accessory power publication remain in the same process.

Version 1.2.0 adds a locally drawn native mouse app icon, a template mouse status icon, a name-editing sheet, and atomic persistence of per-device display aliases. Power-source names can be updated without refreshing the battery reading age. The original HID device identity and reported name are preserved.

Version 1.3.0 adds a persistent menu bar icon visibility setting, uses the Dock icon as the entry point when the menu bar icon is hidden, and enlarges the mouse-name edit button.

Version 1.3.1 hides the Dock icon along with the menu bar icon, including when reopening the window from Finder, while retaining background battery publication.
