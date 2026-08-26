---
id: BOOT-T01
stage: BOOT
title: Integrate CCR upstream history
kind: bootstrap
status: done
session_role: implementation
internal_validation: not-required
depends_on: []
allowed_paths:
  - exact upstream v3.0.22 tree
  - company/tasks/bootstrap/BOOT-T01-UPSTREAM-HISTORY.md
  - company/docs/STATUS.md
  - company/project-state.yml
  - company/gates/BOOT.md
forbidden_paths:
  - upstream file content modifications
human_decision: accepted
---

# Integrate CCR Upstream History

## Validation question

> CCR `v3.0.22` history와 현재 Company foundation history를 force-push 없이 하나의 `main` ancestry로 결합할 수 있는가?

## Why now

Stock build와 Provider 검증은 CCR source/history가 실제 repository에 존재한 뒤에만 의미가 있다.
다른 repository의 전체 commit ancestry는 일반 Git `fetch/merge/push`로 반입해야 한다.

## Required knowledge

- `company/docs/UPSTREAM_SYNC.md`
- `company/docs/AGENT_WORKFLOW.md`
- `company/gates/BOOT.md`

## In scope

- 공식 `upstream` remote 확인 및 pinned tag fetch
- `v3.0.22^{commit}`과 pinned SHA의 자동 동등성 검증
- 실행 시점의 깨끗한 `origin/main`을 `FOUNDATION_SHA`로 고정
- pinned CCR commit에서 bootstrap branch 생성
- foundation history를 `--allow-unrelated-histories`로 merge
- 통합 `MERGE_COMMIT`과 두 부모 기록
- 두 history ancestry와 upstream-controlled tree 무변경 검증
- upstream tag를 제외한 branch push와 PR 생성
- Task/Gate Evidence 갱신
- PR 병합 전 Actions와 merge method에 대한 사람용 체크리스트 제공

## Out of scope

- CCR source 수정
- upstream workflow 내용 수정
- dependency install/build/start
- Provider/model 설정
- Wrapper 기능 구현
- `main` force-push
- upstream tag를 `origin`에 push
- 다음 Task의 구현

## Acceptance criteria

### Codex / local Git

- [x] `upstream` remote가 공식 CCR repository를 가리킴
- [x] `refs/tags/v3.0.22^{commit}`이 pinned SHA와 정확히 일치함
- [x] 깨끗하고 최신인 `origin/main` SHA를 Evidence에 기록함
- [x] 통합 merge commit SHA와 정확한 두 부모를 Evidence에 기록함
- [x] candidate branch가 pinned upstream commit을 ancestor로 포함함
- [x] candidate branch가 foundation commit을 ancestor로 포함함
- [x] Company-owned 경로를 제외한 upstream-controlled tree가 pinned commit과 동일함
- [x] `--no-follow-tags`로 branch만 push함
- [x] `origin`에 `v3.0.22` tag가 생기지 않음
- [x] PR과 재현 가능한 검증 명령이 기록됨
- [x] CCR source 변경 없음

### Human merge

- [x] BOOT PR 병합 전에 repository Actions를 일시 비활성화함
- [x] BOOT PR을 **Create a merge commit** 방식으로 병합함
- [x] 병합 후 `origin/main`이 pinned CCR, foundation, integration merge commit을 모두 ancestor로 포함함
- [x] upstream workflow 검토 전까지 Actions를 다시 활성화하지 않음

## External commands/tests

실행에 사용한 검증 흐름은 아래와 같다.

