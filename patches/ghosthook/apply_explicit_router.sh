#!/usr/bin/env sh
# Apply the GhostHook router only to the source baseline it was reviewed on.
# Usage: apply_explicit_router.sh /path/to/kernel_platform/common
set -eu

expected=8a82a099c89b90b54c8698db456ab8cf9a25b14e
self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
common=${1:?usage: $0 /path/to/kernel_platform/common}
[ -d "$common/.git" ] || { echo "not a git worktree: $common" >&2; exit 2; }
actual=$(git -C "$common" rev-parse HEAD)
[ "$actual" = "$expected" ] || {
    echo "refusing: common HEAD=$actual, expected=$expected" >&2
    exit 3
}
git -C "$common" diff --quiet || {
    echo "refusing: common worktree is dirty" >&2
    exit 4
}
git -C "$common" apply --check "$self_dir/0001-ghosthook-add-explicit-fault-router-point.patch"
git -C "$common" apply "$self_dir/0001-ghosthook-add-explicit-fault-router-point.patch"
git -C "$common" diff --check
grep -q 'gh_fault_router_register' "$common/arch/arm64/mm/fault.c"
grep -q 'gh_fault_router_unregister' "$common/arch/arm64/mm/fault.c"
test -f "$common/include/linux/ghosthook.h"
printf 'GhostHook explicit router patch applied to %s\n' "$actual"
