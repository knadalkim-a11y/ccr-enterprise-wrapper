# Agent Workflow

## 목적

이 프로젝트의 작업은 하나의 에이전트가 처음부터 끝까지 자율 진행하지 않는다.
권한과 실행환경이 다른 네 Lane이 GitHub의 canonical Task를 중심으로 협업한다.

```text
DESIGN → BUILD → VALIDATE → GATE
```

상세 역할 권한은 `company/docs/ROLES_AND_HANDOFF.md`, Task 작성 규칙은 `company/tasks/README.md`를 따른다.

## 기본 단위

```text
One Task = one validation question + one failure layer + one canonical file
One Session = design / implementation / review / repair / validation 중 한 번의 시도
One active attempt PR at a time
```

하나의 Task는 여러 Session과 순차 Evidence PR을 가질 수 있다.
다른 Task를 동시에 시작하지 않는다.

## Four-Lane workflow

### 1. DESIGN — `CHATGPT_ORCHESTRATOR` + `HUMAN_GATE_OWNER`

책임:

- 다음 투자 결정을 좌우하는 검증 질문 하나를 정의한다.
- Task를 파일 단위로 분리한다.
- `primary_actor`, `execution_mode`, candidate contract, merge policy를 정한다.
- Agent Step과 Human Step을 분리한다.
- Acceptance Criteria, Stop condition, Cleanup, Sanitized Evidence를 작성한다.
- 승인된 Task와 상태를 GitHub canonical 문서에 반영한다.

금지:

- 여러 실패 계층을 하나의 Task에 묶기
- 실행하지 않은 내부 검증 PASS 처리
- Human Gate 승인 없이 다음 Task/Stage 활성화

### 2. BUILD — `EXTERNAL_CODEX`

`implementation_required: true`일 때만 존재한다.

책임:

- Android/Termux 외부 환경에서 활성 Task 범위만 구현한다.
- branch/commit/push/PR을 사용한다.
- 외부 테스트와 내부 test-only 절차를 함께 준비한다.
- 내부 검증 candidate SHA를 반환한다.

구현 Task의 권장 candidate:

```text
candidate_sha == instruction_sha == PR head SHA
```

내부 검증이 필요한 PR은 exact PR head의 `INTERNAL_PASS` 전 병합하지 않는다.

### 3. VALIDATE — `INTERNAL_VALIDATOR` + 필요한 Human Step

사내 Windows 에이전트는 pull-only test agent다.

책임:

- Human Gate Owner가 승인한 Task와 exact SHA 하나만 실행한다.
- Task의 preflight, 명령, UI 검증, cleanup만 수행한다.
- secret과 raw evidence를 사내 로컬에 유지한다.
- PASS / FAIL / BLOCKED와 sanitized evidence를 사람에게 반환한다.
- 다음 Task를 시작하지 않는다.

금지:

```text
source/dependency/script/lockfile 수정
Task/STATUS/Gate/project-state 수정
branch/commit/push/PR/Issue
repository 안의 임시 report 생성
다음 Task 선택 또는 자동 진행
```

### 4. GATE — `HUMAN_GATE_OWNER` + `CHATGPT_ORCHESTRATOR`

판정:

```text
PASS
→ Task Evidence 확정
→ 필요 시 코드 PR merge
→ Task DONE 후보

FAIL
→ 같은 Task의 External Codex repair session
→ 새 candidate로 재검증

BLOCKED
→ 코드 수정 없이 권한·환경·정책 선행조건 해결
→ 같은 Task 재시도

DEFER / CANCEL
→ 이유와 영향 기록
```

Human Gate Owner만 다음 Task와 Stage Gate를 최종 승인한다.

## Task 분할 기준

기본적으로 별도 Task:

```text
Provider connection
Profile / Connect Agent setup
Gateway basic completion
Streaming
Tool call/result continuation
Availability error classification
Claude Code vertical slice
Setup / Doctor / Pilot
```

같은 Task의 Step:

```text
Preflight
Agent 명령
사람의 credential/UI 입력
Agent 결과 확인
Service stop
Product diff와 final status
```

판단 기준:

> 실패 원인과 repair 담당이 달라지면 별도 Task다.
> 같은 Validation question의 준비·실행·정리는 같은 Task 안의 Step이다.

## Task classification

```text
kind:
- design
- implementation
- validation
- spike

execution_mode:
- agent_only
- human_assisted
- human_only
```

### Agent-only

예:

```text
npm ci
Typecheck
Build
CLI help/start/stop
Source diff
```

### Human-assisted

예:

```text
API Key 입력
Provider/Profile 저장
사내 UI 결과 육안 확인
Claude Code 실행 승인
```

Task 실행 순서 예:

```text
[INTERNAL_VALIDATOR] Preflight와 service start
→ STOP FOR HUMAN
[HUMAN_GATE_OWNER] Key 입력과 UI 동작
→ 완료 상태만 반환
[INTERNAL_VALIDATOR] 결과 확인, cleanup, sanitized report
```

에이전트 출력에 실제 key, endpoint, model ID를 넣지 않는다.

### Human-only

예:

```text
Stage Gate 승인
공식 지원 protocol 결정
Pilot 확대 승인
Responses 호환성 조사를 현재 범위에 포함할지 결정
```

사내 에이전트 실행 Task로 만들지 않는다.

## Candidate / instruction SHA

내부 handoff에는 다음이 필수다.

```text
candidate_sha
instruction_sha
```

### 단일 SHA 방식 — 기본

