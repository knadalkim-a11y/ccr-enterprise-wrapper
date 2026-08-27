# Repository Agent Instructions

## Session role declaration

모든 세션은 실행 전에 자신의 역할을 하나만 선언한다.

```text
CHATGPT_ORCHESTRATOR
EXTERNAL_CODEX
INTERNAL_VALIDATOR
HUMAN_GATE_OWNER
```

상세 권한과 handoff는 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.
역할 제한은 아래 일반 규칙보다 우선한다.

특히 `INTERNAL_VALIDATOR`는 사내 코딩 에이전트이더라도 pull-only test agent다.
source·Task·STATUS·Gate를 수정하거나 branch/commit/push/PR을 수행하지 않는다.

## Session start

작업 전에 다음을 순서대로 수행한다.

1. 역할을 선언한다.
2. `git branch --show-current`, `git rev-parse HEAD`, `git status --short`를 확인한다.
3. `AGENTS.override.md` 존재 여부를 확인하고 있으면 보고한다.
4. `COMPANY_WRAPPER.md`를 읽는다.
5. `company/project-state.yml`을 읽는다.
6. `company/docs/PROJECT.md`, `STATUS.md`, `TRAPS.md`를 읽는다.
7. `current.task_path`가 가리키는 활성 Task를 읽는다.
8. 활성 Task의 `Required knowledge`만 추가로 읽는다.
9. install/build/start 또는 OS-specific 검증이면 `ENVIRONMENTS.md`를 읽는다.
10. 사내 Provider/model/Claude Code 요청이면 `SECURITY.md`, `INTERNAL_VALIDATION.md`를 읽고 capability matrix를 판정한다.
11. 새 ChatGPT 설계 세션이면 `DESIGN_SESSION_PLAYBOOK.md`의 Context checksum을 먼저 작성한다.

문서가 충돌하면 임의로 해석하지 말고 작업을 중단한 뒤 충돌을 보고한다.

## Task integrity

- `One Task = one validation question + one failure layer + one canonical file`이다.
- 한 세션에서는 활성 Task 하나만 다룬다.
- Task는 여러 구현·리뷰·repair·validation session을 가질 수 있지만 다른 Task를 병행하지 않는다.
- Provider, Profile, Basic completion, Streaming, Tool round-trip, Claude Code E2E는 기본적으로 별도 Task다.
- 같은 질문의 preflight, Human Step, cleanup, product diff는 같은 Task의 Step으로 둔다.
- Task의 In Scope, Out of Scope, Acceptance Criteria, Allowed Paths를 임의 변경하지 않는다.
- 기준 변경이 필요하면 실행을 멈추고 변경 제안만 기록한다.
- `project-state.yml`의 current Task/Stage를 자동 전진시키지 않는다.
- Agent는 Recommendation과 Evidence를 작성할 수 있지만 최종 Gate는 Human Gate Owner가 승인한다.
- 모델 순서는 과거 대화가 아니라 활성 Task와 serving availability를 따른다.

## Required task metadata

새 Task는 `company/tasks/TASK_TEMPLATE.md`를 따르고 최소 다음을 명시한다.

```text
kind
primary_actor
execution_mode
implementation_required
internal_validation
github_write_allowed
candidate_sha
instruction_sha
merge_policy
required_capabilities
```

Internal Validator가 primary actor이면 `github_write_allowed: false`여야 한다.

## Four-Lane workflow

```text
DESIGN
CHATGPT_ORCHESTRATOR + HUMAN_GATE_OWNER

BUILD — 필요한 경우만
EXTERNAL_CODEX

VALIDATE
INTERNAL_VALIDATOR + Human Step

GATE
HUMAN_GATE_OWNER + CHATGPT_ORCHESTRATOR
```

상세 흐름은 `company/docs/AGENT_WORKFLOW.md`를 따른다.
Internal Validator는 roadmap에서 Task를 선택하지 않고 승인된 Task/SHA 하나만 수행한다.

## Candidate / instruction contract

사내 검증 handoff에는 다음 두 값이 필수다.

```text
candidate_sha
instruction_sha
```

기본은:

