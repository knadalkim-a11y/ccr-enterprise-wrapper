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

- Stage: `V1-S1`
- Active Task: `V1-S1-T01`
- Status: `READY_FOR_INTERNAL_VALIDATION`
- Goal: Stock CCR에서 사내 GLM custom Provider 한 개와 모델 한 개의 basic `Check Connection`을 source 수정 없이 검증
- V1-S0 validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`

## Confirmed facts

| Item | Status | Evidence |
|---|---|---|
| Company repository foundation | PASS | foundation `9c117d73aa9732e599e5a2b685090aeb4e706566` |
| CCR upstream history | PASS | PR #5 merged with merge commit; final integration main `b05567891e15a157d8e54fac627618f8214128a7` |
| Pinned CCR ancestry | PASS | merge base with final main is PIN `829298cf8bdcc6ddb9120a5a7c790c30227a1937` |
| CCR repository structure | PASS | `package.json`, `packages/`, `build/`, `docs/`, `LICENSE`, `company/` present |
| Native Termux build attempt | BLOCKED_ENVIRONMENT | Attempt 1 failed at Android/arm64 native dependency install; PR #8 preserved the evidence |
| Stock CCR internal Windows build | PASS | `V1-S0-T01` on commit `97b73a9f4e1fb23d406bb987d0785cefa1f99966`; npm ci, typecheck, build:assets, product diff exit `0` |
| Windows install-integrity anomaly | RECHECK | first `npm ci` returned `0` but `.bin` was absent; clean rerun restored integrity; observed once, root cause unconfirmed |
| Stock CCR Windows runtime smoke | PASS | `V1-S0-T02` on the same product commit; CLI help/start/stop and product diff exit `0`; runtime data directory created |
| V1-S0 Gate | ACCEPTED | internal Windows install/build/start/stop demonstrated without product source changes |
| GLM Provider connection check | READY_FOR_INTERNAL_VALIDATION | active Task `V1-S1-T01` |
| Gateway basic completion | UNVERIFIED | pending later V1-S1 Task |
| Streaming/tool contract | UNVERIFIED | pending later V1-S1 Tasks |
| Claude Code E2E | UNVERIFIED | pending V1-S2 on internal Windows |

## V1-S0 final evidence

| Item | Result |
|---|---|
| Tested product commit | `97b73a9f4e1fb23d406bb987d0785cefa1f99966` |
| Environment | Microsoft Windows 11 Enterprise reported as `10.0.2231`, Node `v24.15.0`, npm `11.12.1`, `win32`, `x64` |
| Clean install | `PASS`, final exit `0` |
| Typecheck | `PASS`, exit `0` |
| Build assets | `PASS`, exit `0` |
| CLI entrypoint/help | `PASS`, exit `0` |
| Management-only start | `PASS`, exit `0` |
| Runtime data directory | absent before first start; present after start |
| Stop | `PASS`, exit `0` |
| Product diff | `PASS`, exit `0` |
| Final Git status | `CLEAN` — no output |
| Runtime smoke reproducibility | `1/1` |
| V1-S0 Human decision | `ACCEPTED` on `2026-08-27` |

## Open risks

- Imported upstream workflows are not yet approved for this repository. Keep GitHub Actions disabled.
- The first-install integrity anomaly remains a one-time `RECHECK`; validators must run real follow-up commands instead of trusting `npm ci` exit code alone.
- V1-S0 used source-built CLI management-only mode. Desktop installer/package was not tested.
- Internal Provider protocol, endpoint permission, proxy/TLS, model access, gateway request, streaming, and tools remain unverified.
- Provider `Check Connection` output may include internal diagnostics; only sanitized categories may be returned externally.

## Last passed gate

- Gate: `V1-S0`
- Decision: `ACCEPTED`
- Validated product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Date: `2026-08-27`

## Last completed Task

- Task: `V1-S0-T02`
- Decision: `ACCEPTED`
- Tested product commit: `97b73a9f4e1fb23d406bb987d0785cefa1f99966`
- Date: `2026-08-27`

## Next action

Run only `company/tasks/v1-s1/V1-S1-T01-GLM-PROVIDER-CHECK.md` on internal Windows.
Configure one GLM Provider and one model in CCR runtime data, run `Check Connection`, redact all internal values, and do not start gateway-client, streaming, tool, Gemma, or Claude Code tests yet.
