#!/usr/bin/env python3
"""Run lifecycle checks against the actual publisher with a fake IOKit backend."""
import pathlib
import subprocess
import tempfile

root = pathlib.Path(__file__).resolve().parents[1]
source = (root / 'main.swift').read_text(encoding='utf-8')
# Reuse production declarations without starting HID monitoring or the daemon.
declarations = source.split('setbuf(stdout, nil)')[0]
checks = (root / 'Tests/PowerPublisherChecks.swift').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='battery-bridge-tests-') as temporary:
    directory = pathlib.Path(temporary)
    main = directory / 'main.swift'
    main.write_text(declarations + '\n' + checks, encoding='utf-8')
    executable = directory / 'checks'
    subprocess.run(['swiftc', '-framework', 'IOKit', str(root / 'HIDPP.swift'), str(main), '-o', str(executable)], check=True)
    subprocess.run([str(executable)], check=True)
