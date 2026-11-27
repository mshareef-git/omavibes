#!/usr/bin/env python3
"""Test production analytics helpers in Qt without launching the plugin.

Run: python3 tests/test_analytics.py
Requires Qt 6 qmltestrunner and the QtTest QML module.
"""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile


root = Path(__file__).resolve().parent.parent
source = (root / "OmaVibesState.qml").read_text()
helpers = source[
    source.index("    readonly property var keyStatsCache:"):
    source.index("    function keyCategoryCounts()")
]
reader = source.index("    property Process analyticsReadProc:")
start = source.index("            onStreamFinished: {", reader)
start = source.index("\n", start) + 1
end = source.index("\n            }\n        }\n    }", start)
test = (root / "tests/analytics.qml.in").read_text()
test = test.replace("__KEY_HELPERS__", helpers)
test = test.replace("__READ_HANDLER__", source[start:end])

runner = next((str(p) for p in (
    Path("/usr/lib/qt6/bin/qmltestrunner"),
    Path("/usr/lib64/qt6/bin/qmltestrunner"),
) if p.is_file()), None) or shutil.which("qmltestrunner6") or shutil.which("qmltestrunner")
if not runner:
    raise SystemExit("Qt 6 qmltestrunner is required")

env = dict(os.environ, QT_QPA_PLATFORM="offscreen",
           QT_QPA_PLATFORMTHEME="", QT_QUICK_CONTROLS_STYLE="Basic")
with tempfile.TemporaryDirectory(prefix="omavibes-analytics-test-") as directory:
    path = Path(directory) / "tst_analytics.qml"
    path.write_text(test)
    result = subprocess.run([runner, "-input", str(path), "-o", "-,txt"], env=env)
    raise SystemExit(result.returncode)
