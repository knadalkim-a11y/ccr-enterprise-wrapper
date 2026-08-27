# Project Definition

## 목적

CCR upstream을 공통 Runtime으로 사용하면서, 사내에서 실제로 설치·검증·운영 가능한
Company Wrapper를 작은 증거 단위로 개발한다.

## 증명해야 할 것

- CCR upstream history를 보존한 하나의 repository 구성
- 사내 Windows에서 pinned Stock CCR 설치·빌드·실행
- host-authorized credential을 사용한 사내 OpenAI-compatible API의 completion/streaming/tool contract 호환
- Gemma·GLM의 Claude Code Agent loop 수행 범위
- N명의 사용자가 M대 승인 PC에서 수동 CCR 설정 없이 사용할 수 있는 Managed Local Fleet
- 다른 PC에 반복 가능한 setup/doctor/update/rollback
- Local CCR의 privacy-safe 중앙 metadata 취합
- 기존 정책상 Sonnet 대상이었던 routing chain의 사내 모델 대체 효과
- Android/Termux 외부 개발과 사내 Windows 검증 사이의 안전한 evidence handoff
- 이전 대화 기억 없이 GitHub canonical 문서만으로 새 설계 세션을 복원하는 운영 방식

## 책임 경계

### CCR

- API Gateway, protocol/stream 변환
- Provider/model/credential/Profile
- manual model selection, Native Subagent Routing
- condition/script routing runtime
- availability retry/fallback
- Fusion/ToolHub/extension
- request logs와 observability

### Company Wrapper

- 검증된 CCR version pin/update
- 사내 설치·설정 자동화
- Provider contract 및 Claude Code E2E 검증
- secret/public boundary
- host/credential/Claude Code approval preflight
- PC 단위 managed runtime, launcher, setup/doctor, update/rollback
- 사용자에게 endpoint/protocol/model/key 설정을 요구하지 않는 실행 경험
- body/source를 제외한 privacy-safe Fleet telemetry
- versioned baseline/actual/fallback 기반 transport-level Sonnet avoidance 측정
- safe pilot
- V2 task state와 quality intervention

## 구현 우선순위

```text
CCR configuration
→ CCR 공식 extension/plugin
→ Company wrapper
→ 증거가 있을 때만 최소 Core patch
```

실제 Provider/model/Profile은 CCR 설정을 Source of Truth로 유지한다.
별도 Model Registry나 Control Plane을 만들지 않는다.

## 협업과 GitHub 권한

```text
CHATGPT_ORCHESTRATOR
→ 설계, 상태 복원, sanitized evidence 검토, canonical GitHub 문서 관리

EXTERNAL_CODEX
→ Android/Termux에서 활성 Task 구현·review·repair·branch/commit/PR

INTERNAL_VALIDATOR
→ 사내 Windows에서 exact commit pull-only test
→ source/Task/STATUS/Gate 수정과 GitHub write 금지

HUMAN_GATE_OWNER
→ 사내 권한/evidence 전달, Stage Gate와 다음 Task 최종 승인
```

상세 기준은 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.
사내 코딩 에이전트는 이름과 무관하게 pull-only Internal Validator다.

## Stateless design session

새 ChatGPT 설계 세션은 이전 대화의 기억에 의존하지 않는다.

```text
project-state.yml
→ STATUS.md
→ PROJECT.md
→ DECISIONS.md
→ STAGES.md
→ ROLES_AND_HANDOFF.md
→ 활성 Task와 Required knowledge
```

`company/docs/DESIGN_SESSION_PLAYBOOK.md`의 Context checksum으로 현재 상태를 복원한다.
현재 상태를 거대한 별도 세션 요약 파일에 복제하지 않는다.
Chat에서만 논의되고 canonical 문서에 반영되지 않은 내용은 proposal이며 accepted decision이 아니다.

## 실행환경과 권한 전략

```text
Native Termux
→ 개발 제어, Git, 문서, Task, PR, review

사내 Windows
→ install, typecheck, build, 실행, 사내 연동, Claude Code E2E
```

사내 Windows라는 사실만으로 모든 검증 권한이 있다고 가정하지 않는다.

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

Provider contract에는 앞의 두 조건이 필요하다.
Claude Code E2E에는 세 조건이 모두 필요하다.
Credential은 host/source IP/NAT·proxy egress/account/model entitlement에 묶일 수 있으며,
범위 불일치 401은 product 또는 protocol failure가 아니라 운영 blocker다.

개인 Windows/Linux PC, Codex Cloud, GitHub Actions는 초기 필수가 아니다.
사내 Windows에서 exact commit을 build하고 실행하는 것은 개발이 아니라 test-only 검증이다.
자세한 기준은 `company/docs/ENVIRONMENTS.md`와 `INTERNAL_VALIDATION.md`를 따른다.

## Model onboarding order와 protocol

모델 순서는 architecture dependency가 아니라 serving availability에 따라 정한다.

```text
현재 available model: Gemma first
GLM: serving rollout 완료 후 별도 onboarding
```

각 모델의 Claude Code workload 전에 해당 모델의 Provider와 gateway basic completion을 별도로 검증한다.
GLM-specific coding loop를 Gemma 결과만으로 PASS 처리하지 않는다.

현재 Gemma V1 upstream protocol:

```text
openai_chat_completions only
Auto detect protocols: OFF
```

