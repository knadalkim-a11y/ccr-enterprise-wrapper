# Security Boundary

저장소는 Public일 수 있다고 가정한다.

## 역할별 정보 경계

```text
INTERNAL_VALIDATOR
→ 실제 secret/raw evidence를 사내 로컬에서만 사용
→ GitHub write와 repository report 생성 금지

HUMAN_GATE_OWNER
→ 외부 전달 가능 여부를 판단하고 sanitized text만 전달

CHATGPT_ORCHESTRATOR / EXTERNAL_CODEX
→ actual secret/raw internal evidence에 접근하지 않음
```

상세 역할은 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.

## Commit 및 외부 전달 금지

- 실제 API Key, endpoint, hostname/IP/proxy
- 실제 사내 model ID와 권한/RPM
- credential이 허용된 실제 PC, source IP, NAT/proxy egress 정보
- 사번·계정·조직명
- 내부 repository/source
- 실제 prompt/response/file/tool result
- management URL/token
- raw CCR database/log/trace
- 계약 가격과 raw internal logs

## Placeholder와 alias

```text
INTERNAL_LLM_BASE_URL
INTERNAL_LLM_API_KEY
INTERNAL_GEMMA_MODEL_ID
INTERNAL_GLM_MODEL_ID
```

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

```text
WINDOWS_RUNTIME_ALLOWED
LLM_CREDENTIAL_AUTHORIZED_FOR_HOST
CLAUDE_CODE_EXECUTION_ALLOWED
```

Provider check에는 앞의 두 권한이 필요하다.
Claude Code E2E에는 세 권한이 모두 필요하다.
한 PC가 Windows에서 CCR를 실행할 수 있다는 사실만으로 LLM key 또는 Claude Code 사용 권한을 추론하지 않는다.

## Protocol capability boundary

한 protocol 실패를 Provider 전체, credential 또는 model failure로 확대하지 않는다.
현재 Gemma V1 운영 경로:

```text
openai_chat_completions: supported
openai_responses: HTTP 500, unsupported_or_incompatible, non-blocking
```

실제 endpoint/body/raw response는 외부에 기록하지 않는다.

## Request logging and body capture

Provider 합성 ping 이후 실제 gateway prompt 또는 Claude Code E2E 전에 다음 중 하나를 검증한다.

```text
Request logs: OFF
Agent observability: OFF
또는
requestLogBodyCapture: none
```

- Company-managed profile의 body capture 기본값은 OFF다.
- `errors` capture도 실제 prompt/source가 포함될 수 있으므로 별도 승인 없이 중앙 전송하지 않는다.
- Raw Request Log, sidecar body, SQLite, trace 전체를 exporter input으로 사용하지 않는다.
- 실패 진단에 body가 꼭 필요하면 사내 로컬에서 승인된 최소 범위로만 확인한다.

## Fleet telemetry boundary

Managed Local Fleet의 중앙 집계는 metadata-only를 기본으로 한다.

### 허용 후보

```text
schema version / dedupe key / time window
pseudonymous host alias
pseudonymous client alias — 승인된 경우만
CCR/Wrapper/source/policy/baseline version
baseline rule/model class
actual model alias
routing chain count
input/output token count
fallback count
logical internal model attempt count
provider transport retry count
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

- Exporter는 versioned metadata schema와 allowlist 필드만 전송한다.
- Host/user alias mapping은 중앙 dashboard data와 분리하고 접근 권한을 제한한다.
- 사용자별 감사 요구가 확인되기 전에는 PC 단위 alias로 시작한다.
- Central analytics는 중앙 model gateway나 key relay로 사용하지 않는다.
- Batch event는 dedupe 가능한 식별자를 가져야 한다.

## Savings claim boundary

- 사내 모델 호출 횟수만으로 비용 절감을 주장하지 않는다.
- 내부 모델 시도 후 Sonnet fallback은 Transport-level Sonnet avoidance가 아니다.
- `baseline policy version`, `baseline rule ID`, `baseline model class`, `actual model`, `fallback`, 최소 `routing_chain_id`를 함께 기록한다.
- V1 지표의 공식 명칭은 `Transport-level Sonnet avoidance rate` 또는 `Sonnet-free resolution rate`다.
- `Successful Sonnet avoidance`는 V2에서 task/test success correlation 후에만 사용한다.
- `Sonnet baseline 대비 추정 외부 비용 회피액`은 counterfactual 추정치이며 `확정 절감액`으로 표현하지 않는다.
- 사용자 명시적 model/profile override는 자동 정책 절감 KPI와 분리한다.
- V1 transport 지표를 전체 업무 생산성 향상으로 확대 해석하지 않는다.

## 일반 원칙

- Key 원문은 config export, exception, log, telemetry, snapshot에 넣지 않는다.
- 외부 fixture는 synthetic만 사용한다.
- Raw internal evidence는 사내에만 보관한다.
- `AGENTS.override.md`는 로컬 전용이며 commit하지 않는다.
- `401/403`은 credential host scope가 확인되기 전에는 protocol 또는 product defect로 확정하지 않는다.
- Internal Validator는 GitHub Task/STATUS를 직접 수정하지 않는다.
