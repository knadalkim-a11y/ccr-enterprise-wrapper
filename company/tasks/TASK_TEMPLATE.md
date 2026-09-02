---
id: V1-SX-TXX
stage: V1-SX
title: Task title
kind: validation
status: planned
primary_actor: INTERNAL_VALIDATOR
execution_mode: human_assisted
implementation_required: false
internal_validation: required
github_write_allowed: false
candidate_sha: TBD
instruction_sha: TBD
# candidate_role: validation_overlay
# tested_product_sha: exact SHA required when candidate_role is validation_overlay
merge_policy: not_applicable
depends_on: []
required_capabilities: []
allowed_git_actions: []
allowed_paths: []
forbidden_paths: []
human_decision: pending
---

# Task title

## Validation question

> 독립적으로 `PASS / FAIL / BLOCKED`를 판단할 수 있는 질문 하나

한 Task에 서로 다른 실패 계층을 섞지 않는다.
Provider, Profile, Gateway completion, Streaming, Tool round-trip, Claude Code E2E는 기본적으로 별도 Task다.

## Task classification

허용 값:

```text
kind:
- design
- implementation
- validation
- spike

primary_actor:
- CHATGPT_ORCHESTRATOR
- EXTERNAL_CODEX
- INTERNAL_VALIDATOR
- HUMAN_GATE_OWNER

execution_mode:
- agent_only
- human_assisted
- human_only

merge_policy:
- internal_pass_required
- external_pass_only
- not_applicable
```

- `implementation_required: true`이면 External Codex 구현 Lane을 사용한다.
- `internal_validation: required`이면 승인된 exact candidate를 사내에서 검증한다.
- `INTERNAL_VALIDATOR`가 primary actor이면 `github_write_allowed`는 반드시 `false`다.

## Why now

-

## Confirmed prerequisites

- 이미 통과한 전제만 기록한다.
- 이번 Task에서 다시 증명하지 않을 사실을 명시한다.

## Candidate contract

```text
Canonical repository URL:
Candidate fetch ref:
Task path:
Candidate SHA:
Instruction SHA:
Candidate role: implementation / validation / validation_overlay
Tested product SHA (validation_overlay only):
Authorized phase:
Merge policy:
Required capability matrix:
Execution mode:
Product tree equivalence:
Internal validation target:
```

원칙:

1. 구현 Task는 코드와 검증 지침이 함께 들어 있는 PR head SHA 하나를 내부 candidate로 사용한다.
2. 내부 검증이 필요한 코드 PR은 `INTERNAL_PASS` 전 merge하지 않는다.
3. Validation-only Task는 `candidate_sha`와 `instruction_sha`가 다를 수 있으나, 둘 다 handoff에 기록하고 제품 경로 동등성을 확인한다.
4. Internal Validator는 branch 이름이나 최신 상태를 추측하지 않고 Human Gate Owner가 승인한 canonical URL/ref/SHA/phase만 사용한다.
5. PR ref가 기본 fetchspec에 없을 수 있으므로 Task-approved disposable repository에 exact ref를 fetch하고 shared checkout은 변경하지 않는다.
6. `validation_overlay`는 Human이 명시적으로 승인한 경우에만 사용하며 exact tested product SHA, protected-path equivalence와 full tested-product build plane을 기록한다.

## Required knowledge

-

## In scope

-

## Out of scope

-

## Actor plan

| Order | Actor | Responsibility | Stop / handoff |
|---:|---|---|---|
| 1 | `CHATGPT_ORCHESTRATOR` | Task·Acceptance Criteria·Evidence 형식 설계 | Human Gate Owner 승인 |
| 2 | `EXTERNAL_CODEX` | 구현이 필요할 때만 branch/PR 작성 | Candidate SHA 반환 |
| 3 | `INTERNAL_VALIDATOR` | disposable repository에서 exact ref/SHA 확인 후 test-only 검증 | Sanitized evidence 반환 |
| 4 | `HUMAN_GATE_OWNER` | secret/UI/정책 작업과 최종 Gate 결정 | 다음 Task 승인 또는 RETRY |

사용하지 않는 Actor 단계는 `NOT_REQUIRED`로 명시한다.

## [CHATGPT_ORCHESTRATOR] Design / state steps

