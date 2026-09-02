# Task System

Task 파일이 요구사항, 실행 역할, Acceptance Criteria, Internal Validation Contract의 유일한 Source of Truth다.
GitHub Issue와 PR은 Task 파일을 링크하고 진행 대화와 Evidence만 담는다.

## 기본 단위

```text
One Task
= one validation question
= one failure layer
= one canonical file

One Session
= design / implementation / review / repair / validation 중 한 번의 시도
```

하나의 Task는 여러 Session과 순차적인 Evidence PR을 가질 수 있지만, 서로 다른 검증 질문을 한 파일에 묶지 않는다.

## Task 파일 분리 기준

다음은 기본적으로 별도 Task다.

```text
Provider connection
Profile / agent mapping
Gateway basic completion
Streaming
Tool call / tool result continuation
Availability error classification
Claude Code vertical slice
Setup / Doctor / Pilot
```

다음은 하나의 Task 안의 Step으로 묶을 수 있다.

```text
Preflight
사람의 credential/UI 입력
Agent의 결과 확인
Service stop
Product diff / fingerprint
Selected checkout status (`NOT_APPLICABLE` for disposable archive)
```

판단 기준:

> 같은 Validation question에 답하기 위한 준비·실행·정리라면 같은 Task의 Step이고,
> 실패 원인이나 다음 repair 담당이 달라지면 별도 Task다.

## Task 종류

| kind | 사용 시점 | 기본 actor |
|---|---|---|
| `design` | 설계 선택, 정책, Gate 결정 | `CHATGPT_ORCHESTRATOR` + `HUMAN_GATE_OWNER` |
| `implementation` | 제품/Company code 변경 | `EXTERNAL_CODEX` |
| `validation` | exact candidate의 사내 검증 | `INTERNAL_VALIDATOR` |
| `spike` | 구현 가능성 또는 인터페이스 확인 | 질문에 따라 지정 |

## 실행 모드

```text
agent_only
→ 에이전트가 명령과 검증을 모두 수행

human_assisted
→ Agent Step 사이에 credential/UI/승인 Human Step이 존재

human_only
→ 정책·Gate·지원 범위처럼 사람만 결정
```

Human-assisted Task는 Task 본문에 `[INTERNAL_VALIDATOR]`와 `[HUMAN_GATE_OWNER]` Step을 순서대로 표시한다.
에이전트는 Human Step 직전에 멈추고, 실제 secret이 아닌 완료 상태만 받아 재개한다.

## Four-Lane workflow

```text
1. DESIGN
   CHATGPT_ORCHESTRATOR + HUMAN_GATE_OWNER
   → 질문, 범위, actor, candidate contract, acceptance 작성

2. BUILD
   EXTERNAL_CODEX — implementation_required일 때만
   → branch, implementation, external test, PR, candidate SHA

3. VALIDATE
   INTERNAL_VALIDATOR + 필요한 Human Step
   → disposable repository에 canonical exact ref/SHA fetch/archive, test-only, sanitized evidence

4. GATE
   HUMAN_GATE_OWNER + CHATGPT_ORCHESTRATOR
   → PASS / RETRY / BLOCKED / DEFER, canonical 상태 갱신
```

Internal Validator는 전체 roadmap을 읽고 다음 Task를 스스로 선택하지 않는다.
`project-state.yml`과 Human Gate Owner가 승인한 Task/phase/ref/SHA 하나만 실행하고 종료한다.

## Candidate / instruction contract

내부 검증 handoff에는 다음 값이 필수다.

```text
canonical_repository_url
candidate_fetch_ref
task_path
candidate_sha
instruction_sha
authorized_phase
merge_policy
required_capability_matrix
execution_mode
```

Internal Validator는 shared checkout의 `origin`, fetchspec, branch/HEAD를 권한
근거로 사용하지 않고 Task-approved disposable repository에 exact ref를
`--prune` 없이 fetch한다.

### 구현 Task

가장 좋은 형태:

```text
candidate_sha == instruction_sha == PR head SHA
```