```text
candidate_sha == instruction_sha == PR head SHA
```

이다. 코드와 그 코드를 검증할 Task 지침을 같은 immutable commit에 둔다.

Validation-only 예외로 두 SHA가 다르면 다음을 모두 기록한다.

```text
Instruction commit
Tested product commit
Product tree equivalence 범위와 결과
```

Internal Validator는 branch 이름, `latest`, 현재 checkout을 근거로 SHA를 추측하지 않는다.

## Role-specific GitHub rules

### `CHATGPT_ORCHESTRATOR`

- GitHub canonical 문서, Task, STATUS, Gate, Issue/PR을 검토·정리할 수 있다.
- 사용자가 전달한 sanitized evidence만 사용한다.
- 사내 검증을 직접 실행한 것처럼 기록하지 않는다.
- Task 분할, actor/execution mode, candidate/merge contract를 명확히 한다.
- 코드 구현은 원칙적으로 `EXTERNAL_CODEX` Task로 분리한다.

### `EXTERNAL_CODEX`

- 활성 Task가 허용한 branch/commit/push/PR을 수행할 수 있다.
- 사내 secret/raw evidence 없이 구현·외부 검증을 수행한다.
- 내부 검증이 필요하면 candidate에 test instruction을 함께 포함한다.
- Human Gate 없이 다음 Task/Stage를 활성화하지 않는다.
- `merge_policy: internal_pass_required`인 PR을 내부 PASS 전 병합하지 않는다.

### `INTERNAL_VALIDATOR`

허용:

```text
git fetch --prune origin
git pull --ff-only
git checkout --detach <approved candidate SHA>
git show <approved instruction SHA>:<task path>
git rev-parse HEAD
git status --short
git diff --exit-code
Task의 명령과 UI 검증
```

금지:

```text
Task 또는 다음 Task 자율 선택
branch 생성
git add / commit / push
git merge / rebase / reset --hard
Issue / PR 작성 또는 수정
Task / STATUS / Gate / project-state 수정
제품 source/dependency/script/lockfile 수정
repository 안의 report/임시 파일 생성
```

결과를 사람에게 sanitized text로 반환하고 종료한다.

### `HUMAN_GATE_OWNER`

- Task와 candidate/instruction SHA를 승인한다.
- Human-assisted Task의 실제 credential/UI/정책 Step을 수행한다.
- Agent에는 secret이 아닌 완료 상태만 전달한다.
- PASS/RETRY/BLOCKED/DEFER와 다음 Task를 최종 승인한다.

## Human-assisted execution

Task의 Actor Step은 다음처럼 표시한다.

```text
A1 [INTERNAL_VALIDATOR]
H1 [HUMAN_GATE_OWNER]
A2 [INTERNAL_VALIDATOR]
```

- Internal Validator는 Human Step 직전에 멈춘다.
- Human Gate Owner는 actual key/endpoint/model ID를 agent output에 넣지 않는다.
- Agent에는 `COMPLETED`, `PASS / FAIL / BLOCKED`, sanitized category만 반환한다.
- Human Step 완료는 다음 Task 승인이나 전체 Gate PASS를 의미하지 않는다.

## PR merge policy

```text
internal_validation: required
merge_policy: internal_pass_required
→ exact PR head의 INTERNAL_PASS 전 merge 금지

internal_validation: not_required
merge_policy: external_pass_only
→ 외부 Acceptance Criteria와 리뷰 후 merge 가능

validation-only
merge_policy: not_applicable
→ 제품 코드 PR 없음
```

내부 PASS 후 repair commit이 추가되면 이전 PASS를 새 HEAD에 자동 적용하지 않는다.

## Environment suitability

- Native Termux는 외부 개발 제어환경이다.
- `process.platform=android` 결과를 Windows/native-addon 증거로 간주하지 않는다.
- Windows install/build/runtime와 사내 연동 증거는 사내 Windows test-only 절차에서 수집한다.
- 별도 PC, CI, PRoot Linux는 Task가 명시적으로 허용할 때만 사용한다.
- 환경 조건이 맞지 않으면 이미 알려진 실패 명령을 반복하지 않는다.
- 환경 문제를 통과시키기 위한 source/dependency patch를 하지 않는다.

