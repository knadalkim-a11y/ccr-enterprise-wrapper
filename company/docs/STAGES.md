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

### V1-S3 — Minimal Wrapper

승인된 Native/Force Profile을 secret 없이 배포할 수 있는가?

### V1-S4 — Repeatable Setup / Doctor

깨끗한 사내 Windows 환경에서 setup과 계층별 진단을 재현할 수 있는가?
Doctor는 runtime, credential host scope, Claude Code host approval을 서로 다른 계층으로 진단한다.

### V1-S5 — Safe Pilot

소규모 사용자가 사내 Windows에서 CCR Native를 기본으로 실제 작업에 사용할 수 있는가?

### V1-S6 — Static Economy Experiment (Optional)

Sonnet-only / Native / Static을 비교해 Cost per Successful Task가 개선되는가?
실패 시 실험 정책만 폐기하며 Wrapper V1 실패로 보지 않는다.

## Wrapper V2

### V2-S0 — Session Correlation Feasibility

Hook event와 CCR request를 동일 session으로 안정적으로 연결한다.
실패하면 자동 개입을 중단한다.

### V2-S1 — Observe-only State

민감정보 없이 edit, verification, 반복 실패, permission/network/API 오류를 구분한다.

### V2-S2 — Shadow Decision

모델을 바꾸지 않고 `would_escalate_to_sonnet`의 오탐·미탐·예상 비용을 평가한다.

### V2-S3 — Opt-in Sonnet Intervention

검증된 반복 build/test 실패에만 현재 turn 동안 Local → Sonnet을 적용한다.

### V2-S4 — Rescue Evaluation

```text
CCR Native
vs Native + Adaptive Quality
vs Sonnet-only
```

Release Gate: Native보다 성공률 개선, Sonnet-only보다 낮은 Cost per Successful Task,
Manual Override 보호, Native fail-open.
