#!/usr/bin/env bash
set -eu

if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' '[FAIL] Python: python3 is not on PATH.' \
        'Install Python 3.10 or newer, then rerun this script.' >&2
    exit 1
fi

exec python3 "$(cd -- "$(dirname -- "$0")" && pwd)/check_environment.py" "$@"
