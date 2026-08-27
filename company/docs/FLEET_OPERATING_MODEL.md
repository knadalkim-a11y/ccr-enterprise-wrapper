# Managed Local Fleet and Savings Measurement

## 목적

이 문서는 다음 운영 문제를 하나의 V1 기본 가설과 검증 계약으로 정리한다.

```text
N명의 사용자
×
M대의 Claude Code 승인 Windows PC
```

- 비개발자가 CCR endpoint, protocol, model, key를 직접 설정하지 않게 한다.
- 각 PC의 Local CCR 안정성과 장애 격리를 유지한다.
- M대에 분산된 모델 사용량과 routing 효과를 privacy-safe 방식으로 중앙 취합한다.
- 서로 다른 태스크의 절대 비용을 억지로 비교하지 않는다.
- V1 transport 지표를 task 성공으로 과장하지 않는다.

Windows service account, machine-scoped data directory, exporter source와 transport 같은 구현은 V1-S3 이후 Task에서 검증한 뒤 확정한다.

## V1 기본 토폴로지 가설

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
│ Central Fleet Analytics  │
│ - fleet health           │
│ - model routing          │
│ - transport avoidance    │
│ - operational guardrail  │
└──────────────────────────┘
```

```text
Model request data plane
→ PC별 Local CCR

Fleet analytics plane
→ 중앙 metadata 집계
```

중앙 analytics는 중앙 CCR Gateway, key relay, SSO 또는 Control Plane을 의미하지 않는다.
이 토폴로지는 `ACCEPTED_AS_V1_DEFAULT`이며 PC당 논리적 Runtime 가능성이 V1-S3에서 실패하면 재검토한다.

## 사용자와 관리자 경험

### 사용자

```text
1. 승인된 PC에 로그인
2. Company Claude Code 바로가기 실행
3. 작업 수행
```

사용자가 직접 수행하지 않는 항목:

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

### 관리자 또는 배포 도구

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

## PC 단위와 사용자 단위

### PC 또는 Runtime 단위

- 승인된 CCR/Wrapper version
- Provider/model/protocol template
- Host/source scope에 승인된 upstream credential
- Local service 시작 방식
- Native/Force profile
- Telemetry exporter와 host alias
- Update/rollback 상태

### 사용자 단위

- Claude Code 작업 세션
- 사용자 명시적 model/profile override
- 감사 요구가 있을 때의 local client identity

초기 Pilot은 PC 단위 alias로 시작한다.
사용자별 감사가 필수라는 운영 요구가 확인된 경우에만 사용자별 CCR client identity 또는 pseudonymous provisioning을 추가한다.

## Windows 사용자 프로필 문제

Stock CCR CLI runtime data는 기본적으로 다음 아래에 저장된다.

```text
%APPDATA%\claude-code-router
```

여러 Windows 계정이 같은 PC를 이용하면 runtime/config가 사용자별로 복제될 수 있다.
V1-S3에서 다음을 순서대로 검증한다.

1. CCR 공식 data-directory 또는 service option
2. 전용 Windows runtime/service account
3. Company launcher가 고정 runtime을 사용하는 방식
4. 증거가 있을 때만 최소 Core patch

실행 중인 SQLite 직접 편집, 사용자 프로필 간 수동 복사, key 파일 복제를 운영 해법으로 사용하지 않는다.

## Credential 계층

### Upstream LLM credential

```text
Local CCR
→ Internal Gemma/GLM API
```

- Host, source IP, NAT/proxy egress, account 또는 model entitlement에 묶일 수 있다.
- 일반 사용자에게 노출하지 않는다.
- 발급 단위는 serving 운영 정책에 따라 PC별, egress group별, service account별로 결정한다.
- Key 공유, allowlist 우회, 승인되지 않은 proxy/tunnel은 사용하지 않는다.

### CCR client credential

```text
Claude Code client
→ Local CCR gateway
```

Upstream credential과 별개다.
Pilot은 PC당 local client identity 하나로 시작할 수 있다.
사용자별 감사가 필요하면 자동 provisioning과 pseudonymous alias를 검토한다.
SSO/IAM 연계는 실제 요구와 지원 인프라가 확인되기 전에는 V1 범위에 넣지 않는다.

## 실제 사용자 요청 전 보안 선행조건

CCR Request Log는 설정에 따라 request/response body를 로컬에 저장할 수 있다.
Provider connectivity의 합성 `ping` 이후 실제 gateway prompt 또는 Claude Code E2E를 시작하기 전에 다음을 검증한다.

```text
Request logs: OFF
Agent observability: OFF
또는
requestLogBodyCapture: none
```

Company-managed profile의 기본값은 body capture OFF다.
Raw Request Log, SQLite, trace file 전체를 중앙 exporter input으로 사용하지 않는다.

## Telemetry source feasibility

중앙 Collector나 Dashboard 구현 전에 다음 질문을 V1-S3 spike로 검증한다.

> CCR Core를 수정하지 않고 request 종료 시점의 metadata를 안전하게 얻을 수 있는가?

우선순위:

1. CCR 공식 extension/event hook
2. Local management API의 metadata-only read
3. Company launcher/gateway wrapper가 생성하는 metrics event
4. 마지막 수단으로 CCR version에 고정된 local storage read-only adapter

공식 extension 문서에 request-completion event가 확인되지 않으면 지원된다고 가정하지 않는다.
실행 중인 DB 직접 편집 또는 raw DB 중앙 복사는 금지한다.

## 중앙 Telemetry boundary

### 허용 후보

```text
schema_version
event_id 또는 dedupe_key
window_start / window_end
generated_at
complete / partial
pseudonymous host alias
wrapper / CCR / source commit
policy version
baseline policy version / rule ID
baseline model class
actual model alias
routing chain count
input/output token counts
success/error count
fallback count
internal logical model attempt count
provider transport retry count
latency summary
sanitized error category
```

사용자별 감사가 승인된 경우에만 pseudonymous client alias를 추가한다.

### 중앙 전송 금지

```text
prompt 또는 response body
source code
file path 또는 file name
raw tool input/result
실제 endpoint, API key, model ID
실제 hostname/IP/proxy/egress
Windows user name, 사번, 조직명
management URL/token
raw CCR database/log/trace
```

### Batch deduplication

초기 daily JSON/CSV batch도 중복 전송을 고려한다.
최소 dedupe key 후보:

```text
host_alias
+ window_start
+ window_end
+ schema_version
+ sequence
```

Exporter retry나 공유 폴더 재복사로 동일 집계가 이중 계산되지 않아야 한다.

## V1 측정 단위

### Routing chain

V1은 전체 사용자 task가 아니라 하나의 자동 routing/fallback chain을 최소 단위로 사용한다.

```text
routing_chain_id
→ baseline decision
→ actual first model
→ logical internal attempts
→ provider transport retries
→ automatic Sonnet fallback 여부
→ chain 정상 종료 여부
```

필수 분리:

```text
logical_model_attempt_count
provider_transport_retry_count
automatic_fallback_to_sonnet
manual_escalation_to_sonnet — 포착 가능할 때
explicit_sonnet_from_start
```

Provider 429 재시도와 품질 문제로 인한 모델 escalation을 같은 증폭으로 계산하지 않는다.

V2는 이 chain을 Claude Code session, task, test/result, 최종 성공과 연결한다.

## Baseline contract

Baseline은 실제 결과를 보기 전에 executable rule로 결정하고 version을 고정한다.

최소 metadata:

```text
baseline_policy_version
baseline_rule_id
baseline_model_class
sonnet_eligible
eligibility_reason_code
manual_override
```

초기 후보:

```text
pre-wrapper-sonnet-v1
→ 사용자 명시적 override와 health check를 제외한
  기존 자동 Claude Code model request는 Sonnet 대상
