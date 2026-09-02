# Stateless Design Session Playbook

## 목적

새 ChatGPT 설계 세션은 이전 대화의 길이, 기억, 요약에 의존하지 않는다.
이 저장소의 canonical 문서만 읽고도 현재 상태, 승인 결정, 미해결 질문,
활성 Task와 정확한 다음 행동을 복원할 수 있어야 한다.

현재 상태는 `project-state.yml`, `STATUS.md`, 활성 Task에 기록한다.
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
| Claude Enterprise/CCR 실행 경계 | `company/docs/CLAUDE_CODE_ISOLATION.md` |
| 반복 함정 | `company/docs/TRAPS.md` |
| 사내 검증 규칙 | `company/docs/INTERNAL_VALIDATION.md` |
| 비밀·Telemetry 경계 | `company/docs/SECURITY.md` |
| Fleet/절감 설계 | `company/docs/FLEET_OPERATING_MODEL.md` |
| CCR 원본 기능 | 활성 Task가 지정한 upstream source/docs |

Issue와 PR은 전달·리뷰 수단이며 canonical 문서보다 우선하지 않는다.
단, Human Gate가 exact SHA로 승인한 PR bundle은 canonical main의 권한을
확장하지 않는 범위에서 해당 Task/phase의 execution overlay가 될 수 있다.
이때 main SHA, canonical repository URL, PR fetch ref, instruction/candidate SHA와
authorized phase를 handoff에 함께 고정한다.

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
11. Claude/CCR Task이면 `CLAUDE_CODE_ISOLATION.md`
12. 관련이 있을 때만 `TRAPS`, `SECURITY`, `INTERNAL_VALIDATION`, `FLEET_OPERATING_MODEL`

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
Claude execution contract: claude / company-claude
Enterprise isolation status:
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

Runtime isolation, Provider, Profile, Completion, Streaming, Tool, E2E처럼 실패 계층이 다르면 Task를 나눈다.

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

## Claude isolation Task 설계

Claude 관련 Task는 먼저 실행 lane을 명시한다.

```text
claude
→ Enterprise lane

company-claude
→ CCR lane
```

V1 기본:

```text
Only opened from CCR
scope=ccr
CLI only
System default prohibited
Claude App deferred
```

또한 다음을 별도 검증한다.

```text
Client profile isolation
≠
CCR Runtime side-effect isolation
```

Stock management/save가 real `%LOCALAPPDATA%\Claude-3p`를 변경할 수 있으므로, 승인된 sandbox `LOCALAPPDATA` 없이 Provider/Profile Task를 실행하지 않는다.

Baseline fingerprint는 반드시:

```text
Enterprise smoke
→ 모든 Claude client 종료
→ capture
```

순서로 잡는다.
수동 rollback이 필요하면 PASS가 아니라 `ISOLATION_BREACH`다.

## Task 파일 작성 원칙

- Task 하나당 파일 하나를 만든다.
- 긴 문서 안에 여러 Task를 체크리스트로 넣지 않는다.
- 같은 Validation question의 preflight·Human Step·cleanup만 한 파일에 둔다.
- `TASK_TEMPLATE.md`의 frontmatter를 채운다.
- `candidate_sha`, `instruction_sha`, merge policy를 명시한다.
- Internal Validator가 Task를 자율 선택하지 않게 exact handoff를 작성한다.
- Sanitized Evidence 템플릿과 Stop condition을 포함한다.
- Claude Task에는 invariant/allowed paths와 fail-closed 조건을 포함한다.

## 비례성·과설계 검토

설계·repair·review마다 기능 정확성·보안과 함께 다음을 기본 확인한다.

```text
MUST NOW
→ 현재 Task의 실제 실패 또는 승인된 위협을 직접 줄임

CONDITIONAL
→ 특정 정책, 다중 사용자, credential 또는 배포 조건에서만 필요

DEFER
→ 미래 fleet/자동화/적대적 contributor를 가정해야만 필요
```

다음 질문에 답하지 못하는 새 gate, 상태, attestation, script, parser 또는
격리 계층은 추가하지 않는다.

1. 지금 관찰된 어떤 실패를 막는가?
2. 더 작은 절차로 같은 안전성을 얻을 수 없는가?
3. 사람의 승인 왕복·수기 Evidence·실행 실패 surface를 얼마나 늘리는가?
4. 현재 V1 증거 수집에 필요한가, 아니면 미래 운영 자동화인가?

보안 통제를 제거할 때는 남는 위험을 숨기지 않고 명시적으로 수용하거나
조건부 통제로 남긴다. 단순함 자체를 위해 invariant나 secret 경계를 약화하지 않는다.

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

### Human-approved validation overlay — 좁은 예외