PR head 안에 제품 변경과 해당 변경을 검증할 Task 지침이 함께 있어야 한다.
`merge_policy: internal_pass_required`인 PR은 내부 PASS 전 병합하지 않는다.

### Validation-only Task

제품 코드가 과거 검증 commit이고 지침만 최신 main에 있는 경우 두 SHA가 다를 수 있다.
이 경우:

```text
Tested product commit
Instruction commit
Product tree equivalence 범위
```

를 모두 Evidence에 기록한다.
두 SHA가 다르다는 사실을 숨기거나 branch 이름만으로 대체하지 않는다.

### Human-approved validation overlay Task

활성 Task가 `candidate_role: validation_overlay`를 명시할 때만 다음을 사용한다.

```text
candidate_sha == instruction_sha == exact control/instruction PR head
tested_product_sha: exact prior validated product commit
protected-path equivalence: exact scope/result
build plane: full tested_product_sha archive
```

이 예외의 candidate는 product commit이 아니며 candidate whole-tree build
equivalence를 주장하지 않는다.

## GitHub write ownership

```text
CHATGPT_ORCHESTRATOR
→ 승인된 Task/STATUS/Gate/Issue/docs 갱신 가능

EXTERNAL_CODEX
→ 활성 구현 Task의 branch/commit/push/PR 가능

INTERNAL_VALIDATOR
→ disposable exact-ref fetch/archive/read/test only, GitHub/source/shared-checkout write 금지

HUMAN_GATE_OWNER
→ 최종 Gate와 다음 Task 승인
```

Internal Validator는 PASS 결과가 나와도 Task, STATUS, Gate, Issue를 직접 수정하지 않는다.
Sanitized text를 Human Gate Owner에게 반환하고 끝낸다.

## 코드 PR 병합 정책

| internal_validation | merge_policy | 병합 조건 |
|---|---|---|
| `required` | `internal_pass_required` | exact PR head의 사내 PASS 후 |
| `not_required` | `external_pass_only` | 외부 Acceptance Criteria와 리뷰 통과 후 |
| validation-only | `not_applicable` | 제품 PR 없음; Evidence docs만 별도 반영 |

내부 FAIL이면 같은 Task의 External Codex repair session으로 돌아간다.
내부 BLOCKED이면 코드를 수정하지 않고 권한·환경·정책 선행조건을 해결한다.

## 상태 흐름

```text
PLANNED
→ IN_PROGRESS
→ EXTERNAL_PASS / READY_FOR_INTERNAL_VALIDATION
→ INTERNAL_PASS / INTERNAL_FAIL / BLOCKED
→ HUMAN_DECISION
→ DONE / RETRY / CANCELLED / DEFERRED
```

Task 완료가 Stage Gate 통과를 자동으로 의미하지 않는다.
`project-state.yml`의 current Task 변경은 Human Gate Owner 승인 후 ChatGPT Orchestrator가 반영한다.

## Evidence 규칙

- Attempts는 덮어쓰지 않고 누적한다.
- 실행하지 않은 검사를 PASS로 기록하지 않는다.
- actual endpoint/key/model/host와 raw request/response는 Task에 넣지 않는다.
- Internal Validator의 결과는 `ROLES_AND_HANDOFF.md`의 sanitized 형식을 따른다.
- `AI_WORK_REPORT.md`는 canonical 기록이 아니며 repository에 commit하지 않는다.

## 새 Task 작성 순서

1. Validation question 하나를 작성한다.
2. `kind`, `primary_actor`, `execution_mode`를 정한다.
3. implementation/internal validation 필요 여부를 정한다.
4. candidate/instruction SHA 전달 방식을 정한다.
5. Actor plan과 Human Step을 작성한다.
6. Stop conditions와 Cleanup을 작성한다.
7. Sanitized evidence template과 Acceptance Criteria를 작성한다.
8. Human Gate Owner가 승인한 뒤 `project-state.yml`에서 활성화한다.

새 Task는 `TASK_TEMPLATE.md`를 복사해 작성한다.
