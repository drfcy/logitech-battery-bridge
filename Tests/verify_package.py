#!/usr/bin/env python3
"""Validate an installer without installing it or requiring administrator access."""
import pathlib
import plistlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

package = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='battery-package-check-') as temporary:
    expanded = pathlib.Path(temporary) / 'expanded'
    subprocess.run(['pkgutil', '--expand-full', str(package), str(expanded)], check=True)
    payload = expanded / 'BridgeComponent.pkg/Payload'
    app = payload / 'Applications/LogitechBatteryBridge.app'
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    executable = app / 'Contents/MacOS/LogitechBatteryBridge'
    build = subprocess.check_output(['vtool', '-show-build', str(executable)], text=True)
    assert 'minos 14.0' in build, build
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    assert info['LSMinimumSystemVersion'] == '14.0'
    assert info['CFBundleShortVersionString'] == '1.3.1'
    agent = plistlib.loads((payload / 'Library/LaunchAgents/local.logitech.batterybridge.plist').read_bytes())
    assert agent['ProgramArguments'] == ['/Applications/LogitechBatteryBridge.app/Contents/MacOS/LogitechBatteryBridge', '--log-to-file', '--background']
    assert agent['RunAtLoad'] and agent['KeepAlive']['SuccessfulExit'] is False
    dist = ET.parse(expanded / 'Distribution').getroot()
    assert dist.find('options').get('hostArchitectures') == 'arm64'
    assert dist.find('volume-check/allowed-os-versions/os-version').get('min') == '14.0'
    assert (app / 'Contents/Resources/Source/LICENSE').is_file()
    assert (app / 'Contents/Resources/Source/HIDPP.swift').is_file()
    assert (app / 'Contents/Resources/Source/Dashboard.swift').is_file()
    assert (app / 'Contents/Resources/Source/DeviceNames.swift').is_file()
    assert (app / 'Contents/Resources/AppIcon.icns').is_file()
    assert (app / 'Contents/Resources/卸载.command').stat().st_mode & 0o111
    preinstall = (expanded / 'BridgeComponent.pkg/Scripts/preinstall').read_text()
    assert '"$major_version" -lt 14' in preinstall
print('PASS: installer metadata, deployment target, app signature, launch agent and bundled sources')
