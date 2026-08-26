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
- Active Task: `V1-S0-T01`
- Status: `READY_FOR_INTERNAL_VALIDATION`
- Goal: Company 변경 없이 Stock CCR `v3.0.22`가 사내 Windows에서 install/typecheck/build되는지 검증
- Node policy: upstream `>=22`를 만족하는 LTS major 사용; 현재 Node 22 또는 Node 24 허용

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
| Stock CCR internal Windows build | READY_FOR_INTERNAL_VALIDATION | Active Task `V1-S0-T01`; supported Node LTS `>=22` + clean `npm ci` + typecheck + build:assets pending |
| Stock CCR Windows execution | UNVERIFIED | follow-up V1-S0 validation after build |
| Internal provider contract | UNVERIFIED | pending V1-S1 on internal Windows |
| Claude Code E2E | UNVERIFIED | pending V1-S2 on internal Windows |

## BOOT final evidence

| Item | Result |
|---|---|
| Official upstream | `https://github.com/musistudio/claude-code-router.git` |
| Tag/PIN equality | `PASS` — `v3.0.22^{commit}` = PIN |
| Foundation | `9c117d73aa9732e599e5a2b685090aeb4e706566` |
| Integration merge | `dfc15f15e37577abc26aee22fdcd09fe8bc2418c` |
| Candidate branch HEAD | `43e087e17956fc74a06456d124dddb56268bedc0` |
| Final integration main | `b05567891e15a157d8e54fac627618f8214128a7` |
| Merge method | `Create a merge commit` |
| Final main ancestry | PIN `PASS`; foundation `PASS`; integration merge `PASS` |
| Upstream-controlled tree | `PASS` — candidate verification found no diff |
| Origin tag | `PASS` — `refs/tags/v3.0.22` absent after branch-only push |
| Actions during merge | `DISABLED` — user-confirmed before merge; remains disabled |

## Open risks

- Imported upstream workflows are not yet approved for this repository. Keep GitHub Actions disabled.
- 사내 Windows에서 dependency 설치가 네트워크/registry 정책으로 차단될 수 있다. 이 경우 제품 결함과 분리해 기록한다.
- Node 24에서만 native dependency 또는 build failure가 발생하면 Node major compatibility 가능성을 분리해 기록하고, 필요한 경우에만 Node 22 비교 검증을 수행한다.
- Stock CCR build와 runtime은 아직 사내 Windows에서 검증되지 않았다.

## Last passed gate

- Gate: `BOOT`
- Decision: `ACCEPTED`
- Baseline commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Date: `2026-08-26`

## Next action

1. 사내 Windows working tree가 clean이고 `process.platform=win32`, `process.arch=x64`인지 확인한다.
2. 설치된 Node가 upstream `>=22`를 만족하는 LTS major인지 확인한다. Node 24 LTS는 허용한다.
3. 현재 설치된 지원 LTS 환경에서 `npm ci`, `npm run typecheck`, `npm run build:assets`를 변경 없이 실행한다.
4. 사내에서는 수정하지 않고 command/exit code/분류/sanitized observation만 외부에 반환한다.
5. Node-major-specific failure 증거가 있을 때만 Node 22 비교 재검증을 고려한다.
6. 결과를 같은 `V1-S0-T01`의 Attempt 2로 기록한다.
