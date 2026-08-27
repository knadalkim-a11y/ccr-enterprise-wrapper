# Version / Stage / Gate / Task

- Version: 사용자에게 제공되는 큰 제품 능력 (`Wrapper V1`, `Wrapper V2`)
- Stage: 핵심 불확실성 하나를 제거하는 구간
- Gate: 다음 투자에 필요한 증거와 사람의 결정
- Task: 독립적으로 검증 가능한 최소 질문; 여러 Codex 세션과 순차 Evidence PR을 가질 수 있음
- Session: 한 Task에 대한 구현·리뷰·수정·검증 시도 하나

## Repository Bootstrap

### BOOT — Upstream History Integration

CCR `v3.0.22` commit `829298cf8bdcc6ddb9120a5a7c790c30227a1937`의 전체 history와
현재 Company foundation history를 force-push 없이 하나의 main history로 결합할 수 있는가?

Gate는 두 history의 ancestry, upstream-controlled tree의 무변경, origin/upstream remote 구조를 요구한다.

## Pre-V1 Feasibility

### V1-S0 — Stock CCR on Internal Windows

실제 target인 사내 Windows에서 pinned Stock CCR을 수정 없이 설치·빌드·실행할 수 있는가?

최소 증거:

```text
Node LTS >= 22 preflight
→ clean npm ci
→ npm run typecheck
→ npm run build:assets
→ CLI start/stop smoke
```

Native Termux는 개발 제어환경이며 Windows/native-addon 증거로 사용하지 않는다.
별도 PC, CI, PRoot Linux는 사내 Windows만으로 실패 원인을 구분할 수 없을 때만 보조로 사용한다.

### V1-S1 — Internal Provider Contract

CCR이 사내 Windows에서 사내 OpenAI-compatible API를 upstream Provider로 사용해
basic completion, streaming, tool result continuation과 주요 availability 오류를 source 수정 없이 처리할 수 있는가?

#### Host preconditions

```text
Provider/gateway contract
→ WINDOWS_RUNTIME_ALLOWED
+ LLM_CREDENTIAL_AUTHORIZED_FOR_HOST

Claude Code E2E
→ 위 두 조건
+ CLAUDE_CODE_EXECUTION_ALLOWED
```

Credential은 특정 PC/source IP/NAT·proxy egress/account/model entitlement에 묶일 수 있다.
Host scope가 맞지 않아 발생한 401은 `BLOCKED_CREDENTIAL_HOST_SCOPE`이며 protocol failure가 아니다.

#### Model order

모델 검증 순서는 architecture에 고정하지 않고 serving availability를 따른다.

```text
현재: Gemma first
이후: GLM serving rollout 완료 시 별도 onboarding
```

V1-S1 transport Gate는 우선 사용 가능한 내부 모델 한 개로 전체 contract를 증명한다.
현재는 Gemma가 그 대상이다.
각 모델은 자신의 V1-S2 workload 전에 Provider와 gateway basic completion을 별도로 통과해야 한다.
GLM-specific coding loop는 GLM onboarding이 완료될 때까지 시작하지 않는다.

최소 검증:

```text
Gemma Provider connection
→ gateway basic completion
→ streaming
→ tool call/result continuation
→ auth/rate-limit/5xx/timeout 또는 network 분류
```

### V1-S2 — Claude Code Vertical Slice

사내 Windows 중 다음 세 capability가 모두 있는 host에서 검증한다.

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

Model-specific path:

```text
Gemma: Glob/Grep/Search → relevant files → summary
GLM: Read → Edit → Test fail → understand → fix → PASS
```

Gemma path는 Gemma V1-S1 contract 후 진행할 수 있다.
GLM path는 GLM serving availability와 별도 Provider/gateway onboarding 후 진행한다.

## Wrapper V1

### V1-S3 — Managed Local Wrapper

N명의 사용자가 M대의 승인 Windows PC에서 CCR 수동 설정 없이 사용할 수 있는가?

최소 검증 질문:

