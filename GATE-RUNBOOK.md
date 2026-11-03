# Calldata Firewall gate runbook

This is a manual, non-executable operator checklist for the isolated Calldata Firewall gate. It is not a shell script and must never be sourced. Run every accepted phase manually, serially, from `$(git rev-parse --show-toplevel)` using the single authorized runner.

The gate window closes at `2026-11-03T11:30:00Z`. Stop heavy execution at `11:20:00Z` and preserve the last ten minutes for logs, hashes, review, and the decision. Nothing may be inferred from another project.

## 1. Authoritative resource guard

Run the guard while no gate build or test is active, before provenance, before build, before the full suite, and before every trace invocation. A previous pass never authorizes a later phase.

### 1.1 Process snapshots

Take two snapshots at least 15 seconds apart:

```text
date -u '+%Y-%m-%dT%H:%M:%SZ'
ps -eo pid=,ni=,pcpu=,pmem=,etime=,stat=,comm= --sort=-pcpu
```

The process inventory is restricted to exactly `pid,ni,%cpu,%mem,etime,stat,comm`. Never inspect command arguments, command lines, working directories, executable paths, open files, or environment variables. Do not use `ps aux`, argument-bearing `ps` formats, `pgrep -a/-f`, `/proc/*/cmdline`, `lsof`, or equivalent sources.

Record `RG-STOP` and do not start or continue a heavy phase if either condition holds:

- the same external process is at or above `75%` CPU in both snapshots, or otherwise remains at or above `75%` for at least 15 seconds;
- any external compiler process is present, at any CPU level. Compiler names include `fe`, `fe_linux_amd64`, `rustc`, `cargo`, `clang`, `clang++`, `gcc`, `g++`, `cc1`, `cc1plus`, `ld`, `lld`, and their evident `comm` truncations.

Because the snapshots are taken while this gate is idle, any compiler then visible is external. If ownership is ambiguous using only the permitted fields, stop. During a gate phase, the one compiler launched by the operator is the only permitted compiler; a second compiler or newly sustained external heavy process requires interrupting the phase, retaining its partial log, and returning to the guard.

### 1.2 Memory and disk

Both memory predicates must pass: `MemAvailable >= 4 GiB` and `MemAvailable >= 25% of MemTotal`. The exact KiB floor is `4194304`.

```text
awk '/MemTotal:/{t=$2}/MemAvailable:/{a=$2} END{p=100*a/t; printf "MemAvailableKiB=%d MemAvailablePct=%.2f\n",a,p; exit !(a>=4194304 && p>=25)}' /proc/meminfo
```

The filesystem containing the repository must have at least `20 GiB` free. The exact 1-KiB-block floor is `20971520`.

```text
df -Pk . | awk 'NR==2{printf "DiskAvailableKiB=%d\n",$4; exit !($4>=20971520)}'
```

Any nonzero result is `RG-STOP`. Do not round a failing value upward.

### 1.3 CPU affinity and priority

Inspect only the current shell's affinity:

```text
taskset -pc $$
```

Set `CPUSET` manually to one or two CPU IDs from that allowed list and record the chosen value. Never select more than two logical CPUs. Every build/test command below must retain all four controls:

- `RAYON_NUM_THREADS=1`;
- `CARGO_BUILD_JOBS=1`;
- `nice -n 15`;
- `taskset -c "$CPUSET"` with at most two CPUs.

No phases run concurrently.

## 2. Time budget and timeout rule

Immediately before each heavy command, record the remaining execution budget:

```text
cutoff=$(date -u -d '2026-11-03T11:20:00Z' +%s)
now=$(date -u +%s)
remaining=$((cutoff-now))
printf 'remaining_before_evidence_cutoff_seconds=%s\n' "$remaining"
```

Use the smaller of the phase cap below and `remaining` as the concrete `timeout` value. Never start with `remaining <= 0`, never extend a cap, and never retry merely to erase a failure. Default caps are:

| Phase | Maximum wall time |
|---|---:|
| build | 12 minutes / 720 seconds |
| full grouped suite | 25 minutes / 1500 seconds |
| each individually filtered call trace | 8 minutes / 480 seconds |
| final evidence and hashes | reserved 10 minutes |

