# Stateless Design Session Playbook

## 목적

새 ChatGPT 설계 세션은 이전 대화의 길이, 기억, 요약에 의존하지 않는다.
이 저장소의 canonical 문서만 읽고도 현재 상태, 승인 결정, 미해결 질문,
활성 Task와 정확한 다음 행동을 복원할 수 있어야 한다.

현재 상태는 `project-state.yml`, `STATUS.md`, 활성 Task에만 기록한다.
이 문서는 새 세션의 복원·Task 설계·handoff 절차를 정의한다.

## 새 설계 세션 역할

```text
Role: CHATGPT_ORCHESTRATOR
```

역할 경계는 `ROLES_AND_HANDOFF.md`, 작업 흐름은 `AGENT_WORKFLOW.md`, Task 형식은 `company/tasks/README.md`를 따른다.

## Canonical source map

| 질문 | Source of Truth |
|---|---|
| 지금 어느 Stage/Task인가 | `company/project-state.yml` |
| 현재 사실·blocker·다음 행동 | `company/docs/STATUS.md` |
| 무엇을 만들고 만들지 않는가 | `company/docs/PROJECT.md` |
| 장기 Stage/Gate 구조 | `company/docs/STAGES.md` |
| 여러 Task에 영향을 주는 승인 결정 | `company/docs/DECISIONS.md` |
| 현재 Task 범위·actor·evidence | `current.task_path` |
| Task 작성 규칙 | `company/tasks/README.md`, `TASK_TEMPLATE.md` |
| 역할과 GitHub 권한 | `company/docs/ROLES_AND_HANDOFF.md` |
| 반복 함정 | `company/docs/TRAPS.md` |
| 사내 검증 규칙 | `company/docs/INTERNAL_VALIDATION.md` |
| 비밀·Telemetry 경계 | `company/docs/SECURITY.md` |
| Fleet/절감 설계 | `company/docs/FLEET_OPERATING_MODEL.md` |
| CCR 원본 기능 | 활성 Task가 지정한 upstream source/docs |

Issue와 PR은 전달·리뷰 수단이며 canonical 문서보다 우선하지 않는다.

## 새 세션 읽기 순서

1. `COMPANY_WRAPPER.md`
2. `company/project-state.yml`
3. `company/docs/STATUS.md`
4. `company/docs/PROJECT.md`
5. `company/docs/DECISIONS.md`
6. `company/docs/STAGES.md`
7. `company/docs/ROLES_AND_HANDOFF.md`
8. `company/docs/AGENT_WORKFLOW.md`
9. `current.task_path`
10. 활성 Task의 Required knowledge
11. 관련이 있을 때만 `TRAPS`, `SECURITY`, `INTERNAL_VALIDATION`, `FLEET_OPERATING_MODEL`

모든 문서를 매번 전부 읽지 않는다.
현재 질문과 Task에 필요한 canonical 문서만 추가로 읽는다.

## Context checksum

설계나 실행 지시 전에 다음을 보고한다.

```text
Repository main SHA:
Wrapper version:
Current Stage:
Current Task ID/path:
Current status/blocker:
Last passed Gate:
Validated product commit:
Active model/protocol decision:
Open risks relevant to current Task:
Exact next action:
Role boundaries for this action:
```

문서끼리 충돌하면 임의 해석하지 않고 충돌 파일과 값을 먼저 보고한다.

## 사실·결정·제안 구분

```text
CONFIRMED FACT
→ code/doc/sanitized evidence로 확인

ACCEPTED DECISION
→ DECISIONS.md 또는 Human Gate에 기록

PROPOSAL / OPEN QUESTION
→ 검증 또는 사람 승인 전
```

과거 대화에서만 논의되고 GitHub에 반영되지 않은 내용은 승인 결정이 아니다.

## Task 설계 decision tree

### 1. 질문이 하나인가

다음 문장으로 표현할 수 있어야 한다.

> 독립적으로 PASS / FAIL / BLOCKED를 판단할 수 있는가?

Provider, Profile, Completion, Streaming, Tool, E2E처럼 실패 계층이 다르면 Task를 나눈다.

### 2. 구현이 필요한가

```text
No
→ validation 또는 design Task

Yes
→ implementation Task
→ EXTERNAL_CODEX Build Lane
```

### 3. 사내 검증이 필요한가

```text
No
→ merge_policy: external_pass_only 또는 not_applicable

Yes
→ internal_validation: required
→ candidate/instruction SHA contract
→ merge_policy: internal_pass_required
```

### 4. 사람의 로컬 작업이 필요한가

```text
No
→ execution_mode: agent_only

Yes
→ execution_mode: human_assisted
→ Agent Step / Human Step / Agent Step 작성

정책 결정 자체
→ execution_mode: human_only
```

### 5. Primary actor는 누구인가

- 설계/상태: `CHATGPT_ORCHESTRATOR`
- 외부 코드 구현: `EXTERNAL_CODEX`
- 사내 exact candidate 검증: `INTERNAL_VALIDATOR`
- 정책/secret/UI/Gate: `HUMAN_GATE_OWNER`

## Task 파일 작성 원칙

- Task 하나당 파일 하나를 만든다.
- 긴 문서 안에 여러 Task를 체크리스트로 넣지 않는다.
- 같은 Validation question의 preflight·Human Step·cleanup만 한 파일에 둔다.
- `TASK_TEMPLATE.md`의 frontmatter를 채운다.
- `candidate_sha`, `instruction_sha`, merge policy를 명시한다.
- Internal Validator가 Task를 자율 선택하지 않게 exact handoff를 작성한다.
- Sanitized Evidence 템플릿과 Stop condition을 포함한다.

