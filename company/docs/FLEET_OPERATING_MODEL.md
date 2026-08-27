# Managed Local Fleet and Savings Measurement

## 목적

이 문서는 다음 운영 문제를 하나의 설계로 정리한다.

```text
N명의 사용자
×
M대의 Claude Code 승인 Windows PC
```

- 비개발자가 CCR endpoint, protocol, model, key를 직접 설정하지 않게 한다.
- 각 PC의 Local CCR 안정성과 장애 격리를 유지한다.
- M대에 분산된 모델 사용량과 라우팅 효과를 중앙에서 취합한다.
- 서로 다른 태스크의 절대 비용을 억지로 비교하지 않고, 기존 정책상 Sonnet 대상이었던 라우팅 기회를 사내 모델이 얼마나 대체했는지 측정한다.

이 문서는 운영 목표와 검증 계약이다. Windows service account, machine-scoped data directory, exporter transport와 같은 구체 구현은 해당 Stage의 Task에서 검증한 뒤 확정한다.

## 선택한 V1 운영 토폴로지

### Managed Local Fleet

```text
N명의 사용자
        │
        ▼
승인된 Windows PC M대
┌──────────────────────────┐
│ Company Launcher         │
│ Company Doctor           │
│ Local CCR Runtime        │
│ Host-authorized Key      │
│ Local metrics exporter   │
└────────────┬─────────────┘
             │ metadata only
             ▼
┌──────────────────────────┐
│ Central Telemetry        │
│ - fleet aggregation      │
│ - routing KPI            │
│ - Sonnet avoidance       │
│ - operational health     │
└──────────────────────────┘
```

V1 기본 결정:

```text
Model request data plane
→ PC별 Local CCR

Fleet analytics plane
→ 중앙 집계
```

중앙 통계 취합은 중앙 CCR Gateway를 의미하지 않는다.

### 사용자 경험 목표

사용자는 다음만 수행한다.

```text
1. 승인된 PC에 로그인
2. Company Claude Code 바로가기 실행
3. 필요한 작업 수행
```

사용자가 직접 수행하지 않아야 하는 항목:

```text
Node/CCR 설치
Provider 생성
Endpoint 입력
Protocol 선택
Upstream API key 입력
Model ID 입력
CCR start/stop
Routing profile 편집
Telemetry 설정
```

### 관리자 경험 목표

관리자 또는 사내 배포 도구가 PC 단위로 다음을 수행한다.

```text
install
configure
start
health check
update
rollback
```

장기 목표 명령 예시:

```powershell
company-ccr install
company-ccr doctor
company-ccr update
company-ccr rollback
```

명령 이름과 구현 방식은 아직 확정하지 않는다.

## PC 단위와 사용자 단위의 책임 분리

### PC 또는 Runtime 단위

- 승인된 CCR/Wrapper version
- Provider/model/protocol template
- Host/source scope에 승인된 upstream credential
- Local service 시작 방식
- Native/Force routing profile
- Telemetry exporter와 host alias
- Update/rollback 상태

### 사용자 단위

- Claude Code 작업 세션
- 사용자 명시적 model/profile override
- 사용자별 감사가 필요한 경우의 local client identity

초기 Pilot에서는 PC 단위 식별로 시작할 수 있다.
사용자별 사용량 감사가 필수라는 운영 요구가 확인된 경우에만 사용자별 CCR client key 또는 익명 identity provisioning을 추가한다.

## Windows 사용자 프로필 문제

Stock CCR CLI runtime data는 Windows에서 기본적으로 다음 아래에 저장된다.

```text
%APPDATA%\claude-code-router
```

따라서 N명이 각자의 Windows 계정으로 로그인하는 환경에서는 사용자별 runtime/config가 복제될 수 있다.

V1-S3에서 반드시 답해야 할 질문:

> 여러 사용자가 공유하는 승인 PC에서 논리적으로 PC당 CCR Runtime 하나를 운영할 수 있는가?

우선 검토 순서:

1. CCR 공식 data-directory 또는 service 실행 옵션
2. 전용 Windows runtime/service account
3. Company launcher가 고정 runtime을 사용하는 방식
4. 증거가 있을 때만 최소 Core patch

`%APPDATA%` 파일을 수동 복사하거나 실행 중인 SQLite를 직접 편집하는 방식은 운영 해법으로 사용하지 않는다.

## Credential 계층

### Upstream LLM credential

```text
Local CCR
→ Internal Gemma/GLM API
```

