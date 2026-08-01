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
    "$self_dir/0011-ghosthook-add-bounded-ghost-region.patch" \
    "$self_dir/0012-ghosthook-add-passive-undef-trace.patch" \
    "$self_dir/0013-ghosthook-allow-bounded-code-data-pair.patch" \
    "$self_dir/0014-ghosthook-make-rw-data-pte-writable.patch" \
    "$self_dir/0015-ghosthook-rewind-ss-after-consumed-event.patch" \
    "$self_dir/0016-ghosthook-clear-pending-ss-on-stop.patch" \
    "$self_dir/0017-ghosthook-scalar-write-and-ss-fastforward.patch" \
    "$self_dir/0018-ghosthook-commit-emitted-ghost-writes.patch" \
    "$self_dir/0019-ghosthook-disarm-final-ss-in-exception.patch" \
    "$self_dir/0020-ghosthook-drain-final-owned-hwss.patch" \
    "$self_dir/0021-ghosthook-add-bpr-follow-range-trace.patch" \
    "$self_dir/0022-ghosthook-add-bounded-ghcp-syscall-router.patch" \
    "$self_dir/0023-ghosthook-add-ghcp-v2-response-abi.patch"; do
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
grep -q 'user_rewind_single_step(current)' "$common/arch/arm64/kernel/gh_ss_trace.c"
# Explicit stop still uses task_work for a remote target; the final owned
# HWSS is intentionally disarmed directly in its exception context.
grep -q 'task_work_add(task, &gh_ss_trace.disarm_work, TWA_RESUME)' "$common/arch/arm64/kernel/gh_ss_trace.c"
grep -q 'task_work_add' "$common/arch/arm64/kernel/gh_ss_trace.c"
grep -q 'gh_ss_trace_register_router' "$common/arch/arm64/kernel/hw_breakpoint.c"
grep -q 'gh_ghost_region_create' "$common/mm/gh_ghost.c"
grep -q 'gh_ghost_region_write_u32' "$common/mm/gh_ghost.c"
grep -q 'gh_ghost_region_write_u32' "$common/include/linux/ghosthook.h"
grep -q 'user_fastforward_single_step(current)' "$common/arch/arm64/kernel/gh_ss_trace.c"
grep -q 'WRITE_ONCE(.*page_address(region->pages\[page\])' "$common/mm/gh_ghost.c"
# r21 drains the hardware tail event; the public trace still ends at the requested limit.
grep -q 'final_drain' "$common/arch/arm64/kernel/gh_ss_trace.c"
grep -q 'gh_hwbp_direct_follow_arm' "$common/arch/arm64/kernel/hw_breakpoint.c"
grep -q 'gh_hwbp_direct_follow_arm' "$common/include/linux/ghosthook.h"
grep -q 'range_start' "$common/arch/arm64/kernel/hw_breakpoint.c"
grep -q 'user_disable_single_step(current)' "$common/arch/arm64/kernel/gh_ss_trace.c"
grep -q 'GH_GHOST_MAX_REGIONS_PER_MM' "$common/mm/gh_ghost.c"
grep -q 'VM_MAYWRITE | VM_SHARED' "$common/mm/gh_ghost.c"
grep -q 'gh_ghost_region_overlaps' "$common/mm/mmap.c"
grep -q 'gh_ghost_region_mm_exit' "$common/mm/mmap.c"
grep -q 'gh_undef_trace_record_el0' "$common/arch/arm64/kernel/traps.c"
grep -q 'gh_undef_trace_arm' "$common/arch/arm64/kernel/gh_undef_trace.c"
grep -q 'gh_undef_trace_read' "$common/arch/arm64/kernel/gh_undef_trace.c"
grep -q 'gh_control_register' "$common/kernel/gh_control.c"
grep -q 'SYSCALL_DEFINE2(ghosthook_control' "$common/kernel/gh_control.c"
grep -q '__NR_ghosthook_control 451' "$common/include/uapi/asm-generic/unistd.h"
grep -q '__ARCH_WANT_GHOSTHOOK_CONTROL' "$common/arch/arm64/include/uapi/asm/unistd.h"
grep -q 'gh_control_register_v2' "$common/kernel/gh_control.c"
grep -q 'SYSCALL_DEFINE4(ghosthook_control' "$common/kernel/gh_control.c"
grep -q 'GH_CONTROL_V2_RESPONSE_MAX 4096U' "$common/include/linux/ghosthook.h"
test -f "$common/include/linux/ghosthook.h"
printf 'GhostHook explicit router stack applied to %s\n' "$actual"
