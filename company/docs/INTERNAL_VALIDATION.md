# Internal Validation

사내 환경은 개발이 아니라 검증만 수행한다.

```text
External implementation
→ exact candidate commit
→ internal detached checkout
→ host capability preflight
→ documented commands
→ PASS / FAIL / BLOCKED
→ sanitized result
```

```bash
git fetch origin
git checkout --detach <TESTED_COMMIT_SHA>
git status --short
```

## Host capability preflight

사내 Task를 실행하기 전에 host가 필요한 권한을 실제로 갖는지 판정한다.

| Capability | Meaning |
|---|---|
| `WINDOWS_RUNTIME_ALLOWED` | CCR build/run이 가능한 Windows host |
| `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST` | 사용할 credential이 현재 host/source identity에서 허용됨 |
| `CLAUDE_CODE_EXECUTION_ALLOWED` | 해당 PC에서 Claude Code 사용이 승인됨 |

Task별 요구사항:

| Task type | Required capabilities |
|---|---|
| Stock build/runtime | `WINDOWS_RUNTIME_ALLOWED` |
| Provider/gateway/stream/tool | `WINDOWS_RUNTIME_ALLOWED` + `LLM_CREDENTIAL_AUTHORIZED_FOR_HOST` |
| Claude Code E2E | 세 capability 모두 |

Capability가 부족하면 실제 model request를 반복하지 않고 `BLOCKED`로 종료한다.
서로 다른 host에서 증거를 수집할 수 있지만, 각 Evidence에는 실제 값 대신 capability 충족 여부와 host alias만 기록한다.

Credential scope는 local IP와 다를 수 있다.
NAT/proxy egress, device, account 또는 model entitlement가 기준일 수 있으므로 serving 운영 정책을 확인한다.

## Result semantics

- `PASS`: 내부 Acceptance Criteria 충족
- `FAIL`: 필요한 권한과 실행환경이 준비된 상태에서 구현 또는 contract 실패
- `BLOCKED`: 권한, host/source scope, network, proxy, TLS, 모델 미제공 등 선행조건 미충족
- `SKIPPED`: 비대상
- `UNVERIFIED_INTERNAL`: 실행 전

세부 blocker 분류:

```text
BLOCKED_CREDENTIAL_HOST_SCOPE
BLOCKED_HOST_NOT_APPROVED
BLOCKED_MODEL_NOT_AVAILABLE
BLOCKED_NETWORK_OR_PROXY
BLOCKED_POLICY
```

`401/403` 처리:

```text
현재 host에 credential 권한이 없음 또는 불명확
→ BLOCKED_CREDENTIAL_HOST_SCOPE

현재 host scope가 AUTHORIZED로 확인된 뒤에도 401/403
→ AUTHORIZATION failure 후보
```

Host-scope mismatch는 CCR protocol 또는 model failure로 기록하지 않는다.

## 금지

- 사내 product code 수정
- endpoint/key/model ID/actual host/IP/raw evidence 반출
- 다른 commit 결과 재사용
- 미검증 PASS
- key 복사·공유 또는 allowlist 우회
- 승인되지 않은 proxy/tunnel/relay 사용

## Evidence 반환

FAIL/BLOCKED의 raw evidence는 사내에 유지하고 다음만 외부로 반환한다.

```text
Task ID
exact tested commit
capability matrix: YES / NO / UNKNOWN
provider/model aliases
selected protocol when known
PASS / FAIL / BLOCKED
failure category
reproducibility
sanitized observation
```