```bash
set -euo pipefail

TAG=v3.0.22
PIN=829298cf8bdcc6ddb9120a5a7c790c30227a1937
BRANCH=bootstrap/upstream-v3.0.22
UPSTREAM_URL=https://github.com/musistudio/claude-code-router.git

git fetch --prune origin
git switch main
git pull --ff-only origin main
test -z "$(git status --porcelain)"
FOUNDATION_SHA=$(git rev-parse origin/main)

if git remote get-url upstream >/dev/null 2>&1; then
  test "$(git remote get-url upstream)" = "$UPSTREAM_URL"
else
  git remote add upstream "$UPSTREAM_URL"
fi

git fetch upstream "refs/tags/${TAG}:refs/tags/${TAG}"
TAG_SHA=$(git rev-parse "refs/tags/${TAG}^{commit}")
test "$TAG_SHA" = "$PIN"

git switch -c "$BRANCH" "$PIN"
git merge --no-ff --allow-unrelated-histories "$FOUNDATION_SHA" \
  -m "merge: establish CCR v3.0.22 company baseline"

MERGE_COMMIT=$(git rev-parse HEAD)
read -r PARENT_1 PARENT_2 EXTRA <<< "$(git show -s --format='%P' "$MERGE_COMMIT")"
test -z "${EXTRA:-}"
test "$PARENT_1" = "$PIN"
test "$PARENT_2" = "$FOUNDATION_SHA"

git merge-base --is-ancestor "$PIN" "$MERGE_COMMIT"
git merge-base --is-ancestor "$FOUNDATION_SHA" "$MERGE_COMMIT"

git diff --exit-code "$PIN" "$MERGE_COMMIT" -- . \
  ':(exclude)AGENTS.md' \
  ':(exclude)COMPANY_WRAPPER.md' \
  ':(exclude)company/**' \
  ':(exclude).github/ISSUE_TEMPLATE/task.md' \
  ':(exclude).github/PULL_REQUEST_TEMPLATE.md'

git push --no-follow-tags -u origin "HEAD:refs/heads/${BRANCH}"
test -z "$(git ls-remote --tags origin "refs/tags/${TAG}")"
```

Post-merge ancestry was independently verified against final `main`:

```text
PIN -> final main: PASS
FOUNDATION_SHA -> final main: PASS
MERGE_COMMIT -> final main: PASS
```

## Internal validation contract

- Required: No
- Internal result: `NOT_REQUIRED`

## Stop conditions

No stop condition was triggered.

## Rollback

- Before merge: delete only the bootstrap branch.
- After merge: do not rewrite public `main`; use a normal revert only if a later human decision requires it.

## Attempts

| Attempt | Session role | Commit | External | Internal | Recommendation |
|---:|---|---|---|---|---|
| 1 | implementation | `43e087e17956fc74a06456d124dddb56268bedc0` candidate HEAD | `PASS` | `NOT_REQUIRED` | `GO` — human merge checklist required |
| 2 | human merge and post-merge verification | `b05567891e15a157d8e54fac627618f8214128a7` final main | `PASS` | `NOT_REQUIRED` | `ACCEPTED` |

## Final evidence

- Official upstream remote: `https://github.com/musistudio/claude-code-router.git`
- Target CCR ref: `v3.0.22`
- Target CCR commit/PIN: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Tag commit equality: `PASS`
- Foundation commit: `9c117d73aa9732e599e5a2b685090aeb4e706566`
- Integration merge commit: `dfc15f15e37577abc26aee22fdcd09fe8bc2418c`
- Integration merge parents: PIN, then foundation (`PASS`, exactly two)
- Candidate branch HEAD: `43e087e17956fc74a06456d124dddb56268bedc0`
- Candidate PR: #5 (`MERGED` with **Create a merge commit**)
- Final `main` commit: `b05567891e15a157d8e54fac627618f8214128a7`
- Final `main` parents: foundation, then candidate branch HEAD
- Candidate ancestry: pinned CCR `PASS`; foundation `PASS`
- Final main ancestry: PIN `PASS`; foundation `PASS`; integration merge `PASS`
- Upstream-controlled tree diff: `PASS` — no diff in candidate verification
- Origin tag check: `PASS` — `refs/tags/v3.0.22` absent after branch-only push
- Required CCR paths: `PASS`
- Actions state during merge: `DISABLED` — user-confirmed before merge and kept disabled
- CCR source/Core patch: `NONE`
- Build/install/start: intentionally not performed; belongs to `V1-S0-T01`

## Codex recommendation

`GO`

## Human decision

`ACCEPTED` — BOOT Gate passed on `2026-08-26`; `V1-S0-T01` may be activated.
