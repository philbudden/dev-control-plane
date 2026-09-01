#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fake_bin="${tmp_dir}/bin"
mkdir -p "$fake_bin"

cat >"${fake_bin}/devpod" <<'FAKEDEVPOD'
#!/usr/bin/env bash
exit 0
FAKEDEVPOD

cat >"${fake_bin}/tmux" <<'FAKETMUX'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >>"${DCA_TEST_LOG}"

case "${1:-}" in
    has-session)
        if [ "${DCA_TEST_EXISTING_SESSION:-}" = "true" ]; then
            exit 0
        fi
        exit 1
        ;;
    list-windows)
        count="${DCA_TEST_WINDOW_COUNT:-1}"
        i=1
        while [ "$i" -le "$count" ]; do
            printf '%s: window-%s\n' "$i" "$i"
            i=$((i + 1))
        done
        ;;
    new-session|new-window|set-option|select-window|attach-session|switch-client)
        exit 0
        ;;
    *)
        echo "unexpected tmux command: $*" >&2
        exit 1
        ;;
esac
FAKETMUX

chmod +x "${fake_bin}/devpod" "${fake_bin}/tmux"

assert_contains() {
    local file="$1"
    local pattern="$2"

    if ! grep -F -- "$pattern" "$file" >/dev/null; then
        echo "Expected ${file} to contain: ${pattern}" >&2
        echo "--- ${file} ---" >&2
        cat "$file" >&2
        exit 1
    fi
}

assert_not_contains() {
    local file="$1"
    local pattern="$2"

    if grep -F -- "$pattern" "$file" >/dev/null; then
        echo "Expected ${file} not to contain: ${pattern}" >&2
        echo "--- ${file} ---" >&2
        cat "$file" >&2
        exit 1
    fi
}

export PATH="${fake_bin}:${PATH}"
export TMPDIR="${tmp_dir}/runtime"
mkdir -p "$TMPDIR"

export DCA_TEST_LOG="${tmp_dir}/new-session.log"
"${repo_dir}/bin/dca" example-workspace

assert_contains "$DCA_TEST_LOG" "new-session -d -s example-workspace -n nvim"
assert_contains "$DCA_TEST_LOG" "set-option -t example-workspace -q @dev_control_workspace example-workspace"
assert_contains "$DCA_TEST_LOG" "attach-session -t example-workspace"
assert_not_contains "$DCA_TEST_LOG" "new-window"
assert_contains "${TMPDIR}/dev-control-plane-${USER:-user}/example-workspace-nvim.sh" "dcssh example-workspace --command"
assert_contains "${TMPDIR}/dev-control-plane-${USER:-user}/example-workspace-nvim.sh" "nvim\\ ."

export DCA_TEST_LOG="${tmp_dir}/existing-session.log"
export DCA_TEST_EXISTING_SESSION=true
export DCA_TEST_WINDOW_COUNT=1
"${repo_dir}/bin/dca" example-workspace

assert_contains "$DCA_TEST_LOG" "has-session -t example-workspace"
assert_contains "$DCA_TEST_LOG" "list-windows -t example-workspace"
assert_contains "$DCA_TEST_LOG" "set-option -t example-workspace -q @dev_control_workspace example-workspace"
assert_contains "$DCA_TEST_LOG" "attach-session -t example-workspace"
assert_not_contains "$DCA_TEST_LOG" "new-session"
assert_not_contains "$DCA_TEST_LOG" "new-window"

export DCA_TEST_LOG="${tmp_dir}/old-session.log"
export DCA_TEST_EXISTING_SESSION=true
export DCA_TEST_WINDOW_COUNT=6
if "${repo_dir}/bin/dca" example-workspace >"${tmp_dir}/old-session.out" 2>&1; then
    echo "Expected dca to reject an existing multi-window session." >&2
    exit 1
fi

assert_contains "${tmp_dir}/old-session.out" "already exists with 6 windows"
assert_contains "${tmp_dir}/old-session.out" "will not close existing windows automatically"
assert_not_contains "$DCA_TEST_LOG" "kill-window"
assert_not_contains "$DCA_TEST_LOG" "new-window"

echo "dca single-window behaviour verified"
