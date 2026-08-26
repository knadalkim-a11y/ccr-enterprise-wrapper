# Gate BOOT — Upstream History Integration

## Gate question

> CCR pinned history와 Company foundation history가 하나의 repository `main` ancestry로 안전하게 결합되었는가?

## Required Tasks / evidence

- `BOOT-T01`
- official upstream remote URL
- pinned tag/commit equality
- foundation commit SHA
- integration merge commit SHA와 두 부모
- candidate branch에서 두 history ancestry
- upstream-controlled tree diff
- `origin`에 upstream tag가 없다는 확인
- BOOT PR merge method: **Create a merge commit**
- final `main`에서 pinned CCR, foundation, integration merge commit ancestry
- BOOT merge 중 GitHub Actions 상태

## Evidence summary

| Item | Task | Commit | Result |
|---|---|---|---|
| History integration candidate | BOOT-T01 | `dfc15f15e37577abc26aee22fdcd09fe8bc2418c` | `PASS` — pinned CCR and foundation are ancestors |
| Upstream tree unchanged | BOOT-T01 | `dfc15f15e37577abc26aee22fdcd09fe8bc2418c` | `PASS` — no upstream-controlled diff |
| Origin tag absent | BOOT-T01 | `43e087e17956fc74a06456d124dddb56268bedc0` | `PASS` — `refs/tags/v3.0.22` absent after branch-only push |
| BOOT PR merge method | BOOT-T01 | PR #5 | `PASS` — Create a merge commit |
| Final main ancestry | BOOT-T01 | `b05567891e15a157d8e54fac627618f8214128a7` | `PASS` — PIN, foundation, integration merge all ancestors |
| Required CCR paths | BOOT-T01 | `b05567891e15a157d8e54fac627618f8214128a7` | `PASS` — root package, packages, build, docs, LICENSE and company present |
| Actions safety | BOOT-T01 | Human confirmation | `PASS` — disabled before merge and kept disabled |

## Validated details

- Official upstream: `https://github.com/musistudio/claude-code-router.git`
- Tag/PIN: `v3.0.22^{commit}` = `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Foundation: `9c117d73aa9732e599e5a2b685090aeb4e706566`
- Integration merge: `dfc15f15e37577abc26aee22fdcd09fe8bc2418c`
- Integration parents: PIN, then foundation (`PASS`, exactly two)
- Candidate branch HEAD: `43e087e17956fc74a06456d124dddb56268bedc0`
- Candidate PR: #5 (`MERGED`)
- Final main: `b05567891e15a157d8e54fac627618f8214128a7`
- Final main parents: foundation main, then candidate branch HEAD
- Final main ancestry: PIN `PASS`; foundation `PASS`; integration merge `PASS`
- GitHub Actions: `DISABLED`; keep disabled until upstream workflows are reviewed

## Remaining risks

- Imported upstream workflows are intentionally not approved yet; Actions remain disabled.
- Build, install and runtime compatibility are outside this Gate and remain unverified.

## Codex recommendation

`GO`

## Human decision

`ACCEPTED` — BOOT requirements were met and `V1-S0-T01` may become the active Task.

## Validated baseline

- CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Foundation commit: `9c117d73aa9732e599e5a2b685090aeb4e706566`
- Integration merge commit: `dfc15f15e37577abc26aee22fdcd09fe8bc2418c`
- Final wrapper `main` commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Date: `2026-08-26`
