# Project Status

`company/project-state.yml`이 현재 Stage/Task의 기계 판독 기준이다.
이 문서는 사람이 이해해야 할 확인 사실, blocker, 다음 결정을 기록한다.

## Baseline

- CCR ref: `v3.0.22`
- CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Upstream history integrated: `YES`
- Integration main commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Wrapper version: `pre-v1`
- Development control: Android/Termux-first
- External build preference: Termux + PRoot Linux
- Internal target environment: Windows, test only
- GitHub Actions: `DISABLED` — upstream workflows 검토 전까지 유지

## Current

- Stage: `V1-S0`
- Active Task: `V1-S0-T01`
- Status: `PLANNED`
- Goal: Company 변경 없이 Stock CCR `v3.0.22`의 외부 install/typecheck/build 가능 여부 검증

## Confirmed facts

| Item | Status | Evidence |
|---|---|---|
| Company repository foundation | PASS | foundation `9c117d73aa9732e599e5a2b685090aeb4e706566` |
| CCR upstream history | PASS | PR #5 merged with merge commit; final integration main `b05567891e15a157d8e54fac627618f8214128a7` |
| Pinned CCR ancestry | PASS | merge base with final main is PIN `829298cf8bdcc6ddb9120a5a7c790c30227a1937` |
| Foundation ancestry | PASS | merge base with final main is foundation SHA |
| Integration merge ancestry | PASS | merge base with final main is `dfc15f15e37577abc26aee22fdcd09fe8bc2418c` |
| CCR repository structure | PASS | `package.json`, `packages/`, `build/`, `docs/`, `LICENSE`, `company/` present |
| Stock CCR external build | RETRY_REQUIRED | Attempt 1 was `BLOCKED_ENVIRONMENT` on native Android/arm64 Termux; PR #8 recorded the evidence without closing the Task |
| PRoot Linux retry | PLANNED | preferred Attempt 2: Ubuntu userland + Node 22 on the same Android device |
| Stock CCR Windows execution | UNVERIFIED | later V1-S0 target validation on internal Windows |
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
- PRoot Linux is not a Windows runtime and cannot validate Desktop/installer/Windows path behavior.
- Stock CCR external build remains unanswered until `npm ci`, `typecheck`, and `build:assets` pass in the PRoot Linux retry or another approved runner.
- Final product feasibility still depends on internal Windows validation.

## Last passed gate

- Gate: `BOOT`
- Decision: `ACCEPTED`
- Baseline commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Date: `2026-08-26`

## Next action

1. Native Termux의 임시 `AI_WORK_REPORT.md`를 repository 밖으로 이동하거나 삭제한다.
2. `company/docs/ENVIRONMENTS.md`에 따라 Ubuntu PRoot + Node 22를 준비한다.
3. 같은 `V1-S0-T01`의 Attempt 2로 `npm ci`, `npm run typecheck`, `npm run build:assets`를 변경 없이 실행한다.
4. PRoot 제약으로 실패 원인을 구분할 수 없을 때만 별도 Windows/Linux PC 또는 CI를 고려한다.