OpenAI Responses는 CCR Check Connection에서 HTTP 500이 확인되어 현재 `UNSUPPORTED_OR_INCOMPATIBLE`이며 non-blocking deferred capability다.
이 결과를 전체 Provider, credential, Gemma model 또는 특정 replica failure로 확대하지 않는다.

## 운영 토폴로지

V1 기본 배포 방식은 Managed Local Fleet 가설이다.

```text
N명의 사용자
→ M대의 승인 Windows PC
→ PC별 Local CCR Runtime
→ Internal LLM Serving
```

중앙화하는 것은 모델 요청 경로가 아니라 Fleet analytics다.

```text
Model request data plane
→ Local CCR

Analytics plane
→ privacy-safe central aggregation
```

PC당 논리적 Runtime 하나를 목표로 하지만 Stock CCR의 `%APPDATA%` 사용자 범위 때문에
multi-user Windows에서 machine scope를 만드는 방법은 V1-S3에서 검증한다.
전용 service account, official data directory option, launcher 기반 고정 runtime을 순서대로 검토한다.

중앙 CCR Gateway, SSO, HA는 Pilot에서 운영 필요가 증명되기 전에는 기본 경로가 아니다.
자세한 기준은 `company/docs/FLEET_OPERATING_MODEL.md`를 따른다.

## 절감 측정 원칙

V1은 task 성공을 아직 상관관계로 증명하지 못하므로 다음을 1차 KPI로 사용한다.

```text
Transport-level Sonnet avoidance rate
=
기존 정책상 Sonnet 대상 routing chain 중
자동 Sonnet 호출 없이 transport-level 정상 종료된 비율
```

함께 확인할 guardrail:

```text
Internal-first rate
Automatic Sonnet fallback rate
Internal logical call amplification
Provider transport retry
Input-token-weighted avoidance
Error/latency
```

V1에는 최소 `routing_chain_id`와 실행 전에 결정되는 versioned baseline rule이 필요하다.
사내 모델 호출 수만으로 절감을 주장하지 않는다.

`Sonnet baseline 대비 추정 외부 비용 회피액`은 2차 참고 지표다.
`Successful Sonnet avoidance`와 `Cost per Successful Task`는 V2에서 session/test/result correlation 후 사용한다.

## 실제 사용자 요청 전 보안

Provider 합성 ping 이후 실제 gateway prompt 또는 Claude Code E2E 전에 다음을 검증한다.

```text
Request logs: OFF
Agent observability: OFF
또는 requestLogBodyCapture: none
```

Prompt/response/source/raw tool data와 raw CCR DB/log/trace를 중앙 telemetry로 전송하지 않는다.

## 제품 버전

### Wrapper V1 — Internal Adoption Foundation

Android/Termux에서 Company layer를 개발·관리하고,
사내 Windows에서 반복 가능하고 안전하게 설치·검증하여
host-authorized credential과 승인된 실행환경으로 사내 모델을 Claude Code Agent 모델로 사용한다.

V1 운영 기반:

- Managed Local Fleet 최소 설치·업데이트 경험
- PC 단위 local runtime과 Company launcher
- setup/doctor
- body-capture-safe, privacy-safe Fleet telemetry
- routing-chain 수준 transport Sonnet avoidance Pilot

`static-economy`는 V1의 정의가 아니라 Native와 비교하는 선택 실험이다.

### Wrapper V2 — Native-first Quality Intervention

정상 상태에서는 CCR Native를 유지하고,
검증 가능한 반복 품질 실패에만 Sonnet 개입을 적용한다.

V2 평가 기반:

- routing chain과 session/task correlation
- test/result 기반 task success
- task-level Successful Sonnet avoidance
- Cost per Successful Task

초기 V2는 자동 Opus, prompt classifier, learned router를 포함하지 않는다.

## 정책

| Policy | Meaning | Availability |
|---|---|---|
| `native` | CCR 기본 동작 | V1 |
| `force-model` | 실제 모델 직접 선택 | V1 |
| `static-economy` | 정적 비용 절감 실험 | V1 optional |
| `adaptive-quality` | Native-first 품질 개입 | V2 |

## 우선순위

```text
사용자 명시적 모델/Profile
> 선택적 Company intervention
> CCR Native/default
> CCR availability retry/fallback
```

Availability 오류와 품질 실패를 혼합하지 않는다.

- Availability: credential host scope, timeout, 429, 5xx, network/provider 오류
- Protocol capability: protocol별 지원 여부를 분리
- Quality: 동일 build/test 실패 반복 등 → V2 Company layer

## 비목표

- CCR 대체 Gateway/Control Plane
- V1 기본 경로로서의 중앙 Shared CCR Gateway
- 중앙 Key/사용자/SSO/Admin UI
- Credential allowlist 우회 또는 key relay
- Prompt/response/source code의 중앙 telemetry 수집
- Redis/Kubernetes/다중 Gateway
- 범용 사내 Agent 플랫폼
- V1 Hook routing
- V2 learned routing
- Android native ABI를 제품 지원 대상으로 만들기 위한 CCR patch
- Internal Validator의 코드 수정 또는 GitHub write

## 개발/검증 루프

```text
ChatGPT Orchestrator가 Task/절차 정리
→ External Codex가 구현 branch/PR
→ Human Gate Owner가 승인 commit 사내 반입
→ Internal Validator가 pull-only test
→ Human이 sanitized result 전달
→ ChatGPT가 Task/STATUS/Gate 갱신
→ 필요 시 External Codex repair
```
