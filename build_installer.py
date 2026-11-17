#!/usr/bin/env python3
"""Build the unsigned macOS Installer package. Requires Xcode command-line tools."""
import argparse
import os
import pathlib
import plistlib
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

SOURCE = pathlib.Path(__file__).resolve().parent
VERSION = '1.3.1'
MINIMUM_OS = '14.0'
NAME = 'LogitechBatteryBridge'
LABEL = 'local.logitech.batterybridge'
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=pathlib.Path, default=SOURCE / 'dist' / f'{NAME}-{VERSION}-macOS14plus-arm64.pkg')
parser.add_argument('--app-output', type=pathlib.Path, help='Also copy the built app to this path')
parser.add_argument('--sdk', default=os.environ.get('SDKROOT'), help='Optional SDK path for Swift compilation')
args = parser.parse_args()
output = args.output.resolve()
output.parent.mkdir(parents=True, exist_ok=True)

def run(*argv):
    subprocess.run([str(x) for x in argv], check=True)

def plist(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('wb') as f:
        plistlib.dump(value, f)

with tempfile.TemporaryDirectory(prefix='logitech-battery-package-') as directory:
    stage = pathlib.Path(directory)
    root = stage / 'root'
    app = root / 'Applications' / f'{NAME}.app'
    contents = app / 'Contents'
    executable = contents / 'MacOS' / NAME
    executable.parent.mkdir(parents=True)
    resources = contents / 'Resources'
    sources = resources / 'Source'
    sources.mkdir(parents=True)
    for name in ['HIDPP.swift', 'Dashboard.swift', 'DeviceNames.swift', 'make_icon.swift', 'main.swift', 'LICENSE', 'ATTRIBUTION.md', 'build_installer.py']:
        shutil.copy2(SOURCE / name, sources / name)
    shutil.copytree(SOURCE / 'packaging', sources / 'packaging')
    shutil.copytree(SOURCE / 'IntegrationTests', sources / 'IntegrationTests')
    shutil.copy2(SOURCE / 'packaging' / 'uninstall.command', resources / '卸载.command')
    readme = SOURCE / '安装说明.md'
    if readme.exists():
        shutil.copy2(readme, resources / readme.name)
    plist(contents / 'Info.plist', {
        'CFBundleIdentifier': LABEL,
        'CFBundleName': 'Logitech Battery Bridge',
        'CFBundleDisplayName': '罗技电量桥接',
        'CFBundleExecutable': NAME,
        'CFBundleIconFile': 'AppIcon',
        'CFBundlePackageType': 'APPL',
        'CFBundleShortVersionString': VERSION,
        'CFBundleVersion': VERSION,
        'LSMinimumSystemVersion': MINIMUM_OS,
        'LSUIElement': True,
        'NSHighResolutionCapable': True,
        'NSInputMonitoringUsageDescription': '读取罗技鼠标接收器报告的电量与充电状态。',
    })
    run('swiftc', *(['-sdk', args.sdk] if args.sdk else []), '-O', '-target', f'arm64-apple-macos{MINIMUM_OS}', '-framework', 'IOKit', '-framework', 'AppKit', '-framework', 'SwiftUI',
        SOURCE / 'HIDPP.swift', SOURCE / 'Dashboard.swift', SOURCE / 'DeviceNames.swift', SOURCE / 'main.swift', '-o', executable)
    iconset = stage / 'AppIcon.iconset'
    run('swift', SOURCE / 'make_icon.swift', iconset)
    run('iconutil', '-c', 'icns', iconset, '-o', resources / 'AppIcon.icns')
    run('codesign', '--force', '--sign', '-', app)
    if args.app_output:
        shutil.copytree(app, args.app_output)
    # No paths here depend on the username of the build machine.
    plist(root / 'Library' / 'LaunchAgents' / f'{LABEL}.plist', {
        'Label': LABEL,
        'ProgramArguments': [f'/Applications/{NAME}.app/Contents/MacOS/{NAME}', '--log-to-file', '--background'],
        'RunAtLoad': True,
        'KeepAlive': {'SuccessfulExit': False},
        'ThrottleInterval': 15,
        'LimitLoadToSessionType': 'Aqua',
        'ProcessType': 'Background',
    })
    scripts = stage / 'scripts'
    scripts.mkdir()
    for name in ['preinstall', 'postinstall']:
        shutil.copy2(SOURCE / 'packaging' / name, scripts / name)
    components = stage / 'components.plist'
    run('pkgbuild', '--analyze', '--root', root, components)
    with components.open('rb') as f:
        bundles = plistlib.load(f)
    for bundle in bundles:
        bundle['BundleIsRelocatable'] = False
        bundle['BundleOverwriteAction'] = 'upgrade'
    plist(components, bundles)
    component = stage / 'BridgeComponent.pkg'
    run('pkgbuild', '--root', root, '--component-plist', components,
        '--scripts', scripts, '--identifier', LABEL + '.pkg', '--version', VERSION,
        '--install-location', '/', '--ownership', 'recommended', component)
    requirements = stage / 'requirements.plist'
    plist(requirements, {'arch': ['arm64'], 'os': [MINIMUM_OS]})
    distribution = stage / 'Distribution.xml'
    run('productbuild', '--synthesize', '--product', requirements, '--package', component, distribution)
    tree = ET.parse(distribution)
    dist = tree.getroot()
    ET.SubElement(dist, 'title').text = '罗技电量桥接'
    ET.SubElement(dist, 'welcome', {'file': 'welcome.txt', 'mime-type': 'text/plain'})
    ET.SubElement(dist, 'conclusion', {'file': 'conclusion.txt', 'mime-type': 'text/plain'})
    ET.SubElement(dist, 'domains', {'enable_anywhere': 'false', 'enable_currentUserHome': 'false', 'enable_localSystem': 'true'})
    # Keep the package reference portable when embedding the component.
    for ref in dist.findall('pkg-ref'):
        if ref.text and ref.text.strip().endswith('.pkg'):
            ref.text = component.name
    tree.write(distribution, encoding='utf-8', xml_declaration=True)
    installer_resources = stage / 'installer-resources'
    installer_resources.mkdir()
    (installer_resources / 'welcome.txt').write_text(
        f'罗技电量桥接 {VERSION}\n\n安装目标：M 系列 Mac，macOS {MINIMUM_OS} 或更新版本。\n\n'
        '直接读取兼容的罗技接收器鼠标电量，并显示在苹果原生“电池”小组件中。无需 BTT、Python 或罗技软件。\n\n'
        '安装位置：应用程序文件夹。登录后自动在后台运行，无需手动打开。安装需要管理员密码，并为本机用户配置后台启动。\n\n'
        '已读取 Signature M550 和 PRO X 2 的接收器电量。其他型号取决于电量协议兼容性。', encoding='utf-8')
    (installer_resources / 'conclusion.txt').write_text(
        '文件安装完成。当前已登录用户的后台服务会尝试立即启动；若未运行，请注销后重新登录。\n\n'
        '请连接罗技接收器，并在桌面右键 → 编辑小组件 → 添加“电池”。首次扫描可能需要约一分钟。\n\n'
        '双击应用程序中的 LogitechBatteryBridge 可打开主窗口，查看电量与连接状态，也可点击菜单栏鼠标图标。主窗口可隐藏菜单栏图标；隐藏后也会隐藏程序坞图标，双击应用程序中的 App 可再打开主窗口。关闭窗口后继续在后台运行。\n\n'
        '卸载工具：应用程序中的 LogitechBatteryBridge.app → 右键“显示包内容” → Contents → Resources → 卸载.command。\n\n'
        '若系统提示阻止运行或需要输入监控权限，请按“系统设置 → 隐私与安全性”中的实际提示处理。', encoding='utf-8')
    run('productbuild', '--distribution', distribution, '--package-path', stage,
        '--resources', installer_resources, output)
print(output)
