# Project Status

`company/project-state.yml`이 현재 Stage/Task의 기계 판독 기준이다.
이 문서는 사람이 이해해야 할 확인 사실, blocker, 다음 결정을 기록한다.

## Baseline target

- CCR ref: `v3.0.22`
- CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Upstream history integrated: `NO` — local candidate only; `main` is unchanged
- Wrapper version: `pre-v1`
- Development: External Codex
- Internal environment: Test only

## Current

- Stage: `BOOT`
- Active Task: `BOOT-T01`
- Status: `EXTERNAL_PASS` — candidate PR #5 is open and awaits the human merge checklist

## Confirmed facts

| Item | Status | Evidence |
|---|---|---|
| Company repository foundation | PRESENT | foundation commit on main |
| CCR upstream history | CANDIDATE_PASS | BOOT-T01 merge `dfc15f15e37577abc26aee22fdcd09fe8bc2418c`; PR #5; not on `main` |
| Stock CCR external build | UNVERIFIED | V1-S0-T01 |
| Stock CCR internal execution | UNVERIFIED | pending |
| Internal provider contract | UNVERIFIED | pending |
| Claude Code E2E | UNVERIFIED | pending |

## Open blockers

- Before human merge, repository Actions must be disabled and **Create a merge commit** must be selected.
- Upstream workflows remain unreviewed; Actions must remain disabled after merge until that review is complete.
- Final `main` ancestry and the BOOT Gate remain unverified until the human merge is completed and recorded.

## BOOT-T01 candidate evidence

| Item | Result |
|---|---|
| Official upstream | `https://github.com/musistudio/claude-code-router.git` |
| Tag/PIN equality | `PASS` — `v3.0.22^{commit}` = `829298cf8bdcc6ddb9120a5a7c790c30227a1937` |
| Foundation | `9c117d73aa9732e599e5a2b685090aeb4e706566` |
| Integration merge | `dfc15f15e37577abc26aee22fdcd09fe8bc2418c` |
| Merge parents | `829298cf8bdcc6ddb9120a5a7c790c30227a1937`, then `9c117d73aa9732e599e5a2b685090aeb4e706566` |
| Candidate ancestry | pinned CCR `PASS`; foundation `PASS` |
| Upstream-controlled tree | `PASS` — no diff, exit `0` |
| Initial pushed candidate | `865b25abd44861f05df4106ec0e8238882129be0`; exact current HEAD is maintained in PR #5 because an evidence commit cannot self-reference |
| Candidate PR | `https://github.com/knadalkim-a11y/ccr-enterprise-wrapper/pull/5` — open, not merged |
| Origin tag | `POST_PUSH_PASS` — `refs/tags/v3.0.22` absent after branch-only push |
| Final main ancestry | `UNVERIFIED` — human merge required |

## Last internally validated baseline

- Commit: none
- Gate: none

## Next human decision

- Disable Actions and merge PR #5 only with **Create a merge commit**, or defer the BOOT merge.
