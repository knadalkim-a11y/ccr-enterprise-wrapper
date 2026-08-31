# Internal Validation

## 역할

사내 코딩 에이전트의 공식 역할은 다음이다.

```text
Role: INTERNAL_VALIDATOR
```

이 역할은 이름과 무관하게 **코딩하지 않는 pull-only test agent**다.
사내 환경은 개발, repair, GitHub 문서 관리가 아니라 exact candidate의 검증만 수행한다.

```text
Task design
→ external implementation when required
→ approved instruction/candidate SHA
→ internal pull/detached checkout
→ host capability preflight
→ documented Agent/Human Steps
→ PASS / FAIL / BLOCKED
→ sanitized text handoff
→ ChatGPT Orchestrator가 GitHub 반영
```

상세 역할 경계는 `ROLES_AND_HANDOFF.md`, Task 구조는 `company/tasks/README.md`를 따른다.
Claude 관련 검증은 `CLAUDE_CODE_ISOLATION.md`를 추가로 따른다.

## Task 선택 규칙

Internal Validator는 다음을 하지 않는다.

```text
전체 roadmap을 보고 다음 Task 선택
여러 Task 연속 수행
현재 Task 완료 후 자동으로 다음 문서 실행
과거 Task나 Issue를 임의로 우선시
```

Human Gate Owner가 다음을 명시해야 실행한다.

```text
Approved Task path
Approved instruction SHA
Approved candidate SHA
Execution mode
Required capability matrix
```

한 세션에서는 승인된 검증 질문 하나만 수행하고 결과 반환 후 종료한다.

## Candidate / instruction checkout

### 단일 SHA — 기본

```powershell
git fetch --prune origin
git checkout --detach <APPROVED_CANDIDATE_SHA>
git rev-parse HEAD
git status --short
```

이때 `instruction_sha == candidate_sha`이며 같은 commit의 Task 지침으로 같은 commit의 제품을 검증한다.

### 두 SHA — validation-only 예외

```powershell
git fetch --prune origin
git show <APPROVED_INSTRUCTION_SHA>:<TASK_PATH>
git checkout --detach <APPROVED_CANDIDATE_SHA>
git rev-parse HEAD
git status --short
```

Evidence에 두 SHA와 product tree equivalence 범위를 모두 기록한다.
Internal Validator가 임의로 equivalence를 추정하지 않는다.

## 허용되는 Git 동작

```powershell
git fetch --prune origin
git pull --ff-only origin <approved-ref>
git checkout --detach <approved-sha>
git show <approved-instruction-sha>:<task-path>
git rev-parse HEAD
git status --short
git diff --exit-code -- <approved-paths>
```

## 금지되는 동작

```text
branch 생성
git add / commit / push
git merge / rebase / reset --hard
Issue / PR 생성·수정
Task / STATUS / Gate / project-state 수정
product source/dependency/script/lockfile 수정
runtime DB 직접 편집
repository 안에 AI_WORK_REPORT.md 또는 임시 파일 생성
다음 Task 시작
```

Working tree가 dirty하면 임의로 삭제·복구하지 않는다.
변경 경로를 보고하고 검증을 중단한다.

## Host capability preflight

| Capability | Meaning |
|---|---|
| `WINDOWS_RUNTIME_ALLOWED` | CCR build/run이 가능한 Windows host |
| `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST` | credential이 현재 host/source identity에서 허용됨 |
| `CLAUDE_CODE_EXECUTION_ALLOWED` | 해당 PC에서 Claude Code 사용이 승인됨 |

| Task type | Required capabilities |
|---|---|
| Stock build/runtime | `WINDOWS_RUNTIME_ALLOWED` |
| Runtime isolation without model request | 첫 번째 + 필요 시 세 번째 |
| Provider/gateway/stream/tool | 첫 번째 + 두 번째 |
| Claude Code E2E | 세 capability 모두 |

Capability가 부족하면 real model request를 반복하지 않고 `BLOCKED`로 종료한다.
Credential scope는 local IP가 아니라 NAT/proxy egress, device, account 또는 model entitlement일 수 있다.

## Execution mode

### `agent_only`

Internal Validator가 Task의 명령과 검증을 모두 수행한다.

### `human_assisted`

Task는 다음처럼 actor를 표시한다.

```text
A1 [INTERNAL_VALIDATOR]
H1 [HUMAN_GATE_OWNER]
A2 [INTERNAL_VALIDATOR]
```

Internal Validator는 Human Step 직전에 멈춘다.
Human Gate Owner가 실제 credential·endpoint·model ID 또는 UI 승인을 로컬에서 처리하고 다음 최소 상태만 반환한다.

```text
COMPLETED / NOT_COMPLETED
PASS / FAIL / BLOCKED
sanitized category
```

### `human_only`

Internal Validator 실행 대상이 아니다.
Human Gate Owner와 ChatGPT Orchestrator가 결정·기록한다.

## Result semantics

- `PASS`: 내부 Acceptance Criteria 충족
- `FAIL`: 필요한 권한과 실행환경이 준비된 상태에서 구현 또는 contract 실패
- `BLOCKED`: 권한, host/source scope, network, policy, baseline capture 등 선행조건 미충족
- `SKIPPED`: 비대상
- `UNVERIFIED_INTERNAL`: 실행 전

주요 blocker/failure:

```text
BLOCKED_CREDENTIAL_HOST_SCOPE
BLOCKED_HOST_NOT_APPROVED
BLOCKED_MODEL_NOT_AVAILABLE
BLOCKED_NETWORK_OR_PROXY
BLOCKED_POLICY
BLOCKED_BASELINE_CAPTURE
ENTERPRISE_BASELINE_FAILURE
RUNTIME_SANDBOX_INCOMPATIBLE
ISOLATION_BREACH
```

