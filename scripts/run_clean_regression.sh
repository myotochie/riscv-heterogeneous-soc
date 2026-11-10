#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/verilator_env.sh"
cd "$(dirname "$0")/.."
CLEAN_ROOT="${CLEAN_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-clean.XXXXXX")}"
mkdir -p "$CLEAN_ROOT/source"
CLEAN_ROOT="$(cd "$CLEAN_ROOT" && pwd)"
export CLEAN_ROOT
export SOURCE_GIT_HEAD
SOURCE_GIT_HEAD="$(git rev-parse HEAD)"
# Include pending source changes, exclude all ignored/untracked build artifacts.
# This is a copy, never a checkout or a write into .git.
python3 -B - <<'PY'
import os,pathlib,shutil,subprocess
names=subprocess.check_output(['git','ls-files','--cached','--others','--exclude-standard','-z']).split(b'\0')
root=pathlib.Path(os.environ['CLEAN_ROOT'])/'source'
for name in names:
 if not name:continue
 src=pathlib.Path(os.fsdecode(name))
 if not src.exists():continue
 dst=root/src
 dst.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2(src,dst)
print('Clean source snapshot:',root)
PY
export LOG_ROOT="${LOG_ROOT:-$CLEAN_ROOT/results}"
bash "$CLEAN_ROOT/source/scripts/run_full_regression.sh"