- Multi-user Windows에서 논리적으로 PC당 CCR Runtime 하나를 운영할 수 있는가?
- Stock CCR의 `%APPDATA%` 사용자 범위를 공식 옵션, 전용 runtime account 또는 launcher 방식으로 안전하게 제어할 수 있는가?
- 사용자가 endpoint, protocol, model, key, start/stop을 직접 다루지 않아도 되는가?
- Provider/profile template과 host-authorized secret을 분리할 수 있는가?
- PC별 version/policy/host alias와 최소 metadata event를 생성할 수 있는가?
- raw prompt/response/source를 저장하거나 중앙 전송하지 않는가?

해결 순서:

```text
CCR configuration / official option
→ official extension/plugin
→ Company wrapper/launcher
→ 증거가 있을 때만 최소 Core patch
```

Gate는 한 대의 승인 PC에서 관리자 설치 후 비개발 사용자가 Company launcher만으로 시작할 수 있음을 요구한다.

### V1-S4 — Repeatable Setup / Doctor

깨끗한 두 번째 사내 Windows PC에서 관리자 절차를 반복해 동일 결과를 만들 수 있는가?

Setup 최소 범위:

```text
지원 Node/CCR/Wrapper version
runtime/service 준비
provider/profile template
host-authorized credential 주입 경계
Company launcher
telemetry destination/config
update/rollback metadata
```

Doctor는 다음을 독립적으로 진단한다.

```text
CCR install/runtime health
config/profile version
credential host scope
model entitlement/connectivity
Claude Code host approval
local gateway health
telemetry exporter/destination
```

Gate는 한 번의 문서화된 관리자 절차, idempotent 재실행, sanitized 결과, rollback을 요구한다.

### V1-S5 — Managed Local Safe Pilot

소수의 승인 PC와 사용자에서 Managed Local Fleet가 실제 운영 가능한가?

초기 예시:

```text
2~3대 PC
5~10명 사용자
```

Pilot 측정:

- PC당 설치·업데이트·rollback 시간
- 사용자 최초 실행 단계 수
- 설정 오류와 지원 요청
- config/version drift
- credential 발급·갱신 운영 부담
- PC/user 식별 요구 수준
- metadata completeness
- availability/error/latency
- Internal-first rate
- Successful Sonnet avoidance rate
- Sonnet fallback rate
- Internal call amplification

초기 중앙 취합은 승인된 공유 경로의 daily JSON/CSV batch로 시작할 수 있다.
실시간 Collector는 Pilot에서 필요성이 증명된 경우에만 만든다.

Gate는 사용자가 CCR UI와 upstream key를 직접 다루지 않고, Fleet 상태와 routing KPI를 중앙에서 확인할 수 있음을 요구한다.

### V1-S6 — Sonnet Avoidance Experiment (Optional)

현재 운영 baseline과 CCR 정책을 실제 중복 실행 없이 비교할 수 있는가?

비교 대상:

```text
Current baseline policy
CCR Native
Static Economy — 선택 실험
```

Primary KPI:

```text
Successful Sonnet avoidance rate
=
기존 정책상 Sonnet 대상 중
Sonnet 호출 없이 resolution chain이 종료된 비율
```

Guardrail:

```text
Internal-first rate
Sonnet fallback rate
Internal call amplification
Token-weighted avoidance
Success/error/latency
```

`Sonnet baseline 대비 추정 외부 비용 회피액`은 2차 지표다.
`Cost per Successful Task`는 V1 필수 Gate가 아니며 태스크 간 난이도 차이를 무시해 사용하지 않는다.

실패 시 실험 정책만 폐기하며 Wrapper V1 실패로 보지 않는다.

## Wrapper V2

### V2-S0 — Session Correlation Feasibility

Hook event와 CCR request를 동일 session/task로 안정적으로 연결한다.
실패하면 task-level 평가와 자동 개입을 중단한다.

V1의 routing opportunity/resolution chain metadata와 연결되며,
request-level Sonnet avoidance를 task-level 성공 지표로 확장할 수 있어야 한다.

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
- Successful Sonnet avoidance 보호
- Sonnet fallback과 internal call amplification 허용 범위
- Sonnet-only보다 낮은 Cost per Successful Task
- Manual Override 보호
- Native fail-open