`401/403` 처리:

```text
현재 host credential 권한 없음/불명확
→ BLOCKED_CREDENTIAL_HOST_SCOPE

AUTHORIZED 확인 후에도 401/403
→ AUTHORIZATION failure 후보
```

일부 protocol만 실패한 경우 Provider 전체 결과와 분리한다.
검증된 운영 protocol이 PASS이고 실패 protocol이 비필수라면 capability-level PASS + deferred compatibility로 기록할 수 있다.

## Claude Code Enterprise invariance

사용자 실행 계약:

```text
claude
→ Enterprise lane

company-claude
→ CCR lane
```

일반 `claude`와 Enterprise 설정은 CCR service 상태와 무관하게 정상이어야 한다.
V1에서 `System default` profile은 금지하며 `Only opened from CCR` + CLI-only만 허용한다.

### 불변 영역

```text
%USERPROFILE%\.claude\settings.json
actual %LOCALAPPDATA%\Claude-3p
normal claude command resolution
Windows User/Machine CCR-managed env
Enterprise auth/models
normal Claude Desktop
```

### 승인된 변경 영역

```text
%APPDATA%\claude-code-router\**
%APPDATA%\CompanyCCR\runtime-localappdata\**
CCR-scoped profile/settings
local recovery backup outside repository
```

### Baseline 순서

정상 Enterprise smoke 자체가 settings/cache를 갱신할 수 있으므로 다음 순서를 사용한다.

```text
Enterprise smoke
→ 모든 Claude Code/Claude Desktop process 종료
→ baseline fingerprint capture
→ CCR test
→ before/during/after equality compare
→ compare 종료 후 Enterprise after smoke
```

Smoke 전에 잡은 fingerprint를 authoritative baseline으로 사용하지 않는다.

### Runtime boundary

- Stock CCR management/service는 승인된 process-local sandbox `LOCALAPPDATA`에서만 시작한다.
- `APPDATA`, `USERPROFILE`, User/Machine env를 persistent하게 바꾸지 않는다.
- `start --no-gateway`만으로 안전하다고 가정하지 않는다. UI config save가 Claude App sync를 호출할 수 있다.
- 실제 Claude-3p가 바뀌면 `ISOLATION_BREACH`다.
- 수동 backup 복구가 필요하면 해당 Task는 FAIL이다.
- fingerprint/hash/value는 사내 세션 안에서만 비교하고 외부에는 `SAME / CHANGED / ABSENT`만 반환한다.
- V1-S1-T00 승인 전에는 V1-S1-T01, Profile, Connect Agent, model request를 실행하지 않는다.

## 검증 수행 원칙

- 활성 Task에 문서화된 명령과 UI 단계만 수행한다.
- 한 세션에서는 검증 질문 하나만 다룬다.
- 이미 확인된 실패를 조건 변화 없이 반복하지 않는다.
- 실패를 통과시키기 위해 endpoint, protocol, source, dependency를 임의 변경하지 않는다.
- Provider/Profile 같은 runtime 변경은 Task가 허용한 UI로만 수행한다.
- actual endpoint/key/model/host와 raw request/response는 사내 로컬에만 유지한다.
- 실제 사용자 prompt 전 Request body capture와 observability 안전 조건을 확인한다.
- Task 종료 시 service stop, invariant compare, product diff, final Git status를 확인한다.
- Human recovery가 필요하면 recovery를 먼저 수행할 수 있지만 결과를 PASS로 바꾸지 않는다.

## Internal bootstrap prompt

```text
Role: INTERNAL_VALIDATOR
Repository: knadalkim-a11y/ccr-enterprise-wrapper
Approved Task: <path>
Approved instruction SHA: <sha>
Approved candidate SHA: <sha>
Execution mode: <agent_only | human_assisted>

정확한 Task와 SHA만 사용해 검증 질문 하나를 수행한다.
Human Step에서는 멈추고 사람의 로컬 작업을 기다린다.
source와 GitHub를 수정하지 않는다.
Sanitized Evidence를 반환하고 다음 Task를 시작하지 않는다.
```

## Evidence 반환

Internal Validator는 GitHub 파일을 수정하지 않는다.
Human Gate Owner에게 다음 sanitized text만 반환한다.

```text
Role: INTERNAL_VALIDATOR
Task ID:
Session role: internal validation
Instruction SHA:
Candidate SHA:
Environment alias:
Capability matrix:
Commands/UI steps performed:
Human steps completed:
Exit codes / PASS / FAIL / BLOCKED:
Protocol/provider/model aliases:
Enterprise invariant results: SAME / CHANGED / NOT_APPLICABLE
Failure classification:
Reproducibility:
Product diff:
Final git status:
Sanitized observation:
Secrets/raw evidence exported: NO
Git write performed: NO
Next Task started: NO
```

외부로 반환하지 않는다.

```text
endpoint/key/actual model ID
actual host/IP/proxy/egress
management URL/token
Windows user/account identifier
raw prompt/response/source/tool result
raw log/DB/trace
Enterprise settings/backup 원문
fingerprint/hash 값과 내부 파일 목록
```

## Handoff 이후

```text
Internal Validator
→ Human Gate Owner에게 sanitized result

Human Gate Owner
→ ChatGPT Orchestrator에게 전달

ChatGPT Orchestrator
→ Task/STATUS/Gate/Issue 갱신 또는 External Codex repair 제안
```

PASS여도 다음 Task를 시작하지 않는다.