활성 Task가 명시적으로 승인한 경우에만 control/instruction PR head와 과거 tested
product를 다음처럼 분리한다.

```text
candidate_role: validation_overlay
candidate_sha == instruction_sha == exact control/instruction PR head
tested_product_sha: exact prior validated product commit
protected-path equivalence: exact scope/result
build plane: full tested_product_sha archive
```

Overlay SHA와 tested product SHA를 handoff와 Evidence에서 별도로 보존한다. 이
예외로 candidate whole-tree build equivalence나 merge safety를 주장하지 않는다.

## Human-assisted Task 설계

```text
A1 [INTERNAL_VALIDATOR]
- preflight
- Human Step 준비

H1 [HUMAN_GATE_OWNER]
- 실제 key/UI/승인
- secret 없이 완료 상태 반환

A2 [INTERNAL_VALIDATOR]
- 결과 확인
- service stop
- invariant/product diff
- sanitized evidence
```

Human Step에는 사람이 할 일, agent output 금지 값, 최소 반환 상태, 실패/중단 조건을 명시한다.

## Internal handoff 작성

```text
Role: INTERNAL_VALIDATOR
Canonical repository URL: <https-url>
Repository main SHA: <sha>
Main fetch ref: <full-ref, Task가 요구할 때>
Candidate fetch ref: <full-ref>
Approved Task: <path>
Approved instruction SHA: <sha>
Approved candidate SHA: <sha>
Candidate role: <implementation|validation|validation_overlay>
Tested product SHA: <sha, validation_overlay only>
Protected-path equivalence: <scope/result, validation_overlay only>
Authorized phase: <phase>
Merge policy: <policy>
Required capability matrix: <name=value...>
Execution mode: <mode>

정확한 Task와 SHA만 사용한다.
승인된 phase가 끝나면 멈추고, Human Step이 있으면 그 직전에 멈춘다.
source와 GitHub를 수정하지 않는다.
Sanitized Evidence를 반환하고 다음 Task를 시작하지 않는다.
```

긴 프로젝트 설명과 미래 Task를 프롬프트에 반복하지 않는다.

## Internal evidence를 받았을 때

1. 역할, Task ID, candidate/instruction SHA를 확인한다.
2. Task Acceptance Criteria와 모순되는지 검토한다.
3. PASS/FAIL/BLOCKED를 environment, isolation, credential, protocol, quality로 분리한다.
4. Human Step이 실제로 완료됐는지 확인한다.
5. Enterprise invariant, product diff/fingerprint와 선택된 checkout status를 확인한다.
   Disposable archive flow의 shared checkout status는 `NOT_APPLICABLE`이다.
6. 수동 복구가 있었다면 PASS로 승격하지 않는다.
7. 불완전한 evidence를 전체 Gate PASS로 확대하지 않는다.
8. 승인 범위에서 Task/STATUS/Gate/Issue를 갱신한다.
9. 다음 내부 검증은 검증 질문 하나로 나눈다.

## 설계 변경 기록 위치

- 현재 Task 범위·Evidence: 활성 Task
- 현재 blocker·다음 행동: `STATUS.md`
- 기계 판독 상태: `project-state.yml`
- 여러 Task에 영향: `DECISIONS.md`
- Stage/Gate 구조: `STAGES.md`
- 제품 목적·책임 경계: `PROJECT.md`
- Claude 실행/격리: `CLAUDE_CODE_ISOLATION.md`
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
9. Claude Task가 Enterprise invariant와 allowed surface를 구분하는가
10. `claude`와 `company-claude` 경계가 명확한가
11. actual LOCALAPPDATA에서 unsafe Stock start/save를 요구하지 않는가
12. Issue/PR이 canonical Task를 정확히 가리키는가
13. 실제 secret/raw evidence가 tracked content에 없는가
14. Internal Validator에게 GitHub write/source 수정이 요구되지 않았는가
15. 다음 Task는 Human Gate 없이 전진하지 않았는가
16. 새 세션이 읽을 정확한 다음 행동이 남아 있는가
17. 새 통제가 `MUST NOW / CONDITIONAL / DEFER`로 검토됐는가
18. 같은 안전성을 유지하면서 더 작은 절차로 줄일 수 없는가
19. 사람의 승인 왕복과 수기 Evidence 부담이 필요 이상으로 늘지 않았는가

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

Claude 관련 Task이면 CLAUDE_CODE_ISOLATION을 반드시 읽어라.
작업 전에 Context checksum을 보고하라.
문서가 충돌하면 충돌부터 보고하라.
사내 에이전트는 pull-only INTERNAL_VALIDATOR이며 Task 자율 선택,
GitHub write, source 수정을 시키지 마라.
Human Gate 승인 없이 다음 Task/Stage를 활성화하지 마라.
```
