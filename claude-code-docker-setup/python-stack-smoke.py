#!/usr/bin/env python3
"""Build-time verification for the pinned Python scientific stack."""
from importlib import metadata
from pathlib import Path
import sys

if sys.version_info[:2] != (3, 12):
    raise SystemExit(f"Expected Python 3.12, got {sys.version}")

requirements = Path('/tmp/requirements-python.txt')
expected: dict[str, str] = {}
for raw in requirements.read_text(encoding='utf-8').splitlines():
    line = raw.strip()
    if not line or line.startswith('#'):
        continue
    name, version = line.split('==', 1)
    expected[name] = version

for name, wanted in expected.items():
    actual = metadata.version(name)
    if actual != wanted:
        raise SystemExit(f"{name}: expected {wanted}, installed {actual}")

# Import compiled and integration-heavy modules so ABI or dependency failures
# stop the image build rather than appearing during a research session.
import IPython  # noqa: F401,E402
import matplotlib  # noqa: F401,E402
import nbstata  # noqa: F401,E402
import numpy  # noqa: F401,E402
import pandas  # noqa: F401,E402
import scipy  # noqa: F401,E402
import sklearn  # noqa: F401,E402
import statsmodels  # noqa: F401,E402

print(f"Python {sys.version.split()[0]} scientific stack import test passed")