## Candidate 설계

### 구현 Task — 단일 SHA 기본

```text
Task spec main 반영
→ External Codex 구현 PR
→ 코드 + 최신 검증 지침이 포함된 PR head
→ instruction_sha == candidate_sha
→ internal validation
→ PASS 후 merge
```

### Validation-only — 두 SHA 예외

```text
instruction_sha: 최신 승인 Task 문서
candidate_sha: 실제 product commit
product tree equivalence: 기록
```

새로운 코드 변경 Task에서는 가능한 한 두 SHA 방식을 만들지 않는다.

## Human-assisted Task 설계

예:

```text
A1 [INTERNAL_VALIDATOR]
- preflight
- CCR start
- Human Step 준비 완료 보고

H1 [HUMAN_GATE_OWNER]
- 실제 key 입력
- UI 선택/승인
- secret 없이 완료 상태 반환

A2 [INTERNAL_VALIDATOR]
- 결과 확인
- service stop
- product diff
- sanitized evidence
```

Human Step에는 다음을 명시한다.

```text
사람이 할 일
agent output에 넣지 않을 실제 값
agent에 반환할 최소 상태
실패/중단 조건
```

## Internal handoff 작성

사내 프롬프트는 GitHub Task를 가리키는 짧은 bootstrap이어야 한다.

```text
Role: INTERNAL_VALIDATOR
Approved Task: <path>
Approved instruction SHA: <sha>
Approved candidate SHA: <sha>
Execution mode: <mode>

정확한 Task와 SHA만 사용한다.
Human Step에서 멈춘다.
source와 GitHub를 수정하지 않는다.
Sanitized Evidence를 반환하고 다음 Task를 시작하지 않는다.
```

긴 프로젝트 설명과 미래 Task를 프롬프트에 반복하지 않는다.

## Internal evidence를 받았을 때

1. 역할, Task ID, candidate/instruction SHA가 있는지 확인한다.
2. Task Acceptance Criteria와 모순되는지 검토한다.
3. PASS/FAIL/BLOCKED를 환경·권한·protocol·quality로 분리한다.
4. Human Step이 실제로 완료됐는지 확인한다.
5. product diff와 final Git status를 확인한다.
6. 불완전한 evidence를 전체 Gate PASS로 확대하지 않는다.
7. 승인 범위에서 Task/STATUS/Gate/Issue를 갱신한다.
8. 다음 내부 검증은 검증 질문 하나로 나눈다.

## 설계 변경 기록 위치

- 현재 Task 범위·Evidence: 활성 Task
- 현재 blocker·다음 행동: `STATUS.md`
- 기계 판독 상태: `project-state.yml`
- 여러 Task에 영향: `DECISIONS.md`
- Stage/Gate 구조: `STAGES.md`
- 제품 목적·책임 경계: `PROJECT.md`
- 반복 함정: `TRAPS.md`
- 보안 경계: `SECURITY.md`
- 역할·handoff: `ROLES_AND_HANDOFF.md`
- Task 시스템: `company/tasks/README.md`

같은 사실을 여러 문서에 장문 복제하지 않는다.

## 설계 세션 종료 체크리스트

1. 활성 Task의 actor/candidate/Evidence가 최신인가
2. `STATUS.md`의 Current/Next action이 실제와 일치하는가
3. `project-state.yml`과 Task/STATUS가 일치하는가
4. 승인 결정이 `DECISIONS.md`에 기록됐는가
5. Task가 검증 질문 하나만 포함하는가
6. Human Step과 Internal Step이 구분됐는가
7. candidate/instruction SHA handoff가 명확한가
8. 내부 PASS 전 코드 PR merge 금지 조건이 적용됐는가
9. Issue/PR이 canonical Task를 정확히 가리키는가
10. 실제 secret/raw evidence가 tracked content에 없는가
11. Internal Validator에게 GitHub write/source 수정이 요구되지 않았는가
12. 다음 Task는 Human Gate 없이 전진하지 않았는가
13. 새 세션이 읽을 정확한 다음 행동이 남아 있는가

변경이 없으면 억지로 문서를 수정하지 않는다.

## 긴 대화 처리 원칙

- Chat history는 참고 자료이며 Source of Truth가 아니다.
- 거대한 `SESSION_SUMMARY.md`를 누적하지 않는다.
- 중요한 내용은 발생 즉시 올바른 canonical 문서로 승격한다.
- 임시 reasoning과 폐기된 안을 모두 GitHub에 남기지 않는다.
- 폐기된 안이 미래 혼동을 만들 때만 `DEFERRED` 또는 Decision으로 남긴다.

## 새 설계 세션 시작 프롬프트

```text
Role: CHATGPT_ORCHESTRATOR
Repository: knadalkim-a11y/ccr-enterprise-wrapper

이전 대화 기억에 의존하지 말고 GitHub를 Source of Truth로 사용하라.
COMPANY_WRAPPER, project-state, STATUS, PROJECT, DECISIONS, STAGES,
ROLES_AND_HANDOFF, AGENT_WORKFLOW, 활성 Task와 Required knowledge를 읽어라.

작업 전에 Context checksum을 보고하라.
문서가 충돌하면 충돌부터 보고하라.
사내 에이전트는 pull-only INTERNAL_VALIDATOR이며 Task 자율 선택,
GitHub write, source 수정을 시키지 마라.
Human Gate 승인 없이 다음 Task/Stage를 활성화하지 마라.
```