A timeout (`124`), forced kill (`137`), interrupt (`130`), or missing exit code is not a pass. If a phase is interrupted by `RG-STOP`, preserve the partial output and do not resume until the complete guard passes again and there is enough margin for a fresh, separately logged attempt.

## 3. Provenance and evidence layout

First require a clean tracked worktree:

```text
git status --porcelain=v1
git diff --check
git rev-parse HEAD
./.contest-tools/fe_linux_amd64 --version
```

Any tracked modification is a stop. Only after that check, create a local evidence directory and capture provenance:

```text
mkdir -p evidence
{
  date -u '+utc=%Y-%m-%dT%H:%M:%SZ'
  printf 'commit='; git rev-parse HEAD
  printf 'fe='; ./.contest-tools/fe_linux_amd64 --version
  printf 'cpuset=%s\n' "$CPUSET"
} 2>&1 | tee evidence/00-provenance.log
sha256sum .contest-tools/fe_linux_amd64 GATE-RUNBOOK.md README.md GATE-LOG.md RED-TEAM.md TEST-MATRIX.md TOOLCHAIN.md gate/fe.toml gate/src/lib.fe > evidence/00-inputs.sha256
```

`00-inputs.sha256` does not name itself. Do not alter tracked inputs after this point. Every command log must contain its exit code. In an interactive Bash session, capture each piped command as follows, substituting its concrete command, log, and timeout:

```text
set -o pipefail
COMMAND 2>&1 | tee LOG
rc=${PIPESTATUS[0]}
printf 'exit_code=%s\n' "$rc" | tee -a LOG
```

Stop on nonzero `rc`; diagnostic runs may explain a failure but cannot turn the original failure into a pass.

## 4. Serial execution

### 4.1 Build

After a fresh guard pass and budget calculation:

```text
env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 nice -n 15 taskset -c "$CPUSET" timeout --signal=INT --kill-after=30s 720s ./.contest-tools/fe_linux_amd64 build gate --color never 2>&1 | tee evidence/01-build.log
```

Record `${PIPESTATUS[0]}` immediately in the same log. The shown `720s` is a ceiling; replace it with the smaller remaining budget when necessary. On success, hash build artifacts without leaving the repository:

```text
find gate/out -type f -print0 | sort -z | xargs -0 -r sha256sum > evidence/01-build-artifacts.sha256
```

A failed or timed-out build stops all runtime work.

### 4.2 Full test suite

After another complete guard pass:

```text
env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 nice -n 15 taskset -c "$CPUSET" timeout --signal=INT --kill-after=30s 1500s ./.contest-tools/fe_linux_amd64 test gate --jobs 1 --grouped --color never 2>&1 | tee evidence/02-tests-full.log
```

Record `${PIPESTATUS[0]}` immediately. This invocation must discover and pass the entire suite, including canonical forwarding, all canonicality and bounds rejections, accepted maximums, the four-byte burner with eight 512-byte inputs, first/last-word input observation, output scratch reuse, reentrancy, capped returndata, and reserve recurrence. A filtered success never substitutes for the full suite.

### 4.3 Individual call traces

Run each trace below separately, in order, with a new complete guard pass and budget calculation before each invocation. Record `${PIPESTATUS[0]}` in its corresponding log. Clamp every shown `480s` timeout to the remaining budget.

```text
env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 nice -n 15 taskset -c "$CPUSET" timeout --signal=INT --kill-after=30s 480s ./.contest-tools/fe_linux_amd64 test gate --jobs 1 --grouped --filter malformed_canonicality_matrix_zero_call_trace_oracle --call-trace --color never 2>&1 | tee evidence/03-trace-malformed.log
```

```text
env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 nice -n 15 taskset -c "$CPUSET" timeout --signal=INT --kill-after=30s 480s ./.contest-tools/fe_linux_amd64 test gate --jobs 1 --grouped --filter bounds_zero_call_trace_oracle --call-trace --color never 2>&1 | tee evidence/04-trace-bounds.log
```

```text
env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 nice -n 15 taskset -c "$CPUSET" timeout --signal=INT --kill-after=30s 480s ./.contest-tools/fe_linux_amd64 test gate --jobs 1 --grouped --filter raw_rejection_hardening_zero_call_trace_oracle --call-trace --color never 2>&1 | tee evidence/05-trace-raw-hardening.log
```

