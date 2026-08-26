# Project Status

`company/project-state.yml`이 현재 Stage/Task의 기계 판독 기준이다.
이 문서는 사람이 이해해야 할 확인 사실, blocker, 다음 결정을 기록한다.

## Baseline

- CCR ref: `v3.0.22`
- CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Upstream history integrated: `YES`
- Integration main commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Wrapper version: `pre-v1`
- Development control: Android/Termux
- Primary validation environment: Internal Windows, test only
- Optional runner: separate PC/CI/PRoot only when internal Windows cannot provide conclusive evidence
- GitHub Actions: `DISABLED` — upstream workflows 검토 전까지 유지

## Current

- Stage: `V1-S0`
- Active Task: `V1-S0-T02`
- Status: `PLANNED`
- Goal: build가 검증된 Stock CCR CLI를 사내 Windows에서 source checkout 그대로 start/stop하고 runtime/config 경로를 확인
- Validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`

## Confirmed facts

| Item | Status | Evidence |
|---|---|---|
| Company repository foundation | PASS | foundation `9c117d73aa9732e599e5a2b685090aeb4e706566` |
| CCR upstream history | PASS | PR #5 merged with merge commit; final integration main `b05567891e15a157d8e54fac627618f8214128a7` |
| Pinned CCR ancestry | PASS | merge base with final main is PIN `829298cf8bdcc6ddb9120a5a7c790c30227a1937` |
| Foundation ancestry | PASS | merge base with final main is foundation SHA |
| Integration merge ancestry | PASS | merge base with final main is `dfc15f15e37577abc26aee22fdcd09fe8bc2418c` |
| CCR repository structure | PASS | `package.json`, `packages/`, `build/`, `docs/`, `LICENSE`, `company/` present |
| Native Termux build attempt | BLOCKED_ENVIRONMENT | Attempt 1 failed at Android/arm64 native dependency install; PR #8 preserved the evidence |
| Stock CCR internal Windows build | PASS | `V1-S0-T01` Attempt 2 on commit `97b73a9f4e1fb23d406bb987d0785cefa1f99966`; npm ci, typecheck, build:assets, product diff all exit `0` |
| Windows install-integrity anomaly | RECHECK | first `npm ci` returned `0` but `.bin` was absent; clean rerun restored integrity; observed once, root cause unconfirmed |
| Stock CCR Windows runtime smoke | PLANNED | active Task `V1-S0-T02` |
| Internal provider contract | UNVERIFIED | pending V1-S1 on internal Windows |
| Claude Code E2E | UNVERIFIED | pending V1-S2 on internal Windows |

## V1-S0-T01 final evidence

| Item | Result |
|---|---|
| Tested commit | `97b73a9f4e1fb23d406bb987d0785cefa1f99966` |
| Environment | Microsoft Windows 11 Enterprise `10.0.2231`, Node `v24.15.0`, npm `11.12.1`, `win32`, `x64` |
| Working tree before test | `CLEAN` |
| Final clean npm install | `PASS`, exit `0` |
| Typecheck | `PASS`, exit `0` |
| Build assets | `PASS`, exit `0` |
| Product diff | `PASS`, exit `0` |
| Final Git status | `CLEAN` — no output |
| Reproducibility | `1/1` |
| Human decision | `ACCEPTED` |

## Open risks

- Imported upstream workflows are not yet approved for this repository. Keep GitHub Actions disabled.
- 첫 `npm ci`가 exit `0`이었지만 실제 설치가 불완전했던 단일 사례의 원인은 확인되지 않았다. 후속 검증자는 install exit code만 보지 말고 실제 typecheck/build 또는 필요한 실행 파일 존재까지 확인한다.
- Stock CCR runtime start/stop, 설정 위치, 기본 로그 위치는 아직 사내 Windows에서 검증되지 않았다.

## Last passed gate

- Gate: `BOOT`
- Decision: `ACCEPTED`
- Baseline commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Date: `2026-08-26`

## Last completed Task

- Task: `V1-S0-T01`
- Decision: `ACCEPTED`
- Validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Date: `2026-08-26`

## Next action

Run only `company/tasks/v1-s0/V1-S0-T02-STOCK-RUNTIME-SMOKE.md` on internal Windows.
Do not configure internal providers or start V1-S1 until the V1-S0 runtime smoke and Gate decision are complete.
