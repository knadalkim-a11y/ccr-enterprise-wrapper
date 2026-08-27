# Project Definition

## 목적

CCR upstream을 공통 Runtime으로 사용하면서, 사내에서 실제로 설치·검증·운영 가능한
Company Wrapper를 작은 증거 단위로 개발한다.

## 증명해야 할 것

- CCR upstream history를 보존한 하나의 repository 구성
- 사내 Windows에서 pinned Stock CCR 설치·빌드·실행
- host-authorized credential을 사용한 사내 OpenAI-compatible API의 completion/streaming/tool contract 호환
- Gemma·GLM의 Claude Code Agent loop 수행 범위
- 다른 사용자가 재현 가능한 setup/doctor
- Android/Termux의 외부 에이전트 개발과 사내 Windows 테스트 사이의 안전한 증거 전달

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
- setup/doctor와 safe pilot
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

## 실행환경과 권한 전략

```text
Native Termux
→ 기본 개발 제어, Git, 문서, Task, PR, 리뷰

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
범위 불일치 401은 product 또는 protocol failure가 아니라 운영 blocker로 분류한다.

개인 Windows/Linux PC, Codex Cloud, GitHub Actions는 초기 필수가 아니다.
사내 Windows에서 exact commit을 build하고 실행하는 것은 개발이 아니라 test-only 검증이다.
자세한 기준은 `company/docs/ENVIRONMENTS.md`를 따른다.

## Model onboarding order

모델 순서는 architecture dependency가 아니라 serving availability에 따라 정한다.

```text
현재 available model: Gemma first
GLM: serving rollout 완료 후 별도 onboarding
```

사용 가능한 모델로 CCR transport contract를 먼저 증명할 수 있다.
다만 각 모델의 Claude Code workload 전에 해당 모델의 Provider와 gateway basic completion을 별도로 검증한다.
GLM-specific coding loop를 Gemma 결과만으로 PASS 처리하지 않는다.

## 제품 버전

### Wrapper V1 — Internal Adoption Foundation

Android/Termux에서 Company layer를 개발·관리하고,
사내 Windows에서 반복 가능하고 안전하게 설치·검증하여
host-authorized credential과 승인된 실행환경으로 사내 모델을 Claude Code Agent 모델로 사용한다.

`static-economy`는 V1의 정의가 아니라 Native와 비교하는 선택 실험이다.

### Wrapper V2 — Native-first Quality Intervention

정상 상태에서는 CCR Native를 유지하고,
검증 가능한 반복 품질 실패에만 Sonnet 개입을 적용한다.

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
- Quality: 동일 build/test 실패 반복 등 → V2 Company layer

Host-scope mismatch는 CCR availability retry로 해결할 문제가 아니라 승인된 credential/host 조합을 준비해야 하는 precondition이다.

## 비목표

- CCR 대체 Gateway/Control Plane
- 중앙 Key/사용자/SSO/Admin UI
- Credential allowlist 우회 또는 key relay
- Redis/Kubernetes/다중 Gateway
- 범용 사내 Agent 플랫폼
- V1 Hook routing
- V2 learned routing
- Android native ABI를 제품 지원 대상으로 만들기 위한 CCR patch

## 개발/검증 루프

```text
Termux external agent development
→ exact candidate commit
→ internal Windows host capability preflight
→ approved host/credential test only
→ sanitized result
→ external repair session if needed
→ human Gate/next Task decision
```