코드 변경과 검증 지침을 같은 PR head에 둔다.

```text
Internal Validator
→ git checkout --detach <PR_HEAD_SHA>
→ 같은 commit의 Task 지침으로 같은 commit의 제품을 검증
```

### 두 SHA 방식 — 예외

Validation-only Task 또는 과거 검증 product tree를 재사용하는 경우:

```text
instruction_sha: 최신 Task 지침
candidate_sha: 실제 제품 commit
product tree equivalence: 검증 범위 기록
```

두 SHA를 branch 이름이나 “최신 main”이라는 표현으로 대체하지 않는다.

## PR merge policy

```text
internal_validation: required
merge_policy: internal_pass_required
→ exact candidate 내부 PASS 전 merge 금지

internal_validation: not_required
merge_policy: external_pass_only
→ 외부 Acceptance Criteria와 리뷰 후 merge 가능

validation-only
merge_policy: not_applicable
→ 제품 코드 PR 없음
```

내부 검증 후 repair commit이 추가되면 이전 PASS는 새 HEAD에 자동 승계되지 않는다.
변경 영향에 따라 재검증한다.

## 상태 흐름

```text
PLANNED
→ IN_PROGRESS
→ EXTERNAL_PASS
→ READY_FOR_INTERNAL_VALIDATION
→ INTERNAL_PASS / INTERNAL_FAIL / BLOCKED
→ HUMAN_DECISION
→ DONE / RETRY / CANCELLED / DEFERRED
```

Preflight blocker는 구현 실패와 분리한다.

```text
BLOCKED_ENVIRONMENT
BLOCKED_CREDENTIAL_HOST_SCOPE
BLOCKED_HOST_NOT_APPROVED
BLOCKED_MODEL_NOT_AVAILABLE
BLOCKED_NETWORK_OR_PROXY
BLOCKED_POLICY
```

## 환경과 capability

```text
Native Termux
→ 외부 구현과 GitHub 작업

사내 Windows
→ test-only 검증
```

사내 Windows capability:

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

- Stock runtime에는 첫 번째가 필요하다.
- Provider/gateway/stream/tool에는 첫 번째와 두 번째가 필요하다.
- Claude Code E2E에는 세 capability 모두가 필요하다.

Credential scope가 `MISMATCH` 또는 `UNKNOWN`이면 real request를 반복하지 않는다.

## 모델과 protocol 순서

- 모델 onboarding 순서는 serving availability를 따른다.
- 활성 Task가 Gemma를 가리키면 과거 GLM-first 계획을 적용하지 않는다.
- 각 모델은 자신의 Claude Code workload 전에 Provider와 gateway basic completion을 별도로 검증한다.
- 일부 protocol이 실패하더라도 공식 운영 protocol 하나가 통과하면 capability-level PASS로 기록할 수 있다.
- 미지원 protocol은 Provider 전체 실패와 분리하고 필요 시 별도 Task로 유예한다.

## 세션 시작

모든 세션:

1. 역할을 선언한다.
2. `project-state.yml`과 활성 Task를 읽는다.
3. Task의 Required knowledge만 추가로 읽는다.
4. branch/HEAD/working tree를 보고한다.
5. Validation question, actor plan, Stop condition을 재진술한다.
6. candidate/instruction SHA를 확인한다.
7. 사내 model request면 capability matrix를 확인한다.

새 ChatGPT 설계 세션은 `DESIGN_SESSION_PLAYBOOK.md`의 Context checksum을 먼저 작성한다.

## External Codex 구현 / 리뷰

구현:

- 가장 작은 변경으로 Acceptance Criteria를 충족한다.
- 다음 Stage abstraction을 미리 추가하지 않는다.
- 내부 검증 명령은 source 수정 없이 실행 가능해야 한다.
- Task가 허용한 branch/commit/push/PR만 수행한다.

리뷰 우선순위:

1. 역할과 GitHub 권한 위반
2. Scope/Allowed Paths 위반
3. candidate/instruction SHA 불명확
4. 내부 PASS 전 merge 위험
5. CCR 기능 중복 구현
6. Core patch와 dependency 증가
7. 거짓 PASS 또는 기준 약화
8. secret/raw evidence 노출
9. Human Step과 Stop condition 누락
10. rollback·Evidence 누락

## Internal Validator 실행

사내 시작 프롬프트는 짧게 유지한다.
실제 맥락과 명령은 GitHub Task에 둔다.

```text
Role: INTERNAL_VALIDATOR
Approved instruction SHA: <sha>
Approved candidate SHA: <sha>
Active Task: company/tasks/.../<task>.md

정확한 SHA를 읽고/checkout한 뒤 활성 Task 하나만 수행한다.
Human Step에서는 멈추고 사람의 로컬 작업을 기다린다.
source와 GitHub를 수정하지 않는다.
Sanitized Evidence를 반환하고 다음 Task를 시작하지 않는다.
```

## AI Work Report

- External Codex는 임시 scratch로 사용할 수 있으나 commit하지 않는다.
- 유효한 내용은 Task Attempts/Evidence에 반영한다.
- Internal Validator는 repository 안에 report나 임시 파일을 만들지 않는다.

## 종료

- External Codex: candidate SHA와 PR, 외부 Evidence를 반환하고 멈춘다.
- Internal Validator: GitHub를 수정하지 않고 sanitized result만 반환한다.
- ChatGPT Orchestrator: 승인된 Evidence를 canonical 문서에 반영한다.
- Human Gate Owner: 최종 Gate와 다음 Task를 승인한다.