```

실제 운영 정책을 확인해 rule을 확정한다.
결과를 본 뒤 사람이 임의로 `Sonnet 대상` 분모를 바꾸지 않는다.
동일 작업을 Sonnet으로 중복 실행하지 않는다.

## V1 핵심 KPI

### 1. Sonnet-eligible chain count

```text
sonnet_eligible_chain_count
```

### 2. Internal-first rate

```text
internal_first_chain_count
──────────────────────────
sonnet_eligible_chain_count
```

### 3. Transport-level Sonnet avoidance rate — V1 1차 KPI

```text
sonnet_free_normal_chain_count
────────────────────────────
sonnet_eligible_chain_count
```

V1의 `sonnet_free_normal_chain`은 다음만 뜻한다.

- 자동 Sonnet 호출 없이 chain 종료
- availability error 또는 automatic fallback 종료가 아님
- transport-level 정상 응답 또는 해당 단계의 검증 신호 존재

전체 사용자 업무 품질 성공을 뜻하지 않는다.
`Successful Sonnet avoidance`라는 명칭은 V2 task/test success correlation 이후에만 사용한다.

### 4. Sonnet fallback rate

```text
automatic_fallback_to_sonnet_count
──────────────────────────────────
internal_first_chain_count
```

수동 Sonnet 전환을 연결할 수 있으면 별도 지표로 보고한다.
V1에서 포착하지 못하면 dashboard limitation으로 명시한다.

### 5. Internal call amplification

```text
internal_logical_model_attempt_count
────────────────────────────────────
internal_first_chain_count
```

Transport retry는 별도 지표다.

### 6. Input-token-weighted avoidance — 보조 KPI

```text
sonnet_free_eligible_input_tokens
──────────────────────────────────
sonnet_eligible_input_tokens
```

Counterfactual output token은 직접 알 수 없으므로 V1은 입력 토큰 workload 비율을 우선한다.

### 7. Estimated external cost avoidance — 2차 KPI

```text
Baseline Sonnet estimated cost
- Actual external model estimated cost
```

표현은 다음으로 제한한다.

```text
Sonnet baseline 대비 추정 외부 비용 회피액
```

`확정 절감액`으로 표현하지 않는다.
사내 GPU/서빙 원가가 제공되면 별도 지표로 추가한다.

## 최소 Batch 예시

실제 값이나 사용자 정보가 아닌 alias만 사용한다.

```json
{
  "schema_version": 1,
  "dedupe_key": "approved_pc_alias:window:sequence",
  "window_start": "REDACTED_TIME_WINDOW",
  "window_end": "REDACTED_TIME_WINDOW",
  "complete": true,
  "host_alias": "approved_pc_alias",
  "source_commit": "APPROVED_WRAPPER_SHA",
  "policy_version": "native-v1",
  "baseline_policy_version": "pre-wrapper-sonnet-v1",
  "sonnet_eligible_chain_count": 100,
  "internal_first_chain_count": 70,
  "sonnet_free_normal_chain_count": 56,
  "automatic_fallback_to_sonnet_count": 14,
  "internal_logical_model_attempt_count": 120,
  "provider_transport_retry_count": 4,
  "sonnet_eligible_input_tokens": 600000,
  "sonnet_free_eligible_input_tokens": 420000,
  "errors": {
    "availability": 2,
    "credential_scope": 0
  }
}
```

Schema는 Pilot Task에서 실제 metadata source를 확인한 뒤 versioned contract로 확정한다.

## 단계별 도입

### V1-S3 — Managed Local Wrapper Feasibility

- PC당 논리적 CCR Runtime 가능성
- Company launcher
- Provider/profile template
- Host-authorized secret 주입 경계
- Body capture OFF
- metadata source feasibility
- 최소 `routing_chain_id`와 event shape
- 사용자에게 CCR UI와 key 설정을 요구하지 않음

### V1-S4 — Repeatable Setup / Doctor

- 한 번의 관리자 설치 절차
- runtime/service/config version 검사
- credential host scope 검사
- Claude Code host approval 검사
- local gateway health
- telemetry source/destination 검사
- update/rollback 검증

### V1-S5 — Managed Local Safe Pilot

초기 예시:

```text
2~3대 승인 PC
5~10명 사용자
```

Pilot 측정:

- PC 설치/업데이트/rollback 시간
- 사용자 최초 실행 단계 수
- 설정 오류/지원 요청
- config drift
- host credential 운영 부담
- metadata completeness와 dedupe
- transport-level Sonnet avoidance
- fallback와 internal amplification
- availability/error/latency

초기 중앙 취합은 승인된 공유 경로의 daily JSON/CSV batch로 시작할 수 있다.
실시간 Collector는 Pilot에서 필요성이 증명된 경우에만 만든다.

### V1-S6 — Sonnet Avoidance Experiment (Optional)

비교 대상:

```text
Current executable baseline policy
CCR Native
Static Economy — 선택 실험
```

1차 판단:

```text
Transport-level Sonnet avoidance
Fallback rate
Internal logical call amplification
Transport retry
Input-token-weighted avoidance
Error/latency guardrail
```

Task-level success와 Cost per Successful Task는 V1 필수 Gate가 아니다.

### V2 — Session/Task-level Evaluation

- routing chain과 Claude Code session/task correlation
- test/result와 최종 성공 판정
- `Successful Sonnet avoidance`
- Cost per Successful Task
- Adaptive Quality intervention 효과

## 중앙 Gateway 재검토 조건

다음 문제가 Pilot에서 실제로 반복될 때만 Shared/Central Gateway를 별도 옵션으로 검토한다.

- M대 update와 config drift가 지속적인 병목
- PC별 credential 발급/회수가 운영 불가능
- 사용자별 중앙 인증·감사가 필수
- 중앙 egress credential 사용이 정식 지원됨
- Local fleet 장애 분석이 감당하기 어려움
- 수십~수백 대 규모로 증가
- SSO, TLS, HA, 운영 인력이 준비됨

```text
Wrapper V1/V2
→ 제품 기능 성숙도

Managed Local / Shared Gateway
→ 배포 토폴로지
```