- Host, source IP, NAT/proxy egress, account 또는 model entitlement에 묶일 수 있다.
- 일반 사용자에게 노출하지 않는다.
- PC별, egress group별 또는 service account별 발급 단위는 serving 운영 정책에 따라 결정한다.
- 승인되지 않은 key 공유, allowlist 우회, proxy/tunnel은 사용하지 않는다.

### CCR client credential

```text
Claude Code client
→ Local CCR gateway
```

Upstream LLM credential과 별개다.

Pilot 기본안:

```text
PC당 local CCR client identity 하나
```

사용자별 감사가 필요하면:

```text
사용자별 local client identity
→ 자동 provisioning
→ 중앙에는 익명 ID만 전송
```

SSO/IAM 연계는 실제 요구와 지원 인프라가 확인되기 전에는 V1 범위에 넣지 않는다.

## 중앙 Telemetry 원칙

### 중앙에 보내는 정보

원칙적으로 요청 단위 raw event보다 짧은 시간 구간의 집계 event를 우선한다.

```text
time window
host alias
wrapper version
CCR version
policy version
baseline policy version
baseline model class
actual model alias
request/resolution count
input/output token counts
success/error count
fallback count
internal model call count
latency summary
sanitized error category
```

사용자별 감사가 승인된 경우에만 pseudonymous user/client alias를 추가한다.

### 중앙에 보내지 않는 정보

```text
prompt 또는 response body
source code
file path 또는 file name
raw tool input/result
실제 endpoint 또는 API key
실제 내부 model ID
실제 hostname/IP/proxy
Windows user name 또는 사번
management URL/token
raw CCR database/log file
```

### Local log와 중앙 지표 분리

CCR Request Log는 같은 날의 troubleshooting에는 유용하지만 장기 Fleet 통계의 Source of Truth로 그대로 사용하지 않는다.

Company telemetry는 다음 우선순위로 구현한다.

1. CCR 공식 extension/event/API
2. Local management API의 metadata-only 조회
3. Company wrapper가 생성하는 별도 metrics event
4. 마지막 수단으로 version-pinned local storage read-only adapter

실행 중인 SQLite 파일 직접 편집 또는 무단 복사는 금지한다.

Company-managed profile에서는 raw request/response body의 저장과 중앙 전송을 기본 OFF로 설계한다.
구체적인 CCR 설정 키와 exporter 인터페이스는 V1-S3/S5 Task에서 검증한다.

## 절감 평가의 기본 단위

### 태스크 간 절대 비용 비교를 1차 KPI로 사용하지 않음

태스크는 난이도, 길이, 파일 수, 도구 호출 수가 다르므로 초기에는 다음을 중심 KPI로 사용하지 않는다.

```text
평균 태스크 비용
Cost per Successful Task
```

이 지표들은 session/task correlation과 성공 판정이 안정된 V2에서 보조 KPI로 사용한다.

### Routing opportunity / resolution chain

V1의 측정 단위는 다음이다.

```text
Routing opportunity
→ baseline policy라면 어떤 model class를 선택했는가
→ 실제 첫 model은 무엇이었는가
→ 내부 모델 호출이 몇 번 발생했는가
→ Sonnet fallback이 발생했는가
→ Sonnet 없이 resolution chain이 종료됐는가
```

한 opportunity에서 내부 모델이 여러 번 호출돼도 하나의 resolution chain으로 집계한다.

### Baseline

Baseline은 결과를 본 뒤 임의로 바꾸지 않는다.
각 event에 baseline policy version을 함께 기록한다.

초기 Baseline 후보:

```text
Company Wrapper 도입 전 현재 운영 정책
→ 기존이면 Sonnet을 사용했을 routing opportunity
```

사용자가 명시적으로 model/profile을 선택한 요청은 자동 절감 KPI에서 별도 분리한다.

동일 작업을 Sonnet으로 중복 실행하지 않는다.
Baseline decision만 metadata로 기록한다.

## 핵심 KPI

### 1. Sonnet-eligible resolution count

기존 기준 정책상 Sonnet 대상이었던 resolution chain 수.

```text
sonnet_eligible_count
```

### 2. Internal-first rate

```text
internal_first_count
──────────────────────
sonnet_eligible_count
```

라우터가 Sonnet 대상 중 얼마나 사내 모델을 먼저 시도했는지 보여준다.

### 3. Successful Sonnet avoidance rate — V1 핵심 KPI

```text
resolved_without_sonnet_count
─────────────────────────────
sonnet_eligible_count
```

V1의 `resolved_without_sonnet`은 다음 transport-level 의미로 제한한다.

- resolution chain이 Sonnet 호출 없이 종료됨
- availability 오류나 fallback으로 종료되지 않음
- 정상 응답 또는 해당 단계의 검증 신호가 있음

