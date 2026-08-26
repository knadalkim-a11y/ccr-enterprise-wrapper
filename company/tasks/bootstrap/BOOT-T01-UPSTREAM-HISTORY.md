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

> CCR `v3.0.22` history와 현재 Company foundation history를 force-push 없이 하나의 main ancestry로 결합할 수 있는가?

## Why now

Stock build와 Provider 검증은 CCR source/history가 실제 repository에 존재한 뒤에만 의미가 있다.
GitHub connector는 다른 repository의 commit object를 직접 참조할 수 없으므로 정상적인 local Git fetch/merge가 필요하다.

## Required knowledge

- `company/docs/UPSTREAM_SYNC.md`
- `company/docs/AGENT_WORKFLOW.md`
- `company/gates/BOOT.md`

## In scope

- `upstream` remote 추가 및 tag fetch
- commit `829298cf8bdcc6ddb9120a5a7c790c30227a1937` 검증
- upstream commit에서 bootstrap branch 생성
- `origin/main` foundation history를 `--allow-unrelated-histories`로 merge
- 두 history ancestry와 upstream-controlled tree 무변경 검증
- branch push와 PR 생성
- Task/Gate Evidence 갱신

## Out of scope

- CCR source 수정
- dependency install/build/start
- Provider/model 설정
- Wrapper 기능 구현
- main force-push
- 다음 Task 활성화

## Acceptance criteria

- [ ] `upstream` remote가 공식 CCR repository를 가리킴
- [ ] pinned tag가 정확한 commit으로 해석됨
- [ ] candidate branch가 pinned upstream commit을 ancestor로 포함
- [ ] candidate branch가 foundation `origin/main`을 ancestor로 포함
- [ ] Company-owned 경로를 제외한 upstream-controlled tree가 pinned commit과 동일
- [ ] force-push 없이 branch가 origin에 push됨
- [ ] PR과 검증 명령이 기록됨
- [ ] CCR source 변경 없음

## External commands/tests

```bash
git remote -v
git remote add upstream https://github.com/musistudio/claude-code-router.git
git fetch upstream --tags

git rev-parse v3.0.22
git cat-file -t 829298cf8bdcc6ddb9120a5a7c790c30227a1937

git switch -c bootstrap/upstream-v3.0.22 \
  829298cf8bdcc6ddb9120a5a7c790c30227a1937

git merge --no-ff --allow-unrelated-histories origin/main \
  -m "merge: establish CCR v3.0.22 company baseline"

git merge-base --is-ancestor \
  829298cf8bdcc6ddb9120a5a7c790c30227a1937 HEAD
git merge-base --is-ancestor origin/main HEAD

git diff --exit-code \
  829298cf8bdcc6ddb9120a5a7c790c30227a1937 HEAD -- . \
  ':(exclude)AGENTS.md' \
  ':(exclude)COMPANY_WRAPPER.md' \
  ':(exclude)company/**' \
  ':(exclude).github/ISSUE_TEMPLATE/task.md' \
  ':(exclude).github/PULL_REQUEST_TEMPLATE.md'

git push -u origin bootstrap/upstream-v3.0.22
```

기존 `upstream` remote가 있다면 URL을 확인하고 중복 추가하지 않는다.

## Internal validation contract

- Required: No
- Internal result: `NOT_REQUIRED`

## Stop conditions

- pinned tag/commit 불일치
- merge conflict가 Company-owned 경로 외에서 발생
- upstream-controlled file 변경이 필요함
- force-push 없이는 진행할 수 없음

## Rollback

- 원격 bootstrap branch 삭제
- main은 변경하지 않음

## Attempts

| Attempt | Session role | Commit | External | Internal | Recommendation |
|---:|---|---|---|---|---|

## Evidence / limitations

- Target CCR ref: `v3.0.22`
- Target CCR commit: `829298cf8bdcc6ddb9120a5a7c790c30227a1937`

## Codex recommendation

`PENDING`

## Human decision

`PENDING`
