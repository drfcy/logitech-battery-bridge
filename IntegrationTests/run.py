#!/usr/bin/env python3
"""Run against a connected, awake Logitech receiver mouse. Does not reset USB."""
from pathlib import Path
import subprocess
import os
import tempfile
source = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix='bridge-reconnect-tests-') as tmp:
    tmp = Path(tmp)
    # Reuse the exact production publisher without starting the background app.
    publisher = (source / 'main.swift').read_text().split('// IOKit termination notifications')[0]
    (tmp / 'Publisher.swift').write_text(publisher)
    subprocess.run(['xcrun', 'swiftc', *(['-sdk', os.environ['SDKROOT']] if os.environ.get('SDKROOT') else []), '-target', 'arm64-apple-macos14.0', '-D', 'HOTPLUG_TESTING', '-framework', 'IOKit',
                    str(source / 'HIDPP.swift'), str(source / 'Dashboard.swift'), str(source / 'DeviceNames.swift'), str(tmp / 'Publisher.swift'),
                    str(source / 'tests/main.swift'), '-o', str(tmp / 'test')], check=True)
    subprocess.run([str(tmp / 'test')], check=True)