이는 전체 사용자 태스크의 품질 성공을 보장하지 않는다.
V2에서 test/result/session correlation을 추가해 task-level 성공으로 확장한다.

### 4. Sonnet fallback rate

```text
fallback_to_sonnet_count
────────────────────────
internal_first_count
```

사내 모델 우선 정책이 지나치게 공격적인지 보여준다.

### 5. Internal call amplification

```text
internal_model_call_count
─────────────────────────
internal_first_resolution_count
```

Sonnet 호출은 줄었지만 내부 서빙 부하가 과도하게 증가하는지 확인한다.

### 6. Token-weighted avoidance — 보조 KPI

건수 회피율과 함께 input/output token 기준 workload 비율을 본다.
작은 요청만 사내 모델이 처리하고 큰 요청은 계속 Sonnet이 처리하는 현상을 구분한다.

### 7. Estimated external cost avoidance — 2차 KPI

```text
Baseline Sonnet estimated cost
- Actual external model estimated cost
```

이 값은 다음 이름으로만 표현한다.

```text
Sonnet baseline 대비 추정 외부 비용 회피액
```

`확정 절감액`으로 표현하지 않는다.
사내 모델의 내부 GPU/서빙 원가가 제공되면 별도 지표로 추가한다.

## 최소 Event 예시

실제 값이나 사용자 정보가 아닌 alias만 사용한다.

```json
{
  "period": "hour",
  "host_alias": "approved_pc_alias",
  "policy_version": "native-v1",
  "baseline_policy_version": "pre-wrapper-sonnet-v1",
  "sonnet_eligible_count": 100,
  "internal_first_count": 70,
  "resolved_without_sonnet_count": 56,
  "fallback_to_sonnet_count": 14,
  "internal_model_call_count": 120,
  "input_tokens_internal": 420000,
  "output_tokens_internal": 52000,
  "errors": {
    "availability": 2,
    "credential_scope": 0
  }
}
```

이 예시는 schema 확정이 아니다. Pilot Task에서 최소 필드를 검증한 뒤 versioned schema를 만든다.

## 단계별 도입

### V1-S3 — Managed Local Wrapper

- PC당 논리적 CCR Runtime 하나의 가능성 검증
- Company launcher
- Provider/profile template
- Host-authorized secret 주입 경계
- 최소 metadata event shape
- 사용자에게 CCR UI와 key 설정을 요구하지 않음

### V1-S4 — Repeatable Setup / Doctor

- 한 번의 관리자 설치 절차
- runtime/service/config version 검사
- credential host scope 검사
- Claude Code host approval 검사
- telemetry destination/config 검사
- update/rollback 검증

### V1-S5 — Safe Pilot

초기 예시:

```text
2~3대 승인 PC
5~10명 사용자
```

Pilot에서 측정:

- PC 설치 시간
- 사용자 최초 실행 단계 수
- 설정 오류/지원 요청
- config drift
- update/rollback 시간
- host credential 운영 부담
- metadata completeness
- Sonnet avoidance/fallback/internal amplification

초기 중앙 취합은 승인된 공유 경로의 daily JSON/CSV 같은 batch 방식으로 시작할 수 있다.
실시간 Collector는 Pilot에서 필요성이 증명된 경우에만 만든다.

### V1-S6 — Sonnet Avoidance Experiment (Optional)

비교 대상:

```text
Current baseline policy
CCR Native
Static Economy — 선택 실험
```

1차 판단:

```text
Successful Sonnet avoidance
Fallback rate
Internal call amplification
Success/error/latency guardrail
```

Cost per Successful Task는 V1 필수 Gate가 아니다.

### V2 — Session/Task-level Evaluation

- request와 Claude Code session/task correlation
- test 결과와 최종 성공 판정
- task-level Successful Sonnet avoidance
- Cost per Successful Task
- Adaptive Quality intervention 효과

## 중앙 Gateway를 재검토할 조건

다음 운영 문제가 실제 Pilot에서 반복될 때만 Shared/Central Gateway를 별도 아키텍처 옵션으로 검토한다.

- M대 업데이트와 config drift가 지속적인 병목
- PC별 credential 발급/회수가 운영 불가능
- 사용자별 중앙 인증·감사가 필수
- 중앙 egress credential 사용이 정식 지원됨
- Local fleet 장애 분석이 감당하기 어려움
- 수십~수백 대 규모로 증가
- SSO, TLS, HA, 운영 인력이 준비됨

중앙 Gateway는 Wrapper V2와 같은 개념이 아니다.

```text
Wrapper V1/V2
→ 제품 기능 성숙도

Managed Local / Shared Gateway
→ 배포 토폴로지
```
