---
id: BOOT-T01
stage: BOOT
title: Integrate CCR upstream history
kind: bootstrap
status: planned
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
human_decision: pending
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
- 다음 Task 활성화

## Acceptance criteria

### Codex / local Git

- [x] `upstream` remote가 공식 CCR repository를 가리킴
- [x] `refs/tags/v3.0.22^{commit}`이 pinned SHA와 정확히 일치함
- [x] 깨끗하고 최신인 `origin/main` SHA를 Evidence에 기록함
- [x] 통합 merge commit SHA와 정확한 두 부모를 Evidence에 기록함
- [x] candidate branch가 pinned upstream commit을 ancestor로 포함함
- [x] candidate branch가 foundation commit을 ancestor로 포함함
- [x] Company-owned 경로를 제외한 upstream-controlled tree가 pinned commit과 동일함
- [ ] `--no-follow-tags`로 branch만 push함
- [ ] `origin`에 `v3.0.22` tag가 생기지 않음
- [ ] PR과 재현 가능한 검증 명령이 기록됨
- [x] CCR source 변경 없음

### Human merge

- [ ] BOOT PR 병합 전에 repository Actions를 일시 비활성화함
- [ ] BOOT PR을 **Create a merge commit** 방식으로만 병합함
- [ ] 병합 후 `origin/main`이 pinned CCR, foundation, integration merge commit을 모두 ancestor로 포함함
- [ ] upstream workflow 검토 전까지 Actions를 다시 활성화하지 않음

## External commands/tests

아래 흐름은 Bash 기준이다. 명령을 줄이지 말고 실제 SHA를 Task Evidence에 기록한다.

```bash
set -euo pipefail

TAG=v3.0.22
PIN=829298cf8bdcc6ddb9120a5a7c790c30227a1937
BRANCH=bootstrap/upstream-v3.0.22
UPSTREAM_URL=https://github.com/musistudio/claude-code-router.git

# 1. origin/main을 최신의 깨끗한 기준선으로 고정
git fetch --prune origin
git switch main
git pull --ff-only origin main
test -z "$(git status --porcelain)"
FOUNDATION_SHA=$(git rev-parse origin/main)

# 2. 공식 upstream과 정확한 tag commit 검증
if git remote get-url upstream >/dev/null 2>&1; then
  test "$(git remote get-url upstream)" = "$UPSTREAM_URL"
else
  git remote add upstream "$UPSTREAM_URL"
fi

git fetch upstream "refs/tags/${TAG}:refs/tags/${TAG}"
TAG_SHA=$(git rev-parse "refs/tags/${TAG}^{commit}")
test "$TAG_SHA" = "$PIN"

# 3. pinned CCR commit에서 branch를 만들고 foundation history merge
git switch -c "$BRANCH" "$PIN"
git merge --no-ff --allow-unrelated-histories "$FOUNDATION_SHA" \
  -m "merge: establish CCR v3.0.22 company baseline"

MERGE_COMMIT=$(git rev-parse HEAD)
read -r PARENT_1 PARENT_2 EXTRA <<< "$(git show -s --format='%P' "$MERGE_COMMIT")"
test -z "${EXTRA:-}"
test "$PARENT_1" = "$PIN"
test "$PARENT_2" = "$FOUNDATION_SHA"

# 4. ancestry와 upstream-controlled tree 검증
git merge-base --is-ancestor "$PIN" "$MERGE_COMMIT"
git merge-base --is-ancestor "$FOUNDATION_SHA" "$MERGE_COMMIT"

git diff --exit-code "$PIN" "$MERGE_COMMIT" -- . \
  ':(exclude)AGENTS.md' \
  ':(exclude)COMPANY_WRAPPER.md' \
  ':(exclude)company/**' \
  ':(exclude).github/ISSUE_TEMPLATE/task.md' \
  ':(exclude).github/PULL_REQUEST_TEMPLATE.md'

# 5. Task/Status/Gate Evidence를 company-owned 경로에서 갱신하고 commit
#    HEAD는 후속 문서 commit이 될 수 있으므로 MERGE_COMMIT을 별도 기록한다.

# 6. upstream tag 없이 branch만 push
git push --no-follow-tags -u origin "HEAD:refs/heads/${BRANCH}"
test -z "$(git ls-remote --tags origin "refs/tags/${TAG}")"

printf 'FOUNDATION_SHA=%s\nMERGE_COMMIT=%s\n' \
  "$FOUNDATION_SHA" "$MERGE_COMMIT"
```

