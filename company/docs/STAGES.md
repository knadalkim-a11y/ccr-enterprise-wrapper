# Version / Stage / Gate / Task

- Version: 사용자에게 제공되는 큰 제품 능력 (`Wrapper V1`, `Wrapper V2`)
- Stage: 핵심 불확실성 하나를 제거하는 구간
- Gate: 다음 투자에 필요한 증거와 사람의 결정
- Task: 독립적으로 검증 가능한 최소 질문; 여러 Codex 세션을 가질 수 있음
- Session: 한 Task에 대한 구현·리뷰·수정 시도 하나

## Repository Bootstrap

### BOOT — Upstream History Integration

CCR `v3.0.22` commit `829298cf8bdcc6ddb9120a5a7c790c30227a1937`의 전체 history와
현재 Company foundation history를 force-push 없이 하나의 main history로 결합할 수 있는가?

Gate는 두 history의 ancestry, upstream-controlled tree의 무변경, origin/upstream remote 구조를 요구한다.

## Pre-V1 Feasibility

### V1-S0 — Stock CCR Execution

지원 환경 하나에서 pinned Stock CCR을 수정 없이 install/build/start할 수 있는가?

### V1-S1 — Internal Provider Contract

CCR이 사내 OpenAI-compatible API를 안정적인 upstream으로 사용할 수 있는가?

최소 검증: completion, streaming, tool call/result continuation, 403/429/5xx/timeout 분류.
GLM 통과 후 Gemma로 확대한다.

### V1-S2 — Claude Code Vertical Slice

```text
GLM: Read → Edit → Test fail → understand → fix → PASS
Gemma: Glob/Grep/Search → relevant files → summary
```

Gate는 GLM 최소 loop 증거와 Gemma 권장 범위/제외 사유를 요구한다.

## Wrapper V1

### V1-S3 — Minimal Wrapper

승인된 Native/Force Profile을 secret 없이 배포할 수 있는가?

### V1-S4 — Repeatable Setup / Doctor

깨끗한 지원 환경에서 setup과 계층별 진단을 재현할 수 있는가?

### V1-S5 — Safe Pilot

소규모 사용자가 CCR Native를 기본으로 실제 작업에 사용할 수 있는가?

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