```text
env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 nice -n 15 taskset -c "$CPUSET" timeout --signal=INT --kill-after=30s 480s ./.contest-tools/fe_linux_amd64 test gate --jobs 1 --grouped --filter value_and_gas_zero_call_trace_oracle --call-trace --color never 2>&1 | tee evidence/06-trace-value-gas.log
```

```text
env RAYON_NUM_THREADS=1 CARGO_BUILD_JOBS=1 nice -n 15 taskset -c "$CPUSET" timeout --signal=INT --kill-after=30s 480s ./.contest-tools/fe_linux_amd64 test gate --jobs 1 --grouped --filter reentrancy_is_rejected_before_nested_validation --call-trace --color never 2>&1 | tee evidence/07-trace-reentrancy.log
```

For the four rejection oracles, inspect every rejected firewall-call subtree. It must contain zero nested `CALL` operations to any destination. The tests intentionally make no post-rejection external query, so any nested `CALL` is proof-killing. For the reentrancy oracle, the initial target call and callback are expected; the callback must reject before another target call, parsing, or scratch use. Save the normalized trace output, not a prose assertion alone.

## 5. Final integrity evidence

Before the decision, confirm no tracked source changed and record repository state:

```text
{
  date -u '+utc=%Y-%m-%dT%H:%M:%SZ'
  git diff --check
  git diff --exit-code
  git status --short
  git rev-parse HEAD
} 2>&1 | tee evidence/98-final-status.log
```

If every planned log exists, hash this explicit set:

```text
sha256sum evidence/00-provenance.log evidence/00-inputs.sha256 evidence/01-build.log evidence/01-build-artifacts.sha256 evidence/02-tests-full.log evidence/03-trace-malformed.log evidence/04-trace-bounds.log evidence/05-trace-raw-hardening.log evidence/06-trace-value-gas.log evidence/07-trace-reentrancy.log evidence/98-final-status.log > evidence/99-evidence.sha256
```

If execution stopped early, name only the files that actually exist as explicit `sha256sum` operands and record the omitted phase and reason in the decision. Never hash `99-evidence.sha256` into itself, never append its own digest, and never rewrite an already cited log. The runbook's digest belongs in `00-inputs.sha256`; no digest is embedded back into this file.

## 6. Decision table

Assign exactly one gate result from retained evidence:

### `GO`

Use only if the build, complete grouped suite, and all five individual traces exit zero within the window; every rejection subtree has zero nested calls; the four-byte burner with eight 512-byte inputs reports `attempted=8, failed=8`; 1024-to-0-to-1 input reuse exposes both boundary markers and bomb-to-empty/failure output reuse is clean; bounded returndata, reentrancy, maximum boundaries, and reserve recurrence pass; no S0/S1 remains; and final integrity checks are clean.

### `PLAN B (single-call)`

Use only when canonical validation, selector handling, zero-value forwarding, single-call bounded input/output scratch, returndata capping, reentrancy rejection, and every zero-call rejection trace are proven green, but a failure is isolated to multi-call admission, suffix reserve recurrence, the eight-call burner, or the `count=8` boundary. The fallback is a strict `count=1` design; it is not a GO and must be implemented and rerun before adoption. Do not weaken canonical validation, bounds, or zero-call guarantees. A timeout qualifies only if it is isolated to that multi-call class and all required single-call safety evidence is already complete.

### `KILL`

Use for build failure; selector/dispatch failure; malformed, noncanonical, out-of-bounds, value-bearing, or invalid-gas input reaching any external call; stale or unbounded scratch/returndata behavior; reentrancy escaping the guard; inconsistent ABI behavior; any shared validator or single-call forwarding failure; any required safety trace failing or missing at the decision deadline; or insufficient evidence to satisfy either `GO` or the narrowly proven single-call fallback. A timeout or `RG-STOP` is never silently converted into a pass.

Record the result with the exact failing phase, exit code, UTC time, relevant log digest, and whether the cause is correctness, resource guard, or exhausted window. Multiple green gates elsewhere do not alter this decision.
