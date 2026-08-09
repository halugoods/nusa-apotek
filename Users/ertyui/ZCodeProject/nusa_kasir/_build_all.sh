#!/usr/bin/env bash
# Canonical multi-variant builder wrapper. Python owns swapping and restoration.
set -Eeuo pipefail

BASE_DIR="/c/Users/ertyui/ZCodeProject/nusa_kasir"
PYTHON="${PYTHON:-python}"

cd "$BASE_DIR"
exec "$PYTHON" "$BASE_DIR/_build_all.py" "$@"
