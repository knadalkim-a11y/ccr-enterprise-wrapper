# Project Definition

## 목적

CCR upstream을 공통 Runtime으로 사용하면서, 사내에서 실제로 설치·검증·운영 가능한
Company Wrapper를 작은 증거 단위로 개발한다.

## 증명해야 할 것

- CCR upstream history를 보존한 하나의 repository 구성
- 지원 환경 하나에서 pinned Stock CCR 설치·실행
- 사내 OpenAI-compatible API의 completion/streaming/tool contract 호환
- GLM·Gemma의 Claude Code Agent loop 수행 범위
- 다른 사용자가 재현 가능한 setup/doctor
- 외부 Codex 개발과 사내 테스트 사이의 안전한 증거 전달

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

## 제품 버전

### Wrapper V1 — Internal Adoption Foundation

지원 환경 하나에서 CCR을 반복 가능하고 안전하게 설치하고,
사내 모델을 Claude Code Agent 모델로 검증·사용한다.

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

- Availability: timeout, 429, 5xx, network/provider 오류 → CCR
- Quality: 동일 build/test 실패 반복 등 → V2 Company layer

## 비목표

- CCR 대체 Gateway/Control Plane
- 중앙 Key/사용자/SSO/Admin UI
- Redis/Kubernetes/다중 Gateway
- 범용 사내 Agent 플랫폼
- V1 Hook routing
- V2 learned routing

## 개발/검증 루프

```text
External Codex development
→ exact candidate commit
→ internal pull and test only
→ sanitized result
→ human Gate/next Task decision
```
