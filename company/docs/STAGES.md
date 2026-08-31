# Version / Stage / Gate / Task

- Version: 사용자에게 제공되는 큰 제품 능력 (`Wrapper V1`, `Wrapper V2`)
- Stage: 핵심 불확실성 하나를 제거하는 구간
- Gate: 다음 투자에 필요한 증거와 사람의 결정
- Task: 독립적으로 검증 가능한 최소 질문; 여러 Session과 순차 Evidence를 가질 수 있음
- Session: 한 Task에 대한 implementation / review / repair / validation 시도 하나

역할과 GitHub 권한은 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.
새 설계 세션은 `company/docs/DESIGN_SESSION_PLAYBOOK.md`로 상태를 복원한다.
Claude Code 관련 Task는 `company/docs/CLAUDE_CODE_ISOLATION.md`를 따른다.

## Repository Bootstrap

### BOOT — Upstream History Integration

CCR `v3.0.22` commit `829298cf8bdcc6ddb9120a5a7c790c30227a1937`의 전체 history와 Company foundation history를 force-push 없이 하나의 main history로 결합할 수 있는가?

Gate는 두 history의 ancestry와 upstream-controlled tree의 무변경을 요구한다.

## Pre-V1 Feasibility

### V1-S0 — Stock CCR on Internal Windows

실제 target인 사내 Windows에서 pinned Stock CCR을 수정 없이 설치·빌드·실행할 수 있는가?

```text
Node LTS >= 22
→ clean npm ci
→ typecheck
→ build assets
→ CLI start/stop smoke
```

Status: `ACCEPTED`.

### V1-S1 — Internal Provider and Gateway Contract

Credential 사용 권한이 있는 사내 Windows host에서 Enterprise Claude 환경을 변경하지 않고 내부 모델 한 개의 Provider/gateway transport contract를 증명할 수 있는가?

Host precondition:

```text
Provider/gateway/stream/tool
→ WINDOWS_RUNTIME_ALLOWED
+ LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
```

Current model order:

```text
Gemma first
GLM rollout 후 별도 onboarding
```

Current Gemma protocol decision:

```text
openai_chat_completions only
Auto detect OFF
openai_responses HTTP 500 → deferred non-blocking
```

#### V1-S1-T00 — CCR Runtime Sandbox

질문:

> CCR management/service를 process-local sandbox `LOCALAPPDATA`에서 실행하고 enabled global Claude Code profile을 제거해도 Enterprise settings, 실제 Claude-3p, User/Machine env와 일반 `claude`가 before/during/after 동일한가?

이 Task는 real model request를 하지 않는다.
PASS 전에는 Provider finalization과 Claude Code profile 실험을 재개하지 않는다.

#### V1-S1-T01 — Gemma Provider Finalization

T00 승인 후에만 재개한다.

```text
accepted sandbox runtime
→ Provider manual Chat-only save
→ persistence
→ logging OFF
→ Enterprise invariance
→ stop / product diff / clean tree
```

기존 Direct Chat와 CCR Chat PASS 증거는 보존한다.

#### Remaining V1-S1 sequence

```text
V1-S1-T00 Runtime sandbox
→ V1-S1-T01 Provider connection and persistence
→ local gateway basic completion
→ streaming
→ tool call/result continuation
→ availability/error classification
→ Gemma scope decision
```

Provider-level, gateway completion, streaming, tools와 error classification을 각각 별도 검증 질문으로 분리한다.

### V1-S2 — Dual-Isolated Claude Code Vertical Slice

다음 세 capability가 모두 있는 host에서 검증한다.

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

사용자 실행 계약:

```text
claude
→ Enterprise Claude Code

company-claude
→ CCR-scoped Claude Code
```

초기 V1 profile:

```text
Effect scope: Only opened from CCR
Internal scope: ccr
Entry mode: CLI only
System default: prohibited
Claude App/Desktop: deferred
```

Task sequence:

```text
Enterprise baseline manifest
→ isolated CCR profile creation
→ company-claude basic request
→ Enterprise/CCR simultaneous separation check
→ start/stop repeatability without manual rollback
→ model-specific workload vertical slice
```

Gate는 다음을 요구한다.

```text
CCR request PASS
Enterprise before/during/after PASS
global settings diff NONE
actual Claude-3p diff NONE
User/Machine env diff NONE
manual rollback NOT_REQUIRED
```

Model-specific path:

```text
Gemma
→ Glob/Grep/Search
→ relevant files
→ summary

GLM
→ Read
→ Edit
→ Test fail
→ understand
→ fix
→ PASS
```

Gemma path는 Gemma V1-S1 contract 후 진행한다.
GLM path는 GLM serving availability와 별도 Provider/gateway onboarding 후 진행한다.

## Wrapper V1

### V1-S3 — Managed Local Wrapper Feasibility

N명의 사용자가 M대 승인 Windows PC에서 CCR 수동 설정 없이 사용할 수 있는가?

검증 질문:

