# Internal Validation

## 역할

사내 코딩 에이전트의 공식 역할은 다음이다.

```text
Role: INTERNAL_VALIDATOR
```

이 역할은 이름과 무관하게 **코딩하지 않는 pull-only test agent**다.
사내 환경은 개발, repair, GitHub 문서 관리가 아니라 exact commit의 검증만 수행한다.

```text
External implementation
→ exact candidate commit
→ internal pull/detached checkout
→ host capability preflight
→ documented commands/UI steps
→ PASS / FAIL / BLOCKED
→ sanitized text handoff
→ ChatGPT Orchestrator가 GitHub 반영
```

상세 역할 경계는 `company/docs/ROLES_AND_HANDOFF.md`를 따른다.

## 허용되는 Git 동작

```powershell
git fetch --prune origin
git pull --ff-only origin <approved-branch>
git checkout --detach <TESTED_COMMIT_SHA>
git rev-parse HEAD
git status --short
git diff --exit-code -- <approved-paths>
```

## 금지되는 동작

```text
branch 생성
git add / commit / push
git merge / rebase / reset --hard
Issue / PR 생성·수정
Task / STATUS / Gate / project-state 수정
product source/dependency/script/lockfile 수정
runtime DB 직접 편집
repository 안에 AI_WORK_REPORT.md 또는 임시 파일 생성
```

Working tree가 dirty하면 임의로 삭제·복구하지 않는다.
변경 경로를 보고하고 검증을 중단한다.

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
서로 다른 host에서 증거를 수집할 수 있지만, 외부 Evidence에는 실제 값 대신 capability 충족 여부와 승인된 alias만 기록한다.

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

## 검증 수행 원칙

- 활성 Task에 문서화된 명령과 UI 단계만 수행한다.
- 한 세션에서는 검증 질문 하나만 다룬다.
- 이미 확인된 실패 명령을 다른 조건 변화 없이 반복하지 않는다.
- 실패를 통과시키기 위해 endpoint, protocol, source, dependency를 임의 변경하지 않는다.
- Provider 설정 같은 runtime 변경은 Task가 허용한 UI를 통해서만 수행한다.
- actual endpoint/key/model/host와 raw request/response는 사내 로컬에만 유지한다.
- Task가 끝나면 service stop, product diff, final git status를 가능한 범위에서 확인한다.

## Evidence 반환

Internal Validator는 GitHub 파일을 수정하지 않는다.
Human Gate Owner에게 다음 형식의 sanitized text만 반환한다.

```text
Role: INTERNAL_VALIDATOR
Task ID:
Session role: internal validation
Exact tested commit:
Environment alias:
Capability matrix: YES / NO / UNKNOWN
Commands/UI steps performed:
Exit codes / PASS / FAIL / BLOCKED:
Protocol/provider/model aliases:
Failure classification:
Reproducibility:
Product diff:
Final git status:
Sanitized observation:
Secrets/raw evidence exported: NO
Git write performed: NO
Next Task started: NO
```

외부로 반환하지 않는 항목:

```text
endpoint/key/actual model ID
actual host/IP/proxy/egress
management URL/token
Windows user/account identifier
raw prompt/response/source/tool result
raw log/DB/trace
```

## Handoff 이후

```text
Internal Validator
→ Human Gate Owner에게 sanitized result

Human Gate Owner
→ ChatGPT Orchestrator에게 전달

ChatGPT Orchestrator
→ Task/STATUS/Gate/Issue 갱신 또는 External Codex repair 제안
```

Internal Validator는 결과가 PASS이더라도 다음 Task를 시작하지 않는다.