기존 local branch가 있으면 이름을 재사용하거나 덮어쓰지 말고 중단하여 상태를 보고한다.

## PR and human merge checklist

Codex는 PR을 생성하고 다음 정보를 본문에 기록한다.

```text
PIN
FOUNDATION_SHA
MERGE_COMMIT
candidate branch HEAD
upstream tree diff result
origin tag absence result
```

그 뒤 사람은 다음 순서로 진행한다.

1. Repository Settings에서 Actions를 일시 비활성화한다.
2. PR에서 **Create a merge commit**을 선택한다. Squash/Rebase를 사용하지 않는다.
3. 병합 후 local clone에서 다음을 검증한다.

```bash
git fetch origin
FINAL_MAIN=$(git rev-parse origin/main)

git merge-base --is-ancestor "$PIN" "$FINAL_MAIN"
git merge-base --is-ancestor "$FOUNDATION_SHA" "$FINAL_MAIN"
git merge-base --is-ancestor "$MERGE_COMMIT" "$FINAL_MAIN"
```

4. 결과를 `company/gates/BOOT.md`에 기록하고 사람이 BOOT Gate를 결정한다.
5. upstream workflow가 검토되기 전에는 Actions를 다시 활성화하지 않는다.

## Internal validation contract

- Required: No
- Internal result: `NOT_REQUIRED`

## Stop conditions

- pinned tag/commit 불일치
- 시작 시 working tree가 깨끗하지 않음
- 기존 bootstrap branch가 있어 안전한 상태를 판단할 수 없음
- merge conflict가 Company-owned 경로 외에서 발생
- integration merge commit의 부모가 예상과 다름
- upstream-controlled file 변경이 필요함
- upstream tag가 `origin`에 push됨
- force-push 없이는 진행할 수 없음

## Rollback

- 원격 bootstrap branch 삭제
- `main`은 변경하지 않음
- GitHub Actions 설정을 작업 전 상태로 복원

## Attempts

| Attempt | Session role | Commit | External | Internal | Recommendation |
|---:|---|---|---|---|---|

## Evidence / limitations

- Official upstream remote: `https://github.com/musistudio/claude-code-router.git` (`PASS`)
- Target CCR ref: `v3.0.22`
- Target CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Tag commit equality: `PASS` — `v3.0.22^{commit}` = `829298cf8bdcc6ddb9120a5a7c790c30227a1937`
- Foundation commit: `9c117d73aa9732e599e5a2b685090aeb4e706566`
- Integration merge commit: `dfc15f15e37577abc26aee22fdcd09fe8bc2418c`
- Integration merge parents: `829298cf8bdcc6ddb9120a5a7c790c30227a1937` then `9c117d73aa9732e599e5a2b685090aeb4e706566` (`PASS`, exactly two)
- Candidate ancestry: pinned CCR `PASS`; foundation `PASS`
- Upstream-controlled tree diff: `PASS` — no diff, exit `0`
- Candidate branch HEAD: `PENDING_PUSH` — the exact pushed HEAD will be recorded in the BOOT PR because an evidence commit cannot self-reference its own Git object ID
- Candidate PR: `PENDING`
- Final `main` commit: `PENDING_HUMAN_MERGE`
- Actions state during merge: `PENDING_HUMAN`; repository Actions were enabled during candidate preparation and were not changed
- Origin tag check: `PRE_PUSH_PASS` — `refs/tags/v3.0.22` absent; post-push check pending
- Limitation: final `main` ancestry, Actions state during merge, and merge method remain unverified until the human merge checklist is completed

## Codex recommendation

`PENDING`

## Human decision

`PENDING`
