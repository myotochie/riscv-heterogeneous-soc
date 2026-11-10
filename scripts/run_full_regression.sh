#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/verilator_env.sh"
cd "$(dirname "$0")/.."
# The timed SV bench and rootp observation benches require modern Verilator.
version="$($VERILATOR --version)"
if [[ ! "$version" =~ ^Verilator\ ([5-9][0-9]*|[1-9][0-9]+)\. ]]; then
    echo "[ERROR] Full regression requires Verilator >=5; got: $version" >&2
    exit 2
fi
LOG_ROOT="${LOG_ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/rv64-regression.XXXXXX")}"
mkdir -p "$LOG_ROOT/build"
LOG_ROOT="$(cd "$LOG_ROOT" && pwd)"
export LOG_ROOT
python3 -B - <<'PY'
import hashlib,json,os,pathlib,subprocess,datetime
root=pathlib.Path.cwd()
files=sorted(p for d in ['rtl','verification','scripts','.github'] for p in (root/d).rglob('*')
             if p.is_file() and p.suffix in ['.sv','.cpp','.h','.sh','.py','.yml','.md'])
records={str(p.relative_to(root)):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
digest=hashlib.sha256(json.dumps(records,sort_keys=True).encode()).hexdigest()
def output(cmd):return subprocess.check_output(cmd,text=True).strip()
manifest={'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source_sha256':digest,
          'source_files':records,'git_head':os.environ.get('SOURCE_GIT_HEAD','unrecorded'),
          'verilator':output([os.environ['VERILATOR'],'--version']),
          'cxx':output(['g++','--version']).splitlines()[0],
          'make':output(['make','--version']).splitlines()[0],
          'python':output(['python3','--version'])}
(pathlib.Path(os.environ['LOG_ROOT'])/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Source SHA256:',digest)
PY
if [[ $? != 0 ]]; then exit 2; fi
passed=0
failed=0
printf 'suite\tresult\n' > "$LOG_ROOT/summary.tsv"
run() {
    local script="$1" name build
    name="$(basename "$script" .sh)"
    build="$LOG_ROOT/build/$name"
    mkdir -p "$build"
    if BUILD_ROOT="$build" BUILD_DIR="$build" BASE_BUILD_DIR="$build" \
        bash "$script" > "$LOG_ROOT/$name.log" 2>&1; then
        echo "[PASS] $script"
        printf '%s\tPASS\n' "$script" >> "$LOG_ROOT/summary.tsv"
        ((passed+=1))
    else
        echo "[FAIL] $script (see $LOG_ROOT/$name.log)"
        printf '%s\tFAIL\n' "$script" >> "$LOG_ROOT/summary.tsv"
        tail -40 "$LOG_ROOT/$name.log"
        ((failed+=1))
    fi
}
run scripts/run_unit_tests.sh
for script in verification/scripts/run_*.sh; do
    run "$script"
done
echo "Suites passed: $passed; suites failed: $failed; logs: $LOG_ROOT"
((failed == 0))
