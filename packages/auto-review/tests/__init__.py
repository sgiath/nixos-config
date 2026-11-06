"""Deterministic tests for the auto-review service."""

import sys

# -I ignores PYTHONDONTWRITEBYTECODE. Keep later imports from writing outside tests/.
sys.dont_write_bytecode = True

import logging

# The engine logs every event it records; the assertions check the store instead.
logging.disable(logging.CRITICAL)
