# Source and license

This distribution is provided under GNU GPL version 3, included as LICENSE.

HIDPP.swift is adapted from APKiwi/Squeak's Sources/HIDPPKit/HIDPP.swift:
https://github.com/APKiwi/Squeak

Upstream revision: c644e241e61a61fa14ab6ab01d29d9d68b110a35

Local changes dated 2026-11-14 include mouse/trackball filtering, scanning receiver slots 1–6, rotating software transaction tags and matching complete command bytes to reject delayed responses, accepting zero-percent unified readings, and integration with a separate power-source publication implementation in main.swift.

main.swift implements the local single-process polling and macOS accessory power-source publication, including a short retry and bounded five-minute retention of last successful readings after transient failures. Connection registry IDs are carried with readings. IOKit termination notifications withdraw records for removed connections, with synchronization and guards against late scan results. The complete source required to build this executable is included in this directory.
