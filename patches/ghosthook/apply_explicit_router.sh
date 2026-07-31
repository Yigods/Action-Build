#!/usr/bin/env sh
# Apply the GhostHook router stack only to the source baseline it was reviewed on.
# Usage: apply_explicit_router.sh /path/to/kernel_platform/common
set -eu

expected=8a82a099c89b90b54c8698db456ab8cf9a25b14e
self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
common=${1:?usage: $0 /path/to/kernel_platform/common}
git -C "$common" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "not a git worktree: $common" >&2
    exit 2
}
actual=$(git -C "$common" rev-parse HEAD)
[ "$actual" = "$expected" ] || {
    echo "refusing: common HEAD=$actual, expected=$expected" >&2
    exit 3
}
git -C "$common" diff --quiet || {
    echo "refusing: common worktree is dirty" >&2
    exit 4
}
for patch in \
    "$self_dir/0001-ghosthook-add-explicit-fault-router-point.patch" \
    "$self_dir/0002-ghosthook-add-explicit-debug-router-point.patch" \
    "$self_dir/0003-ghosthook-add-direct-el0-hwbp.patch" \
    "$self_dir/0004-ghosthook-add-direct-hwbp-trace-ring.patch" \
    "$self_dir/0005-ghosthook-add-direct-hwbp-ss-conflict-guard.patch" \
    "$self_dir/0006-ghosthook-add-direct-hwbp-task-exit-reclaim.patch" \
    "$self_dir/0007-ghosthook-add-debug-core-chain.patch" \
    "$self_dir/0008-ghosthook-add-bounded-ss-trace-core.patch" \
    "$self_dir/0009-ghosthook-ss-trace-target-task-work.patch" \
    "$self_dir/0010-ghosthook-register-ss-core-from-hwbp-init.patch" \
    "$self_dir/0011-ghosthook-add-bounded-ghost-region.patch"; do
    [ -f "$patch" ] || { echo "missing patch: $patch" >&2; exit 5; }
    git -C "$common" apply --check "$patch"
    git -C "$common" apply "$patch"
done
git -C "$common" diff --check
grep -q 'gh_fault_router_register' "$common/arch/arm64/mm/fault.c"
grep -q 'gh_fault_router_unregister' "$common/arch/arm64/mm/fault.c"
grep -q 'gh_debug_router_register' "$common/arch/arm64/mm/fault.c"
grep -q 'gh_debug_router_unregister' "$common/arch/arm64/mm/fault.c"
grep -q 'gh_debug_router_register_core' "$common/arch/arm64/mm/fault.c"
grep -q 'gh_hwbp_direct_arm' "$common/arch/arm64/kernel/hw_breakpoint.c"
grep -q 'gh_hwbp_direct_disarm' "$common/arch/arm64/kernel/hw_breakpoint.c"
grep -q 'gh_hwbp_direct_read_trace' "$common/arch/arm64/kernel/hw_breakpoint.c"
grep -q 'ss_conflicted' "$common/arch/arm64/kernel/hw_breakpoint.c"
grep -q 'gh_hwbp_direct_task_exit' "$common/kernel/exit.c"
grep -q 'GH_DEBUG_ROUTER_CORE_MAX 2' "$common/arch/arm64/mm/fault.c"
grep -q 'gh_ss_trace_arm' "$common/arch/arm64/kernel/gh_ss_trace.c"
grep -q 'gh_ss_trace_arm_work' "$common/arch/arm64/kernel/gh_ss_trace.c"
grep -q 'task_work_add' "$common/arch/arm64/kernel/gh_ss_trace.c"
grep -q 'gh_ss_trace_register_router' "$common/arch/arm64/kernel/hw_breakpoint.c"
grep -q 'gh_ghost_region_create' "$common/mm/gh_ghost.c"
grep -q 'gh_ghost_region_overlaps' "$common/mm/mmap.c"
grep -q 'gh_ghost_region_mm_exit' "$common/mm/mmap.c"
test -f "$common/include/linux/ghosthook.h"
printf 'GhostHook explicit router stack applied to %s\n' "$actual"
