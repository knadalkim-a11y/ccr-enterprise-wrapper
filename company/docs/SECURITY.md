# Security Boundary

저장소는 Public일 수 있다고 가정한다.

## Commit 금지

- 실제 API Key, endpoint, hostname/IP/proxy
- 실제 사내 model ID와 권한/RPM
- credential이 허용된 실제 PC, source IP, NAT/proxy egress 정보
- 사번·계정·조직명
- 내부 repository/source
- 실제 prompt/response/file/tool result
- 계약 가격과 raw internal logs

## Placeholder

```text
INTERNAL_LLM_BASE_URL
INTERNAL_LLM_API_KEY
INTERNAL_GEMMA_MODEL_ID
INTERNAL_GLM_MODEL_ID
```

외부 Evidence alias:

```text
Provider: internal_gemma / internal_glm
Model: internal_gemma_primary / internal_glm_primary
Credential: PRESENT / ABSENT
Credential host scope: AUTHORIZED / MISMATCH / UNKNOWN
Validation host: approved_alias_only
```

## Credential execution scope

사내 LLM credential은 값 자체만으로 사용 가능 여부가 결정되지 않을 수 있다.
발급 정책에 따라 다음 중 하나 이상에 묶일 수 있다.

```text
사용자 또는 계정
특정 PC/device
source IP
NAT 또는 proxy egress
network segment
model entitlement
```

따라서 `Credential: PRESENT`는 검증 가능 상태를 뜻하지 않는다.
실제 요청 전에 현재 validation host/source identity에 credential 사용 권한이 있는지 확인한다.

### 금지

- 다른 PC에 발급된 key를 승인 없이 복사·공유
- host/source allowlist 우회
- 승인되지 않은 proxy, tunnel, relay 사용
- 실제 허용 IP/host 정보를 GitHub Issue, PR, log에 기록
- 401을 없애기 위해 CCR source나 request protocol을 임의 수정

### 허용되는 해결 경로

- 선택한 validation host용 credential을 정식 발급
- 승인 절차를 통한 allowed host/source scope 확장
- 정책상 허용되는 credential-authorized host에서 Provider-only 검증
- serving 운영자에게 실제 egress identity와 entitlement 확인

## Host authorization 분리

다음 권한은 서로 독립적이다.

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

Provider check에는 앞의 두 권한이 필요하다.
Claude Code E2E에는 세 권한이 모두 필요하다.
한 PC가 Windows에서 CCR를 실행할 수 있다는 사실만으로 LLM key 또는 Claude Code 사용 권한을 추론하지 않는다.

## Fleet telemetry boundary

Managed Local Fleet의 중앙 집계는 metadata-only를 기본으로 한다.

### 허용 후보

```text
time window
pseudonymous host alias
pseudonymous client alias — 승인된 경우만
CCR/Wrapper/policy/baseline version
baseline model class
actual model alias
request/resolution count
input/output token count
fallback count
internal model call count
success/error count
latency summary
sanitized error category
```

### 중앙 전송 금지

```text
prompt 또는 response body
source code
file path 또는 file name
raw tool input/result
actual endpoint, API key, model ID
actual hostname/IP/proxy/egress
Windows user name, 사번, 조직명
management URL/token
raw CCR database/log/trace file
```

### 원칙

- Request/response body capture는 Company-managed profile에서 기본 OFF를 목표로 한다.
- 실패 진단에 body가 꼭 필요하면 사내 로컬에서 승인된 최소 범위로만 확인하고 중앙 또는 외부 repository로 보내지 않는다.
- Raw CCR log나 SQLite 전체를 중앙 수집하지 않는다.
- Exporter는 versioned metadata schema와 allowlist 필드만 전송한다.
- Host/user alias mapping은 중앙 대시보드 데이터와 분리하고 접근 권한을 제한한다.
- 사용자별 감사 요구가 확인되기 전에는 PC 단위 alias로 시작한다.
- Central analytics는 중앙 model gateway나 key relay로 사용하지 않는다.

## Savings claim boundary

- 사내 모델 호출 횟수만으로 비용 절감을 주장하지 않는다.
- 내부 모델 시도 후 Sonnet fallback은 Successful Sonnet avoidance가 아니다.
- `baseline policy version`, `baseline model class`, `actual model`, `fallback`을 함께 기록한다.
- `Sonnet baseline 대비 추정 외부 비용 회피액`은 counterfactual 추정치이며 `확정 절감액`으로 표현하지 않는다.
- 사용자 명시적 model/profile override는 자동 정책 절감 KPI와 분리한다.
- task-level 성공이 검증되지 않은 V1 지표를 전체 업무 생산성 향상으로 확대 해석하지 않는다.

## 일반 원칙

- Key 원문은 config export, exception, log, telemetry, snapshot에 넣지 않는다.
- Company body capture 기본값은 OFF 또는 승인된 error-only다.
- 외부 fixture는 synthetic만 사용한다.
- Raw internal evidence는 사내에만 보관한다.
- `AGENTS.override.md`는 로컬 전용이며 commit하지 않는다.
- `401/403`은 credential host scope가 확인되기 전에는 protocol 또는 product defect로 확정하지 않는다.
