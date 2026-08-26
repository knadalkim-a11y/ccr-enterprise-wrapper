# Project Status

`company/project-state.yml`이 현재 Stage/Task의 기계 판독 기준이다.
이 문서는 사람이 이해해야 할 확인 사실, blocker, 다음 결정을 기록한다.

## Baseline target

- CCR ref: `v3.0.22`
- CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Upstream history integrated: `NO`
- Wrapper version: `pre-v1`
- Development: External Codex
- Internal environment: Test only

## Current

- Stage: `BOOT`
- Active Task: `BOOT-T01`
- Status: `PLANNED`

## Confirmed facts

| Item | Status | Evidence |
|---|---|---|
| Company repository foundation | PRESENT | foundation commit on main |
| CCR upstream history | UNVERIFIED | BOOT-T01 |
| Stock CCR external build | UNVERIFIED | V1-S0-T01 |
| Stock CCR internal execution | UNVERIFIED | pending |
| Internal provider contract | UNVERIFIED | pending |
| Claude Code E2E | UNVERIFIED | pending |

## Open blockers

- GitHub connector cannot attach a commit object from another repository directly; upstream history integration requires a normal local Git fetch/merge performed by the active Bootstrap Task.

## Last internally validated baseline

- Commit: none
- Gate: none

## Next human decision

- Start or defer `BOOT-T01`.