- PC 또는 승인 runtime 단위의 Local CCR ownership이 가능한가
- `%APPDATA%` 사용자 범위를 official option, runtime account 또는 launcher로 안전하게 제어 가능한가
- `company-claude` launcher가 sandbox service start, isolated profile, fail-closed를 자동화할 수 있는가
- 일반 `claude`와 Enterprise baseline을 immutable로 유지할 수 있는가
- 사용자가 endpoint/protocol/model/key/start/stop을 직접 다루지 않아도 되는가
- Provider/profile template과 host-authorized secret을 분리 가능한가
- 실제 prompt 전 body capture OFF를 강제 가능한가
- CCR Core 수정 없이 request-completion metadata source를 확보 가능한가
- 최소 `routing_chain_id`와 privacy-safe event를 생성 가능한가

해결 순서:

```text
CCR configuration / official option
→ official extension/plugin
→ Company wrapper/launcher
→ 증거가 있을 때만 최소 Core patch
```

Gate는 한 대의 승인 PC에서 관리자 설치 후 비개발 사용자가 `company-claude`만으로 시작할 수 있고, 일반 `claude`는 계속 Enterprise 상태이며 metadata source feasibility가 증명됐음을 요구한다.

### V1-S4 — Repeatable Setup / Doctor

깨끗한 두 번째 사내 Windows PC에서 관리자 절차를 반복해 동일 결과를 만들 수 있는가?

Setup 범위:

```text
지원 Node/CCR/Wrapper version
runtime/service 준비
sandbox LOCALAPPDATA
provider/profile template
host-authorized credential 주입 경계
company-claude launcher
body-capture policy
telemetry source/destination
update/rollback metadata
```

Doctor 진단 계층:

```text
CCR install/runtime health
config/profile version
credential host scope
model entitlement/connectivity
Claude Code host approval
Enterprise baseline invariance
actual Claude-3p invariance
local gateway health
logging/body-capture safety
telemetry exporter/destination
```

Gate는 문서화된 관리자 절차, idempotent 재실행, sanitized 결과와 emergency recovery를 요구한다.
정상 lifecycle은 수동 rollback이 필요 없어야 한다.

### V1-S5 — Managed Local Safe Pilot

소수 PC와 사용자에서 Managed Local Fleet가 실제 운영 가능한가?

초기 예시:

```text
2~3대 PC
5~10명 사용자
```

Pilot 측정:

- PC당 설치·업데이트·emergency recovery 시간
- 사용자 최초 실행 단계 수
- `claude`와 `company-claude` 혼동/오사용
- 설정 오류와 지원 요청
- config/version drift
- credential 발급·갱신 운영 부담
- Enterprise baseline breach 수
- metadata completeness와 batch dedupe
- availability/error/latency
- Internal-first rate
- Transport-level Sonnet avoidance rate
- Sonnet fallback rate
- Internal logical call amplification
- Provider transport retry

초기 중앙 취합은 승인된 공유 경로의 daily JSON/CSV batch로 시작할 수 있다.
실시간 Collector는 필요성이 증명된 경우에만 만든다.

Gate는 사용자가 CCR UI와 upstream key를 직접 다루지 않고, 일반 Enterprise 환경을 손상시키지 않으며 Fleet 상태와 transport routing KPI를 중앙에서 확인할 수 있음을 요구한다.

### V1-S6 — Sonnet Avoidance Experiment (Optional)

현재 executable baseline policy와 CCR 정책을 실제 중복 실행 없이 비교할 수 있는가?

```text
Current baseline policy
vs CCR Native
vs Static Economy — 선택 실험
```

Primary KPI:

```text
Transport-level Sonnet avoidance rate
```

Guardrail:

```text
Internal-first rate
Automatic Sonnet fallback rate
Internal logical call amplification
Provider transport retry
Input-token-weighted avoidance
Error/latency
Enterprise isolation breach = 0
```

`Sonnet baseline 대비 추정 외부 비용 회피액`은 2차 지표다.
`Successful Sonnet avoidance`와 `Cost per Successful Task`는 V1 필수 Gate가 아니다.
실패 시 실험 정책만 폐기하며 Wrapper V1 실패로 보지 않는다.

## Wrapper V2

### V2-S0 — Session Correlation Feasibility

V1의 `routing_chain_id`를 Claude Code session/task와 안정적으로 연결할 수 있는가?
실패하면 task-level 평가와 자동 개입을 중단한다.

### V2-S1 — Observe-only State

민감정보 없이 edit, verification, 반복 실패, permission/network/API 오류를 구분한다.

### V2-S2 — Shadow Decision

모델을 바꾸지 않고 `would_escalate_to_sonnet`의 오탐·미탐·예상 비용을 평가한다.
Baseline policy version과 actual route를 함께 기록하며 동일 작업을 중복 실행하지 않는다.

### V2-S3 — Opt-in Sonnet Intervention

검증된 반복 build/test 실패에만 현재 turn 동안 Local → Sonnet을 적용한다.

### V2-S4 — Rescue Evaluation

```text
CCR Native
vs Native + Adaptive Quality
vs Sonnet-only baseline
```

Release Gate:

- Native보다 task success 개선
- Task-level Successful Sonnet avoidance 보호
- Sonnet fallback과 internal amplification 허용 범위
- Sonnet-only보다 낮은 Cost per Successful Task
- Manual Override 보호
- Native fail-open
- Enterprise baseline invariance