1. 검증 질문과 실패 계층을 하나로 제한한다.
2. `primary_actor`, `execution_mode`, candidate/merge contract를 정한다.
3. 실제 secret 또는 raw internal evidence가 필요 없는 절차를 작성한다.
4. Human Gate 승인 없이 다음 Task를 활성화하지 않는다.

## [EXTERNAL_CODEX] Build / repair steps

`implementation_required: true`일 때만 작성한다.

1. 활성 Task 범위의 가장 작은 변경을 구현한다.
2. 외부 검증과 제품 diff를 기록한다.
3. 내부 검증 절차를 같은 candidate에 포함한다.
4. branch/commit/push/PR 후 candidate SHA를 반환한다.
5. `merge_policy: internal_pass_required`이면 내부 PASS 전 병합하지 않는다.

## [INTERNAL_VALIDATOR] Preflight / validation steps

1. 역할을 `INTERNAL_VALIDATOR`로 선언한다.
2. 승인된 canonical URL의 exact fetch ref를 Task-approved disposable repository에 가져와 `instruction_sha`/`candidate_sha`와 일치하는지 확인한다.
3. 승인된 Task/phase와 required capability를 확인한다.
4. 아래에 문서화된 명령과 UI 단계만 수행한다.
5. source, dependency, Task, STATUS, Gate, GitHub를 수정하지 않는다.
6. 결과를 Sanitized Evidence 형식으로 Human Gate Owner에게 반환하고 종료한다.

### Allowed commands / UI steps

```text
commands and UI steps
```

## [HUMAN_GATE_OWNER] Human steps

`execution_mode: human_assisted` 또는 `human_only`일 때만 작성한다.

### H1 — Human action title

- 사람이 수행할 실제 UI·credential·승인 작업
- agent 출력에 전달하지 않을 값
- agent에 반환할 최소 상태: `YES / NO`, `PASS / FAIL / BLOCKED`, 일반화된 category

Internal Validator는 Human Step 직전에 멈추고, 완료 신호를 받은 뒤 다음 Agent Step으로 진행한다.

## Acceptance criteria

- [ ] exact candidate SHA 기록
- [ ] exact instruction SHA 기록
- [ ] required capability 충족
- [ ] Actor별 Step 완료
- [ ] 검증 질문에 `PASS / FAIL / BLOCKED`로 답함
- [ ] 제품 source와 lockfile 무변경 또는 승인된 구현 diff만 존재
- [ ] secret/raw internal evidence 외부 반출 없음
- [ ] Internal Validator가 요청·관찰한 GitHub/remote write, source/history authoring, shared checkout mutation 범위를 사실대로 기록
- [ ] disposable local Git/workspace write, runtime/config/service action과 관찰하지 않은 child side effect를 분리해 기록
- [ ] 다음 Task 미시작

## Stop conditions

-

## Cleanup / rollback

-

## Sanitized evidence template

```text
Role:
Task ID:
Session role:
Candidate SHA:
Instruction SHA:
Canonical repository URL verified: YES / NO
Candidate fetch ref verified: YES / NO
Authorized phase:
Environment alias: <sanitized Human-supplied label; not hostname/user/device ID>
Capability matrix:
Commands/UI steps performed:
Exit codes / PASS / FAIL / BLOCKED:
Protocol/provider/model aliases:
Failure classification:
Reproducibility:
Product diff / fingerprint:
Existing shared checkout final status: NOT_APPLICABLE / CLEAN / DIRTY
Human steps completed:
Sanitized observation:
Secrets/raw evidence included in sanitized handoff: NO
Agent-requested GitHub/remote write: NONE / YES
Agent-authored source/history: NONE / YES
Agent-targeted existing shared checkout mutation: NONE / YES
Disposable local Git/workspace write: YES / NO
Agent-requested runtime/config/service action: NONE / YES
Unobserved child side effects: NOT_APPLICABLE / NOT_OBSERVED / NOT_CLAIMED
Next Task started: NO
```

## Attempts

| Attempt | Actor / session role | Candidate | Instruction | External | Internal | Recommendation |
|---:|---|---|---|---|---|---|

Attempts는 덮어쓰지 않고 누적한다.

## Evidence / limitations

-

## Agent recommendation

`GO / RETRY / STOP / SCOPE_REDUCE / READY_FOR_INTERNAL_VALIDATION`

## Human decision

`PENDING / ACCEPTED / RETRY / REJECTED / DEFERRED`