## Internal host capabilities

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

- Provider/gateway/stream/tool에는 앞의 두 항목이 필요하다.
- Claude Code E2E에는 세 항목이 모두 필요하다.
- Credential 존재만으로 현재 host 사용 가능을 추정하지 않는다.
- Scope가 `MISMATCH` 또는 `UNKNOWN`이면 real request를 반복하지 않는다.
- Scope mismatch 401/403은 `BLOCKED_CREDENTIAL_HOST_SCOPE`다.
- `AUTHORIZED` 확인 후에도 401/403이면 일반 `AUTHORIZATION` 후보다.

## Architecture boundary

해결 우선순위:

1. CCR configuration
2. CCR 공식 extension/plugin
3. Company wrapper
4. 승인된 최소 Core patch

CCR upstream은 공통 Runtime이다.
대체 Gateway, Provider manager, protocol converter, routing engine, model registry, control plane을 새로 만들지 않는다.
Core 변경은 Task가 허용한 경우만 가능하며 `company/patches/CORE_PATCHES.md`에 기록한다.

## Change safety

- Allowed Paths 밖 파일을 수정하지 않는다.
- 관련 없는 기존 변경을 되돌리거나 포함하지 않는다.
- 신규 production dependency는 Task가 허용한 경우만 추가한다.
- 테스트를 삭제·skip·완화하여 PASS를 만들지 않는다.
- branch/commit/push는 역할과 Task가 모두 허용할 때만 한다.
- merge/rebase/force-push는 명시적 절차가 아닌 한 수행하지 않는다.
- Internal Validator의 working tree가 dirty하면 임의 정리하지 않는다.

## Security and evidence

- 실제 endpoint, hostname/IP/proxy, credential, model ID, 권한/RPM, actual host/source identity, prompt, source, raw tool output, 사용자 식별자, 계약 가격을 commit하지 않는다.
- 실행하지 않은 검사를 PASS로 기록하지 않는다.
- Raw internal evidence는 사내에만 보관한다.
- Key 공유, allowlist 우회, 승인되지 않은 proxy/tunnel/relay를 제안하거나 구현하지 않는다.
- 일부 protocol 실패를 검증된 운영 protocol의 PASS와 분리한다.

## Temporary work reports

- `AI_WORK_REPORT.md`는 canonical 문서가 아니다.
- External Codex가 임시 사용해도 commit하지 않는다.
- 유효한 내용은 Task Attempts/Evidence에 반영한다.
- Internal Validator는 repository 안에 report를 만들지 않는다.
- 세션 종료 전 임시 파일을 삭제하거나 repository 밖으로 이동한다.

## Session finish

### `EXTERNAL_CODEX`

다음을 보고하고 멈춘다.

1. 역할과 결과
2. 변경 파일
3. 명령/테스트
4. Acceptance Criteria
5. candidate SHA / instruction SHA
6. PR과 merge policy
7. 내부 미검증 항목
8. Core patch/dependency 여부
9. 다음 Task 미시작 확인

### `INTERNAL_VALIDATOR`

GitHub를 수정하지 않고 `ROLES_AND_HANDOFF.md`의 Sanitized Evidence만 출력한다.
반드시 candidate/instruction SHA, Human Step, product diff, final status, `Git write performed: NO`를 포함한다.

### `CHATGPT_ORCHESTRATOR`

Sanitized evidence를 검토해 승인된 범위에서만 Task/STATUS/Gate/Issue를 갱신한다.
새 설계 세션이면 `DESIGN_SESSION_PLAYBOOK.md` 종료 체크리스트를 따른다.

## Code review priorities

1. 역할·GitHub 권한 위반
2. Task 질문/실패 계층 혼합
3. candidate/instruction SHA 불명확
4. 내부 PASS 전 merge 위험
5. Task 범위 초과
6. 거짓 PASS
7. CCR Native 기능 중복
8. 불필요한 Core 변경/dependency
9. 내부정보 유출 또는 credential 우회
10. Human Step/Stop condition/rollback 누락
11. 미래 Stage 과설계
